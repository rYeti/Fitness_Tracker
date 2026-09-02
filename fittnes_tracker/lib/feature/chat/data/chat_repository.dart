import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/feature/chat/data/chat_api.dart';
import 'package:ForgeForm/feature/chat/data/chat_key_store.dart';
import 'package:ForgeForm/feature/chat/data/chat_signalr_client.dart';
import 'package:ForgeForm/feature/chat/data/webcrypto_chat_crypto.dart';
import 'package:ForgeForm/feature/chat/domain/chat_crypto.dart';
import 'package:ForgeForm/feature/chat/domain/models/chat_message.dart';
import 'package:ForgeForm/feature/chat/domain/models/conversation_summary.dart';
import 'package:ForgeForm/feature/chat/domain/models/thread_message.dart';

/// The glue layer — owns the outbox DAO and the SignalR client, mediates
/// between them. This is where the reconnect/replay logic lives (see
/// chat-flutter-roadmap.md §4 and its §4a walkthrough for the full
/// state-by-state reasoning behind each rule below).
///
/// Role-agnostic on purpose: it only ever deals in "the other party", so the
/// same instance serves the Trainer Console (other party = a client) and the
/// trainee app (other party = the trainer).
class ChatRepository {
  final AppDatabase _db;
  final ChatApi _api;
  final ChatSignalRClient _signalR;

  /// The encryption boundary. Every message crosses it exactly once in each
  /// direction, and both crossings happen in this class — see the four call
  /// crossings happen in this class — at [_attemptSend], [replayPending],
  /// [loadThread], [_handleIncoming] and [getConversations], and nowhere else.
  final ChatCrypto _crypto;

  /// This device's key pair. Owned here rather than by [_crypto] because
  /// registering it is a connection-time concern, and this is the class that
  /// already knows when a connection is being established.
  final ChatKeyStore _keys;

  /// How many reconnect-driven resends a message gets before it is marked
  /// `failed` and handed to the user to retry manually.
  final int maxReplayAttempts;

  static const _uuid = Uuid();

  /// The thread currently on screen. Replay targets this one, because it is the
  /// only thread whose outbox the user can actually see.
  String? _activeThreadId;

  /// Message ids this device already knows about — from history, from the
  /// outbox, and from acks. The filter that stops the sender seeing their own
  /// message twice; see [incomingFor].
  final Set<String> _knownIds = {};

  /// Every thread whose hub group this connection has joined — the open one plus
  /// all the conversations being watched for the inbox. Kept so a re-open or a
  /// second [watchConversations] doesn't re-join a group needlessly.
  final Set<String> _watchedThreads = {};

  /// Peers whose public key has already been re-fetched once after a decryption
  /// failure. See [_decrypt].
  final Set<String> _refetchedPeers = {};

  /// Resend attempts per message id, for the bounded retry in [replayPending].
  ///
  /// In memory rather than a column: a counter that resets when the app restarts
  /// is the behaviour we want anyway — a fresh launch is a fresh chance, and it
  /// keeps the Drift schema unchanged.
  final Map<String, int> _replayAttempts = {};

  /// Serialises [_handleIncoming] so decryption cannot reorder a thread.
  Future<void> _incomingChain = Future<void>.value();

  final _threadMessages = StreamController<ThreadMessage>.broadcast();
  final _allIncoming = StreamController<ChatMessage>.broadcast();
  StreamSubscription<ChatMessage>? _incomingSubscription;
  StreamSubscription<void>? _reconnectedSubscription;

  /// Builds a repository with the real crypto stack unless one is injected.
  ///
  /// A factory rather than default arguments because [crypto] and [keys] are not
  /// independent — the crypto derives its secrets from that key store, and two
  /// separately-defaulted instances would each generate their own identity, of
  /// which only one would ever be published.
  factory ChatRepository({
    required AppDatabase db,
    ChatApi? api,
    required ChatSignalRClient signalR,
    ChatCrypto? crypto,
    ChatKeyStore? keys,
    int maxReplayAttempts = 3,
  }) {
    final keyStore = keys ?? ChatKeyStore();
    return ChatRepository._(
      db: db,
      api: api,
      signalR: signalR,
      keys: keyStore,
      crypto: crypto ?? WebCryptoChatCrypto(keys: keyStore),
      maxReplayAttempts: maxReplayAttempts,
    );
  }

