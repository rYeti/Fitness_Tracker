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

  /// Resend attempts per message id, for the bounded retry in [replayPending].
  ///
  /// In memory rather than a column: a counter that resets when the app restarts
  /// is the behaviour we want anyway — a fresh launch is a fresh chance, and it
  /// keeps the Drift schema unchanged.
  final Map<String, int> _replayAttempts = {};

  final _threadMessages = StreamController<ThreadMessage>.broadcast();
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

  /// Joins [otherPartyId]'s hub group, leaving the previous thread's first.
  ///
  /// Staying joined to every thread at once would deliver messages for threads
  /// that aren't on screen, which the UI would then have to filter out anyway.
  Future<void> openThread(String otherPartyId) async {
    if (_activeThreadId == otherPartyId) return;

    final previous = _activeThreadId;
    if (previous != null) await _signalR.leaveGroup(previous);

    _activeThreadId = otherPartyId;
    _knownIds.clear();
    await _signalR.joinGroup(otherPartyId);
  }

  Future<void> closeThread() async {
    final thread = _activeThreadId;
    if (thread == null) return;

    _activeThreadId = null;
    _knownIds.clear();
    await _signalR.leaveGroup(thread);
  }

  /// History (REST) merged with anything still unsent locally, so a message the
  /// user just wrote stays on screen while it is in flight rather than
  /// disappearing until the ack lands.
  Future<List<ThreadMessage>> loadThread(String otherPartyId) async {
    final history = await _api.fetchHistory(otherPartyId);
    final unsent = await _db.chatoutboxDao.getUnsentMessages(otherPartyId);

    final messages = [
      for (final json in history)
        ThreadMessage.fromChatMessage(
          ChatMessage.fromJson(json),
          otherPartyId: otherPartyId,
        ),
      for (final row in unsent) ThreadMessage.fromOutbox(row),
    ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

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

  void _handleIncoming(ChatMessage message) {
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
  }
}
