import 'package:ForgeForm/feature/trainer_console/domain/models/chat_message.dart';

/// Wire protocol only — no outbox/business logic here, that's
/// [ChatRepository]'s job (chat-flutter-roadmap.md §3/§4). Matches
/// `FitTracker.Api/Hubs/ChatHub.cs`'s three RPCs + its group-broadcast
/// `ReceiveMessage` event.
///
/// TODO (open decision, not made yet): pick a Dart↔ASP.NET Core SignalR
/// client package (`signalr_netcore` is the common choice — verify current
/// maintenance status before pinning a version) and add it to pubspec.yaml.
/// Not added here since dependency choice is the kind of call CLAUDE.md's
/// "owner prefers to write implementation code himself" note is about.
abstract class ChatSignalRClient {
  /// Builds the hub connection with the JWT as `?access_token=` (WebSocket
  /// transport can't set headers — see CLAUDE.md's existing note on this).
  Future<void> connect();

  Future<void> joinGroup(String clientId);

  Future<void> leaveGroup(String clientId);

  /// Sends one message and awaits its ack (the persisted `ChatMessageDto`
  /// SendMessageAsync returns) or throws/times out on failure — the caller
  /// (repository) decides what "no ack" means, this layer just reports it.
  Future<ChatMessage> send({
    required String clientId,
    required String messageId,
    required String body,
  });

  /// Broadcast stream — every `ReceiveMessage` for a joined group, including
  /// the sender's own messages (see roadmap §4's dedup note: a sent message
  /// arrives here *in addition to* send()'s ack return value).
  Stream<ChatMessage> get incomingMessages;

  /// Fires when the underlying connection re-establishes after a drop —
  /// the trigger for ChatRepository's outbox replay (§4), not a timer. Named
  /// per whichever package is chosen's `onreconnected`-equivalent.
  Stream<void> get onReconnected;
}