  ChatRepository._({
    required AppDatabase db,
    ChatApi? api,
    required ChatSignalRClient signalR,
    required ChatCrypto crypto,
    required ChatKeyStore keys,
    this.maxReplayAttempts = 3,
  }) : _db = db,
       _api = api ?? ChatApi(),
       _signalR = signalR,
       _crypto = crypto,
       _keys = keys {
    // Replay is driven by the reconnect signal, never a timer: a timer would
    // either fire uselessly while the connection is still down or sit idle after
    // it comes back.
    //
    // Every thread with a pending row, not just the one on screen. The outbox
    // is not scoped to the open conversation -- a trainer who messages several
    // clients queues rows across several threads, and replaying only
    // `_activeThreadId` left every other one stuck at `pending` forever: the
    // only other path back to `sendMessage`'s own network attempt is a second
    // reconnect that happens to land while that particular thread is open,
    // which for most threads never happens.
    _reconnectedSubscription = _signalR.onReconnected.listen((_) {
      unawaited(_replayAllPending());
    });

    // Chained rather than fired off per event. [_handleIncoming] became async
    // when decryption moved into it, and an async listener processes overlapping
    // messages concurrently: the first message of a conversation has to derive a
    // shared key, the second finds it cached, and the second can finish first.
    // In a conversation the order is the meaning, so each message waits for the
    // one before it.
    _incomingSubscription = _signalR.incomingMessages.listen((message) {
      _incomingChain = _incomingChain.then((_) => _handleIncoming(message));
    });
  }

  /// Brings this device's chat key pair up, generating and publishing one on
  /// first run.
  ///
  /// Called alongside `connect()` rather than from the constructor: it makes a
  /// network round trip, and a constructor that quietly does that is a
  /// constructor nothing can build in a test.
  ///
  /// Must complete before the first send. Without a published key the other
  /// side cannot decrypt anything this device writes, and without knowing our
  /// own account id the key store cannot tell its identity key from the one
  /// belonging to whoever used this device last.
  Future<void> prepareKeys() => _keys.ensureRegistered();

  String? get activeThreadId => _activeThreadId;

  Stream<ChatConnectionStatus> get connectionStatus => _signalR.connectionStatus;

  // ── Thread lifecycle ──────────────────────────────────────────────────────

  /// Joins the hub groups for every conversation in [otherPartyIds] and stays in
  /// them, so a message arriving for a thread that is *not* on screen still
  /// reaches this device.
  ///
  /// This reverses an earlier decision. Membership used to follow the open
  /// thread — join on open, leave on switch — reasoning that messages for
  /// threads nobody is looking at would only have to be filtered out again. That
  /// is true of the *thread view*, and false of everything else: an unread badge
  /// is by definition about a conversation you do not have open, so scoping
  /// delivery to the open thread made a live inbox impossible rather than
  /// merely unnecessary. The filtering that argument wanted to avoid is four
  /// lines in [_handleIncoming].
  ///
  /// A join that fails is dropped rather than propagated: the cost is a stale
  /// badge for one conversation until the next load, and failing the whole
  /// inbox over that would be a far worse trade. The thread's own [openThread]
  /// joins independently, so opening a conversation still works.
  Future<void> watchConversations(Iterable<String> otherPartyIds) async {
    for (final id in otherPartyIds) {
      if (!_watchedThreads.add(id)) continue;
      try {
        await _signalR.joinGroup(id);
      } catch (_) {
        _watchedThreads.remove(id);
      }
    }
  }

  /// Marks [otherPartyId] as the thread on screen, joining its group if
  /// [watchConversations] has not already.
  ///
  /// No longer leaves the previous thread's group — see [watchConversations].
  /// The trainee app has exactly one thread and never calls
  /// [watchConversations], so this is still the only join it needs.
  Future<void> openThread(String otherPartyId) async {
    if (_activeThreadId == otherPartyId) return;

    // Dropped before the join, committed after it. Setting it up front recorded
    // the thread as open while the join was still in flight — and if the join
    // then threw, the guard above turned every retry into an immediate return,
    // so the user could tap "retry" forever against a group they were never in.
    _activeThreadId = null;
    _knownIds.clear();

    if (!_watchedThreads.contains(otherPartyId)) {
      await _signalR.joinGroup(otherPartyId);
      _watchedThreads.add(otherPartyId);
    }
    _activeThreadId = otherPartyId;
  }

