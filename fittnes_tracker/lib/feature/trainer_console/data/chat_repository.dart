import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/feature/trainer_console/data/chat_api.dart';
import 'package:ForgeForm/feature/trainer_console/data/chat_signalr_client.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/chat_message.dart';

/// The glue layer — owns the outbox DAO and the SignalR client, mediates
/// between them. This is where the reconnect/replay logic lives (see
/// chat-flutter-roadmap.md §4 and its §4a walkthrough for the full
/// state-by-state reasoning behind each rule below).
class ChatRepository {
  final AppDatabase _db;
  final ChatApi _api;
  final ChatSignalRClient _signalR;

  ChatRepository({
    required AppDatabase db,
    ChatApi? api,
    required ChatSignalRClient signalR,
  }) : _db = db,
       _api = api ?? ChatApi(),
       _signalR = signalR;

  /// History (REST) merged with any still-`pending` outbox rows for this
  /// thread, so a message the user just sent but hasn't gotten an ack for
  /// yet still shows, visually marked as sending (§6).
  Future<List<ChatMessage>> loadThread(String clientId) async {
    // TODO: final history = await _api.fetchHistory(clientId), map to
    // ChatMessage; final pending = await
    // _db.chatoutboxDao.getPendingMessages(clientId); merge (pending rows
    // need a ChatMessage-shaped view — see chat-flutter-roadmap.md §2's note
    // that the outbox row and ChatMessage are deliberately separate types,
    // so this merge needs an explicit mapping, not a cast), sort by time.
    throw UnimplementedError();
  }

  /// §4 "Sending a message": generate messageId, write pending outbox row,
  /// call SignalR send, mark sent on ack, leave pending on
  /// failure/timeout (no inline retry — that's the reconnect handler below).
  Future<ChatMessage> sendMessage({required String clientId, required String body}) async {
    // TODO: const uuid = Uuid(); final messageId = uuid.v4() (package
    // already in pubspec.yaml); insert pending row via
    // _db.chatoutboxDao.insertMessagePending(...); await
    // _signalR.send(clientId: clientId, messageId: messageId, body: body);
    // on success: _db.chatoutboxDao.markMessagePendingAsSent(messageId).
    throw UnimplementedError();
  }

  /// §4 "On reconnect": query pending rows for [clientId] ordered by
  /// createdAt, resend each *sequentially* (await each ack before the next —
  /// SignalR doesn't guarantee cross-invocation ordering), same messageId
  /// each time so the server's dedup-on-Id makes replay idempotent either
  /// way. Wire this to `_signalR.onReconnected`'s stream, not a timer.
  Future<void> replayPending(String clientId) async {
    throw UnimplementedError();
  }

  /// Live incoming messages for the active thread, deduped against
  /// send()'s own ack — §4's "own message arrives twice" subtlety (ack
  /// return value + the group broadcast both hit the sender). Dedupe on
  /// `messageId`/`id` before this reaches the provider, or the sender's own
  /// bubble doubles up.
  Stream<ChatMessage> incomingFor(String clientId) {
    throw UnimplementedError();
  }
}
