import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:ForgeForm/feature/chat/data/chat_repository.dart';
import 'package:ForgeForm/feature/chat/data/chat_signalr_client.dart';
import 'package:ForgeForm/feature/chat/domain/models/conversation_summary.dart';
import 'package:ForgeForm/feature/chat/domain/models/thread_message.dart';

export 'package:ForgeForm/feature/chat/data/chat_signalr_client.dart'
    show ChatConnectionStatus;

/// Per CLAUDE.md's shared-state rule: lives at the app-shell level alongside
/// ActiveClientProvider, not re-created per screen — switching the active
/// client re-derives [thread] without a full navigation reload (roadmap §5,
/// §7). Owns the conversation list plus the active thread (merged history +
/// unsent + live, per ChatRepository).
class ChatProvider extends ChangeNotifier {
  final ChatRepository _repository;

  ChatProvider({required ChatRepository repository}) : _repository = repository {
    _statusSubscription = _repository.connectionStatus.listen((status) {
      _connectionStatus = status;
      notifyListeners();
    });
  }

  List<ConversationSummary> _conversations = [];
  List<ThreadMessage> _thread = [];
  ChatConnectionStatus _connectionStatus = ChatConnectionStatus.disconnected;
  bool _isLoading = false;
  bool _isThreadLoading = false;
  String? _error;
  String? _threadError;

  /// A send that failed before it reached the network — distinct from
  /// [_threadError] because it must not blank out an otherwise-fine thread.
  String? _sendError;

  StreamSubscription<ThreadMessage>? _incomingSubscription;
  StreamSubscription<ChatConnectionStatus>? _statusSubscription;

  List<ConversationSummary> get conversations => _conversations;
  List<ThreadMessage> get thread => _thread;
  ChatConnectionStatus get connectionStatus => _connectionStatus;
  bool get isLoading => _isLoading;
  bool get isThreadLoading => _isThreadLoading;
  String? get error => _error;
  String? get threadError => _threadError;
  String? get sendError => _sendError;
  String? get activeThreadId => _repository.activeThreadId;

  /// Loads the conversation list for the list pane.
  Future<void> loadConversations() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _conversations = await _repository.getConversations();
    } catch (_) {
      // Deliberately not left as an empty list: "no conversations" and "the
      // request failed" look identical on screen, and only one of them has a
      // retry that helps.
      _error = 'Could not load your conversations.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Opens (or switches to) [otherPartyId]'s thread: joins its hub group, loads
  /// the merged history, and subscribes to live messages.
  Future<void> openThread(String otherPartyId) async {
    _isThreadLoading = true;
    _threadError = null;
    _sendError = null;
    _thread = [];
    notifyListeners();

    try {
      // Inside the try, not ahead of it. Joining the hub group is a network call
      // and fails like one — and when it threw from out here the exception
      // escaped past the `finally`, pinning _isThreadLoading true for the rest of
      // the screen's life. Both thread bodies check that flag first, so every
      // later message repainted the loading skeleton instead of itself: chat
      // looked merely slow rather than broken, with no error and no retry.
      await _repository.openThread(otherPartyId);

      await _incomingSubscription?.cancel();
      _incomingSubscription =
          _repository.incomingFor(otherPartyId).listen(_upsert);

      final loaded = await _repository.loadThread(otherPartyId);
      // A message can land between subscribing and the history returning.
      // Assigning `loaded` straight over `_thread` would silently swallow it, so
      // anything already here that history didn't include is kept.
      final live = _thread.where(
        (m) => !loaded.any((l) => l.messageId == m.messageId),
      );
      _thread = [...loaded, ...live]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _markConversationRead(otherPartyId);
    } catch (_) {
      _threadError = 'Could not load this conversation.';
    } finally {
      _isThreadLoading = false;
      notifyListeners();
    }
  }

  Future<void> closeThread() async {
    await _incomingSubscription?.cancel();
    _incomingSubscription = null;
    await _repository.closeThread();
    _thread = [];
    _threadError = null;
    _sendError = null;
    notifyListeners();
  }

  /// Sends [body], showing the bubble straight away rather than waiting for the
  /// server — a slow network shouldn't look like a dead send button.
  Future<void> sendMessage(String otherPartyId, String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;

    _sendError = null;

    try {
      // Two updates on purpose: the first the moment the message is queued, the
      // second when the wire call settles. Same id both times, so _upsert
      // replaces rather than appends.
      final sent = await _repository.sendMessage(
        otherPartyId: otherPartyId,
        body: trimmed,
        onQueued: _upsert,
      );
      _upsert(sent);
    } catch (_) {
      // A failed *send* is already handled inside the repository, which keeps the
      // outbox row pending and hands back a bubble either way. Reaching here
      // means something upstream of the network broke — the local outbox write
      // itself, most likely — so there is no bubble and nothing queued.
      //
      // Left unhandled, that was silence: the composer cleared, no message
      // appeared, and nothing anywhere said why. It is the single worst failure a
      // messaging app has, so it gets a visible, dismissible strip of its own.
      //
      // Deliberately *not* _threadError: that replaces the whole list with a
      // full-screen error, which would throw away a perfectly good thread over
      // one message that didn't make it.
      _sendError = 'Message not sent. Check your connection and try again.';
      notifyListeners();
    }
  }

  /// Dismisses the send-failure strip. Also cleared by the next successful send.
  void clearSendError() {
    if (_sendError == null) return;
    _sendError = null;
    notifyListeners();
  }

  /// Retries one message the replay loop gave up on. Same path as a first send,
  /// so there is only ever one implementation of "get this message out".
  Future<void> retryMessage(String messageId) async {
    final retried =
        await _repository.retryMessage(messageId, onQueued: _upsert);
    if (retried != null) _upsert(retried);
  }

  /// Adds a message, or replaces the one already there with the same id.
  ///
  /// Replacement is what settles a pending bubble to sent when its ack finally
  /// arrives — the same message, a later state, not a second bubble.
  void _upsert(ThreadMessage message) {
    final index =
        _thread.indexWhere((m) => m.messageId == message.messageId);
    if (index == -1) {
      _thread = [..._thread, message];
    } else {
      final next = [..._thread];
      next[index] = message;
      _thread = next;
    }
    notifyListeners();
  }

  void _markConversationRead(String otherPartyId) {
    final index =
        _conversations.indexWhere((c) => c.clientId == otherPartyId);
    if (index == -1 || _conversations[index].unreadCount == 0) return;

    final current = _conversations[index];
    final next = [..._conversations];
    next[index] = ConversationSummary(
      clientId: current.clientId,
      clientName: current.clientName,
      lastMessagePreview: current.lastMessagePreview,
      lastMessageAt: current.lastMessageAt,
      unreadCount: 0,
    );
    _conversations = next;
  }

  @override
  void dispose() {
    _incomingSubscription?.cancel();
    _statusSubscription?.cancel();
    _repository.dispose();
    super.dispose();
  }
}