  /// Closes the thread view. Group membership is deliberately kept: the
  /// conversation list still wants this thread's messages, for its preview and
  /// its unread count.
  Future<void> closeThread() async {
    if (_activeThreadId == null) return;

    _activeThreadId = null;
    _knownIds.clear();
  }

  /// History (REST) merged with anything still unsent locally, so a message the
  /// user just wrote stays on screen while it is in flight rather than
  /// disappearing until the ack lands.
  Future<List<ThreadMessage>> loadThread(String otherPartyId) async {
    final history = await _api.fetchHistory(
      otherPartyId,
      deviceId: await _crypto.deviceId(),
    );
    final unsent = await _db.chatoutboxDao.getUnsentMessages(otherPartyId);

    // Keyed by messageId, server rows inserted first, so an outbox row for a
    // message the server already has is dropped rather than shown a second time.
    //
    // That overlap is not an edge case — it is the outbox's whole reason to
    // exist. A send whose message was stored but whose ack was lost stays
    // `pending` locally *by design* (§2: guessing either way loses messages), so
    // it is in both lists at once. Concatenating them showed the user one message
    // twice, once sent and once as a failure they were invited to retry.
    final byId = <String, ThreadMessage>{};
    for (final json in history) {
      final message = ThreadMessage.fromChatMessage(
        await _decrypt(ChatMessage.fromJson(json), otherPartyId),
        otherPartyId: otherPartyId,
      );
      byId[message.messageId] = message;
    }
    for (final row in unsent) {
      byId.putIfAbsent(row.messageId, () => ThreadMessage.fromOutbox(row));
    }

    final messages = byId.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    _knownIds
      ..clear()
      ..addAll(messages.map((m) => m.messageId));

    // Opening a thread is what "reading" means here. Fire-and-forget: failing to
    // record the read is a stale badge, not a reason to fail the whole screen.
    unawaited(_api.markRead(otherPartyId).catchError((_) {}));

    return messages;
  }

  // ── Sending ───────────────────────────────────────────────────────────────

  /// §4 "Sending a message": generate the id, write a pending outbox row, then
  /// try the wire. A failure leaves the row pending — it is **not** retried here.
  ///
  /// [onQueued] fires as soon as the message is durably in the outbox and before
  /// anything touches the network, so the UI can show the bubble immediately.
  /// Waiting for this method's Future instead would leave the composer looking
  /// broken for as long as the request takes — and on the connection this whole
  /// design exists for, that can be forever.
  Future<ThreadMessage> sendMessage({
    required String otherPartyId,
    required String body,
    void Function(ThreadMessage queued)? onQueued,
  }) async {
    final messageId = _uuid.v4();
    final createdAt = DateTime.now().toUtc();

    await _db.chatoutboxDao.insertMessagePending(
      ChatOutBoxTableCompanion.insert(
        messageId: messageId,
        otherPartyId: otherPartyId,
        body: body,
        createdAt: createdAt,
        chatMessageStatus: Value(ChatMessageStatus.pending.index),
      ),
    );

    // Registered before the send so the group broadcast, which can beat the ack
    // back to us, is recognised as our own and dropped.
    _knownIds.add(messageId);

    onQueued?.call(ThreadMessage(
      messageId: messageId,
      body: body,
      timestamp: createdAt,
      isMine: true,
      status: ChatMessageStatus.pending,
    ));

    return _attemptSend(
      messageId: messageId,
      otherPartyId: otherPartyId,
      body: body,
      createdAt: createdAt,
    );
  }

