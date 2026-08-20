import 'package:flutter/foundation.dart';
import 'package:ForgeForm/feature/trainer_console/data/chat_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/chat_message.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/conversation_summary.dart';

enum ChatConnectionStatus { connected, reconnecting, disconnected }

/// Per CLAUDE.md's shared-state rule: lives at the app-shell level alongside
/// ActiveClientProvider, not re-created per screen — switching the active
/// client re-derives [thread] without a full navigation reload (roadmap §5,
/// §7). Owns the conversation list (all clients with previews) plus the
/// active thread (merged history + pending + live, per ChatRepository).
class ChatProvider extends ChangeNotifier {
  final ChatRepository _repository;

  ChatProvider({required ChatRepository repository}) : _repository = repository;

  List<ConversationSummary> _conversations = [];
  List<ChatMessage> _thread = [];
  ChatConnectionStatus _connectionStatus = ChatConnectionStatus.disconnected;
  bool _isLoading = false;
  String? _error;

  List<ConversationSummary> get conversations => _conversations;
  List<ChatMessage> get thread => _thread;
  ChatConnectionStatus get connectionStatus => _connectionStatus;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Loads the roster-with-previews list for the conversation-list screen
  /// (desktop left column / mobile list screen).
  Future<void> loadConversations() async {
    // TODO: needs a repository method that joins roster + last-message —
    // not yet on ChatRepository; add one there first (mirrors
    // TrainerConsoleRepository.getRoster's shape).
  }

  /// Opens (or switches to) [clientId]'s thread: joins its SignalR group,
  /// loads merged history, subscribes to incoming messages. Per roadmap §7,
  /// leave the previous client's group on switch — don't stay joined to
  /// every client's group at once.
  Future<void> openThread(String clientId) async {
    // TODO: leave previous group if one is joined; await
    // _repository's join/loadThread; subscribe to
    // _repository.incomingFor(clientId), append+notifyListeners on each
    // event; notifyListeners() once loaded.
  }

  Future<void> sendMessage(String clientId, String body) async {
    // TODO: optimistically append a pending bubble, call
    // _repository.sendMessage(...), reconcile on ack/failure. A `failed`
    // bubble (retry budget exhausted, roadmap §4a) needs a manual
    // "tap to retry" affordance per §6 — this method should be re-callable
    // for that retry, not a separate code path.
  }

  void closeThread() {
    // TODO: leave the SignalR group, clear _thread, cancel the incoming
    // subscription. Call this on mobile's back-arrow-to-list and on desktop
    // navigation away from Messages.
  }
}
