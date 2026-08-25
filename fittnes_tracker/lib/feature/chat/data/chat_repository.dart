import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/feature/chat/data/chat_api.dart';
import 'package:ForgeForm/feature/chat/data/chat_signalr_client.dart';
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

  /// Resend attempts per message id, for the bounded retry in [replayPending].
  ///
  /// In memory rather than a column: a counter that resets when the app restarts
  /// is the behaviour we want anyway — a fresh launch is a fresh chance, and it
  /// keeps the Drift schema unchanged.
  final Map<String, int> _replayAttempts = {};

  final _threadMessages = StreamController<ThreadMessage>.broadcast();
  final _allIncoming = StreamController<ChatMessage>.broadcast();
  StreamSubscription<ChatMessage>? _incomingSubscription;
  StreamSubscription<void>? _reconnectedSubscription;

  ChatRepository({
    required AppDatabase db,
    ChatApi? api,
    required ChatSignalRClient signalR,
    this.maxReplayAttempts = 3,
  }) : _db = db,
       _api = api ?? ChatApi(),
       _signalR = signalR {
    // Replay is driven by the reconnect signal, never a timer: a timer would
    // either fire uselessly while the connection is still down or sit idle after
    // it comes back.
    _reconnectedSubscription = _signalR.onReconnected.listen((_) {
      final thread = _activeThreadId;
      if (thread != null) unawaited(replayPending(thread));
    });

    _incomingSubscription = _signalR.incomingMessages.listen(_handleIncoming);
  }

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
    final history = await _api.fetchHistory(otherPartyId);
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
        ChatMessage.fromJson(json),
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
      final ack = await _signalR.send(
        otherPartyId: otherPartyId,
        messageId: messageId,
        body: body,
      );
      await _db.chatoutboxDao.markMessagePendingAsSent(messageId);
      _replayAttempts.remove(messageId);
      // Remember it before the group broadcast echoes it back to us.
      _knownIds.add(ack.id);
      return ThreadMessage.fromChatMessage(ack, otherPartyId: otherPartyId);
    } catch (_) {
      // No ack. That is *all* we know — the server may have stored it and lost
      // the reply, or never received it. Guessing either way loses the message,
      // so the row stays pending and the next reconnect decides.
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
        final ack = await _signalR.send(
          otherPartyId: row.otherPartyId,
          // Same id as the original attempt — this is what lets the server tell
          // a replay from a new message and store it exactly once.
          messageId: row.messageId,
          body: row.body,
        );
        await _db.chatoutboxDao.markMessagePendingAsSent(row.messageId);
        _replayAttempts.remove(row.messageId);
        _knownIds.add(ack.id);
        // Emitted even though this id is already known: the thread is showing it
        // as pending, and this is the event that settles it to sent. Listeners
        // upsert by messageId rather than appending blindly.
        _threadMessages.add(
          ThreadMessage.fromChatMessage(ack, otherPartyId: otherPartyId),
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

  void _handleIncoming(ChatMessage message) {
    // Before the active-thread filter, and never deduped: the inbox has to hear
    // about a message whether or not its thread is open, which is the whole
    // reason this device now stays in every conversation's group.
    _allIncoming.add(message);

    final thread = _activeThreadId;
    if (thread == null) return;

    // The hub tags every message with both sides of the pair, so a message for
    // another thread is recognisable without asking the server.
    final belongsToThread =
        message.clientId == thread || message.senderId == thread;
    if (!belongsToThread) return;

    if (!_knownIds.add(message.id)) return;

    _threadMessages.add(
      ThreadMessage.fromChatMessage(message, otherPartyId: thread),
    );
  }

  // ── Conversation list ─────────────────────────────────────────────────────

  Future<List<ConversationSummary>> getConversations() async {
    final raw = await _api.fetchConversations();
    return raw.map(ConversationSummary.fromJson).toList();
  }

  Future<void> markRead(String otherPartyId) => _api.markRead(otherPartyId);

  Future<void> dispose() async {
    await _incomingSubscription?.cancel();
    await _reconnectedSubscription?.cancel();
    await _threadMessages.close();
    await _allIncoming.close();
  }
}