  /// Manual retry for a message the replay loop gave up on.
  ///
  /// Goes through the same [_attemptSend] as a first send, and deliberately
  /// keeps the original id — a retry with a fresh id would look like a brand new
  /// message to the server and could duplicate one it already stored.
  Future<ThreadMessage?> retryMessage(
    String messageId, {
    void Function(ThreadMessage queued)? onQueued,
  }) async {
    final row = await _db.chatoutboxDao.findMessage(messageId);
    if (row == null) return null;

    await _db.chatoutboxDao.resetToPending(messageId);
    _replayAttempts.remove(messageId);
    _knownIds.add(messageId);

    onQueued?.call(ThreadMessage(
      messageId: row.messageId,
      body: row.body,
      timestamp: row.createdAt,
      isMine: true,
      status: ChatMessageStatus.pending,
    ));

    return _attemptSend(
      messageId: row.messageId,
      otherPartyId: row.otherPartyId,
      body: row.body,
      createdAt: row.createdAt,
    );
  }

  /// One attempt at the wire, with the outbox updated to match the outcome.
  ///
  /// Returns the resulting bubble either way: a send that failed is still a
  /// message the user wrote and must keep seeing.
  Future<ThreadMessage> _attemptSend({
    required String messageId,
    required String otherPartyId,
    required String body,
    required DateTime createdAt,
  }) async {
    try {
      final sealed = await _crypto.encrypt(
        otherPartyId: otherPartyId,
        plaintext: body,
      );

      final ack = await _signalR.send(
        otherPartyId: otherPartyId,
        messageId: messageId,
        body: sealed.ciphertext,
        iv: sealed.iv,
        encryptionVersion: sealed.version,
        ephemeralPublicKeyJwk: sealed.ephemeralPublicKeyJwk,
        keys: sealed.keys,
        senderDeviceId: await _crypto.deviceId(),
      );
      await _db.chatoutboxDao.markMessagePendingAsSent(messageId);
      _replayAttempts.remove(messageId);
      // Remember it before the group broadcast echoes it back to us.
      _knownIds.add(ack.id);
      // Built from the plaintext still in hand, not from the ack. The ack is a
      // faithful copy of what the server stored, which means its body is the
      // ciphertext we just sent -- rendering it would put base64 in the bubble.
      return ThreadMessage.fromChatMessage(
        ack.decrypted(body),
        otherPartyId: otherPartyId,
      );
    } catch (_) {
      // No ack -- or no key to encrypt with, which lands here too. Either way
      // that is *all* we know: the server may have stored it and lost the
      // reply, or never received it, or never been asked. Guessing loses the
      // message, so the row stays pending and the next reconnect decides.
      _knownIds.add(messageId);
      return ThreadMessage(
        messageId: messageId,
        body: body,
        timestamp: createdAt,
        isMine: true,
        status: ChatMessageStatus.pending,
      );
    }
  }

  // ── Replay ────────────────────────────────────────────────────────────────

  /// Every thread with a pending row, replayed one thread at a time.
  ///
  /// [replayPending] already serialises a single thread's own messages so
  /// their order survives; there is no equivalent constraint *between*
  /// threads, since each is a separate conversation. Sequential rather than
  /// concurrent anyway, so one thread's failure (which stops [replayPending]
  /// at the first error) can't be misread as reason to stop the others — each
  /// gets its own independent attempt.
  Future<void> _replayAllPending() async {
    final threads = await _db.chatoutboxDao.getOtherPartyIdsWithPendingMessages();
    for (final otherPartyId in threads) {
      await replayPending(otherPartyId);
    }
  }

