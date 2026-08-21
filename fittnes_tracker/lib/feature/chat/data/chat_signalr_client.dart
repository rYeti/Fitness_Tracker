import 'package:ForgeForm/feature/chat/domain/models/chat_message.dart';

/// Where the connection currently is, as far as the UI needs to care.
///
/// Lives with the transport rather than the provider because the transport is
/// what actually knows — the provider only mirrors it onto the screen.
enum ChatConnectionStatus { connected, reconnecting, disconnected }

/// Wire protocol only — no outbox/business logic here, that's
/// [ChatRepository]'s job (chat-flutter-roadmap.md §3/§4). Matches
/// `FitTracker.Api/Hubs/ChatHub.cs`'s three RPCs + its group-broadcast
/// `ReceiveMessage` event.
///
/// Kept as an interface for two reasons. The obvious one: the SignalR package
/// is replaceable without touching anything else. The one that pays off daily:
/// the states this feature has to get right — a send that never resolves, an
/// ack lost after the server stored the message, a reconnect at an exact moment
/// — cannot be produced on demand against a real socket, but are one line each
/// against a fake implementing this.
abstract class ChatSignalRClient {
  /// Opens the hub connection with the JWT as `?access_token=` (WebSocket
  /// transport can't set headers — see CLAUDE.md's existing note on this).
  Future<void> connect();

  /// Closes the connection. Called when the last chat surface goes away, not on
  /// every thread switch — [leaveGroup] handles that.
  Future<void> disconnect();

  Future<void> joinGroup(String otherPartyId);

  Future<void> leaveGroup(String otherPartyId);

  /// Sends one message and awaits its ack (the persisted `ChatMessageDto`
  /// SendMessageAsync returns) or throws/times out on failure — the caller
  /// (repository) decides what "no ack" means, this layer just reports it.
  ///
  /// [otherPartyId] is the client's id when a trainer sends and the trainer's id
  /// when a client does; the hub resolves which side the caller is on.
  Future<ChatMessage> send({
    required String otherPartyId,
    required String messageId,
    required String body,
  });

  /// Broadcast stream — every `ReceiveMessage` for a joined group, including
  /// the sender's own messages (see roadmap §4's dedup note: a sent message
  /// arrives here *in addition to* send()'s ack return value).
  Stream<ChatMessage> get incomingMessages;

  /// Fires when the underlying connection re-establishes after a drop —
  /// the trigger for ChatRepository's outbox replay (§4), not a timer.
  Stream<void> get onReconnected;

  /// Connection state for the "reconnecting…" banner.
  Stream<ChatConnectionStatus> get connectionStatus;
}