  /// §4 "On reconnect": resend everything still pending for [otherPartyId], in
  /// the order it was typed.
  ///
  /// Sequential, awaiting each ack before starting the next. Firing them
  /// concurrently would be faster but SignalR only guarantees ordering *within*
  /// one invocation, so three parallel sends can be stored in any order — and in
  /// a conversation the order is the meaning.
  Future<void> replayPending(String otherPartyId) async {
    final pending = await _db.chatoutboxDao.getPendingMessages(otherPartyId);

    for (final row in pending) {
      try {
        // Encrypted again from the outbox plaintext rather than resending a
        // stored ciphertext, and that is not merely tolerable -- it is the
        // correct thing to do twice over. An IV must never be reused with the
        // same key, so a fresh envelope per attempt is what the algorithm asks
        // for; and if the peer reinstalled since the first attempt, this is what
        // encrypts to the key they actually hold now. The server dedupes on
        // messageId, so whichever attempt landed is the one kept.
        final sealed = await _crypto.encrypt(
          otherPartyId: row.otherPartyId,
          plaintext: row.body,
        );

        final ack = await _signalR.send(
          otherPartyId: row.otherPartyId,
          // Same id as the original attempt — this is what lets the server tell
          // a replay from a new message and store it exactly once.
          messageId: row.messageId,
          body: sealed.ciphertext,
          iv: sealed.iv,
          encryptionVersion: sealed.version,
          ephemeralPublicKeyJwk: sealed.ephemeralPublicKeyJwk,
          keys: sealed.keys,
          senderDeviceId: await _crypto.deviceId(),
        );
        await _db.chatoutboxDao.markMessagePendingAsSent(row.messageId);
        _replayAttempts.remove(row.messageId);
        _knownIds.add(ack.id);
        // Emitted even though this id is already known: the thread is showing it
        // as pending, and this is the event that settles it to sent. Listeners
        // upsert by messageId rather than appending blindly.
        _threadMessages.add(
          ThreadMessage.fromChatMessage(
            ack.decrypted(row.body),
            otherPartyId: otherPartyId,
          ),
        );
      } catch (_) {
        final attempts = (_replayAttempts[row.messageId] ?? 0) + 1;
        _replayAttempts[row.messageId] = attempts;

        if (attempts >= maxReplayAttempts) {
          await _db.chatoutboxDao.markMessageFailed(row.messageId);
          _replayAttempts.remove(row.messageId);
        }

        // Stop at the first failure rather than skipping ahead: sending a later
        // message while an earlier one is still queued would reorder the thread.
        return;
      }
    }
  }

  // ── Receiving ─────────────────────────────────────────────────────────────

  /// Live messages for [otherPartyId], already deduped.
  ///
  /// §4's "own message arrives twice" subtlety: the hub broadcasts to the whole
  /// group including the sender, so a message you just sent comes back here as
  /// well as through send()'s return value. Filtering here rather than in a
  /// widget means every surface gets it right for free.
  Stream<ThreadMessage> incomingFor(String otherPartyId) {
    return _threadMessages.stream.where((_) => _activeThreadId == otherPartyId);
  }

  /// Every message that arrives, whichever thread it belongs to.
  ///
  /// Separate from [incomingFor] because the two have opposite requirements. The
  /// thread view wants exactly one thread's messages, deduped against what it is
  /// already showing. The conversation list wants *all* of them and no dedup at
  /// all — its job is precisely to tell you about the conversation you are not
  /// looking at.
  Stream<ChatMessage> get allIncoming => _allIncoming.stream;

  Future<void> _handleIncoming(ChatMessage message) async {
    // Which thread this belongs to is read before anything is awaited: the
    // active thread can change while a decryption is in flight, and a message
    // must not be appended to a conversation the user has since switched away
    // from.
    final thread = _activeThreadId;

    final plain = await _decrypt(message, _peerFor(message));

    // Before the active-thread filter, and never deduped: the inbox has to hear
    // about a message whether or not its thread is open, which is the whole
    // reason this device now stays in every conversation's group.
    _allIncoming.add(plain);

    if (thread == null) return;

    // The hub tags every message with both sides of the pair, so a message for
    // another thread is recognisable without asking the server.
    final belongsToThread =
        message.clientId == thread || message.senderId == thread;
    if (!belongsToThread) return;

    if (!_knownIds.add(message.id)) return;

    _threadMessages.add(
      ThreadMessage.fromChatMessage(plain, otherPartyId: thread),
    );
  }

  /// Whose key decrypts [message], from this device's point of view.
  ///
  /// Not the sender. A message this device sent comes back through the group
  /// broadcast too, and it was encrypted to the *other* party — deriving a
  /// secret against our own public key would produce a real key that decrypts
  /// nothing, and the conversation row would report our own message as
  /// unreadable.
  ///
  /// A message names both sides of its pair and this client has never been told
  /// which one it is (docs/chat-architecture.md §5), so the answer comes from
  /// the threads this device has joined: exactly one of the pair is a
  /// conversation it is watching, and that one is the peer.
  String? _peerFor(ChatMessage message) {
    for (final candidate in [message.clientId, message.trainerId]) {
      if (_watchedThreads.contains(candidate)) return candidate;
    }

    // The trainee app has one thread and never calls watchConversations, so the
    // open thread is the only membership it has.
    final thread = _activeThreadId;
    if (thread == message.clientId || thread == message.trainerId) return thread;

    return null;
  }

  // ── Conversation list ─────────────────────────────────────────────────────

  /// The conversation list, with each row's preview already decrypted.
  ///
  /// Decrypted here rather than in `ConversationSummary.fromJson`, which is a
  /// synchronous factory and cannot await a key derivation. Doing it in this
  /// layer also means `ChatProvider` keeps working untouched: by the time a
  /// preview reaches it, from here or from a live message, it is plaintext.
  Future<List<ConversationSummary>> getConversations() async {
    final deviceId = await _crypto.deviceId();
    final raw = await _api.fetchConversations(deviceId: deviceId);

    final summaries = <ConversationSummary>[];
    for (final json in raw) {
      final summary = ConversationSummary.fromJson(json);
      summaries.add(
        summary.withPreview(
          await _crypto.decrypt(
            otherPartyId: summary.clientId,
            ciphertext: summary.lastMessagePreview,
            iv: json['lastMessageIv'] as String?,
            version: json['lastMessageEncryptionVersion'] as int? ?? 0,
            ephemeralPublicKeyJwk: json['lastMessageEphemeralPublicKeyJwk'] as String?,
            wrappedKey: json['lastMessageWrappedKey'] as String?,
            wrappedKeyIv: json['lastMessageWrappedIv'] as String?,
          ),
        ),
      );
    }
    return summaries;
  }

  Future<void> markRead(String otherPartyId) => _api.markRead(otherPartyId);

  // ── Encryption boundary ───────────────────────────────────────────────────

  /// One message, with its body replaced by the plaintext — or by null when
  /// this device cannot read it.
  ///
  /// A null body here is not a failure to handle; it is a message state the UI
  /// draws (see `ThreadMessage.isUndecryptable`). It happens whenever the key
  /// that could read this body no longer exists: the sender reinstalled, or
  /// this device did, and there is no backup of either private key by design.
  Future<ChatMessage> _decrypt(ChatMessage message, String? otherPartyId) async {
    // No peer means no key, which is the same outcome as a key that no longer
    // works: the message is real and this device cannot read it.
    if (otherPartyId == null) return message.decrypted(null);

    // Copied into a local before the closure below captures it, so the
    // non-null-ness is a property of the local rather than of a promotion the
    // closure has to preserve.
    final peer = otherPartyId;

    Future<String?> attempt() => _crypto.decrypt(
      otherPartyId: peer,
      ciphertext: message.body,
      iv: message.iv,
      version: message.encryptionVersion,
      ephemeralPublicKeyJwk: message.ephemeralPublicKeyJwk,
      wrappedKey: message.wrappedKey,
      wrappedKeyIv: message.wrappedKeyIv,
    );

    var plaintext = await attempt();

    // One retry against a freshly fetched peer key, and only one, the first time
    // this thread sees a failure. **Version 1 only** — a version-2 failure means
    // this device simply has no wrapped key for that message (it predates the
    // device, or the device was pruned server-side), and no amount of refetching
    // a peer key changes that: version 2 never looks at one.
    //
    // This is the recovery path for a peer who reinstalled under version 1:
    // they published a new public key, this device is still holding the one it
    // cached, and *every* message they send from now on fails against it.
    // Without this the thread never recovers on its own — the cache is only
    // wrong, never stale, so nothing else would ever go and look.
    //
    // Bounded by [_refetchedPeers] because the far more common cause of a
    // failure is a message genuinely encrypted to a key that no longer exists
    // anywhere. Retrying per message would turn scrolling through old history
    // into one key fetch per bubble.
    if (plaintext == null &&
        message.body != null &&
        message.encryptionVersion == ChatEncryption.ecdhP256AesGcm &&
        _refetchedPeers.add(peer)) {
      await _crypto.forget(peer);
      plaintext = await attempt();
    }

    return message.decrypted(plaintext);
  }

  Future<void> dispose() async {
    await _incomingSubscription?.cancel();
    await _reconnectedSubscription?.cancel();
    await _threadMessages.close();
    await _allIncoming.close();
  }
}
