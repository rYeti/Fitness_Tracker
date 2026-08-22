import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/feature/chat/data/chat_api.dart';
import 'package:ForgeForm/feature/chat/data/chat_signalr_client.dart';
import 'package:ForgeForm/feature/chat/domain/models/chat_message.dart';

/// A real [AppDatabase] on an in-memory Sqlite file.
///
/// The outbox is the part of chat most worth testing directly (roadmap §1), and
/// it only behaves like itself against a real Drift executor — a hand-written
/// fake DAO would let the tests agree with themselves about ordering and
/// filtering rather than checking what Drift actually does.
AppDatabase newTestDatabase() => AppDatabase.test(NativeDatabase.memory());

/// Stands in for the SignalR connection.
///
/// Everything hard about chat happens in states a real socket won't reproduce on
/// demand: a send that never resolves, a send that throws, a reconnect firing at
/// an exact moment, the same message arriving twice. This fake makes each of
/// those a single line in a test, which is the whole reason [ChatSignalRClient]
/// is an interface rather than a concrete class.
class FakeChatSignalRClient implements ChatSignalRClient {
  final _incoming = StreamController<ChatMessage>.broadcast();
  final _reconnected = StreamController<void>.broadcast();
  final _status = StreamController<ChatConnectionStatus>.broadcast();

  /// Every `send` in call order — the assertion target for replay ordering and
  /// for "the retry reused the original messageId".
  final List<({String otherPartyId, String messageId, String body})> sent = [];

  /// Group membership calls, so a test can assert the previous client's group is
  /// left before the next is joined.
  final List<String> joined = [];
  final List<String> left = [];

  bool connected = false;

  /// When set, `send` throws this instead of acking. Simulates "no ack" — which
  /// from the client's side is indistinguishable from "the server never got it".
  Object? throwOnSend;

  /// When non-null, `send` waits on this before completing, so a test can hold a
  /// message in flight and act while it is still pending.
  Completer<void>? holdSend;

  /// Fails only the first [failFirstNSends] calls, then acks. Models a bounded
  /// outage rather than a permanent one.
  int failFirstNSends = 0;

  /// When set, `joinGroup` throws this.
  ///
  /// Joining is the first network call a thread makes and the one most likely to
  /// fail in practice — the socket may still be opening, or the hub may reject
  /// the pair outright — but nothing exercised that path, so a bug that pinned
  /// the screen in its loading state forever went unnoticed.
  Object? throwOnJoin;

  @override
  Future<void> connect() async {
    connected = true;
    _status.add(ChatConnectionStatus.connected);
  }

  @override
  Future<void> disconnect() async {
    connected = false;
    _status.add(ChatConnectionStatus.disconnected);
  }

  @override
  Future<void> joinGroup(String otherPartyId) async {
    if (throwOnJoin != null) throw throwOnJoin!;
    joined.add(otherPartyId);
  }

  @override
  Future<void> leaveGroup(String otherPartyId) async => left.add(otherPartyId);

  @override
  Future<ChatMessage> send({
    required String otherPartyId,
    required String messageId,
    required String body,
  }) async {
    sent.add((otherPartyId: otherPartyId, messageId: messageId, body: body));

    if (holdSend != null) await holdSend!.future;

    if (failFirstNSends > 0) {
      failFirstNSends--;
      throw StateError('connection lost');
    }
    if (throwOnSend != null) throw throwOnSend!;

    return ack(messageId: messageId, otherPartyId: otherPartyId, body: body);
  }

  @override
  Stream<ChatMessage> get incomingMessages => _incoming.stream;

  @override
  Stream<void> get onReconnected => _reconnected.stream;

  @override
  Stream<ChatConnectionStatus> get connectionStatus => _status.stream;

  // ── Test controls ─────────────────────────────────────────────────────────

  /// Fires the reconnect signal that drives outbox replay (roadmap §4).
  void fireReconnected() => _reconnected.add(null);

  void emitStatus(ChatConnectionStatus status) => _status.add(status);

  /// Delivers a message as the hub's `ReceiveMessage` broadcast would.
  void emitIncoming(ChatMessage message) => _incoming.add(message);

  Future<void> dispose() async {
    await _incoming.close();
    await _reconnected.close();
    await _status.close();
  }

  /// Builds the DTO the hub returns/broadcasts. `senderId` defaults to the
  /// trainer, i.e. "mine" from the console's point of view.
  ChatMessage ack({
    required String messageId,
    required String otherPartyId,
    required String body,
    String? senderId,
    DateTime? sentAt,
  }) {
    return ChatMessage(
      id: messageId,
      body: body,
      sentAt: sentAt ?? DateTime.now().toUtc(),
      senderId: senderId ?? trainerId,
      trainerId: trainerId,
      clientId: otherPartyId,
    );
  }

  /// Fixed id standing in for the signed-in trainer.
  static const trainerId = '11111111-1111-1111-1111-111111111111';
}

/// Serves canned history and conversation payloads without a network.
class FakeChatApi implements ChatApi {
  /// Raw history JSON per otherPartyId, in the shape `ChatMessageDto` serialises to.
  final Map<String, List<Map<String, dynamic>>> history;
  final List<Map<String, dynamic>> conversations;

  /// Set to make the matching call throw, for error-state tests.
  final bool throwOnHistory;
  final bool throwOnConversations;

  /// Fails the first N conversation fetches, then succeeds — so a test can check
  /// that a retry actually clears the error rather than only that it re-runs.
  int failConversationsTimes = 0;

  /// Completes only when a test says so, to hold a screen in its loading state.
  final Completer<void>? gate;

  /// Records `markRead` calls so a test can assert the endpoint was hit once.
  final List<String> markedRead = [];

  FakeChatApi({
    this.history = const {},
    this.conversations = const [],
    this.throwOnHistory = false,
    this.throwOnConversations = false,
    this.gate,
  });

  @override
  Future<List<Map<String, dynamic>>> fetchHistory(
    String otherPartyId, {
    int range = 50,
  }) async {
    if (gate != null) await gate!.future;
    if (throwOnHistory) throw Exception('boom');
    return history[otherPartyId] ?? const [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchConversations() async {
    if (gate != null) await gate!.future;
    if (failConversationsTimes > 0) {
      failConversationsTimes--;
      throw Exception('boom');
    }
    if (throwOnConversations) throw Exception('boom');
    return conversations;
  }

  @override
  Future<void> markRead(String otherPartyId) async => markedRead.add(otherPartyId);
}

/// One server-side message in the JSON shape `ChatMessageDto` serialises to.
///
/// Guids and DateTimes cross the wire as strings and `MediaType` as an int (the
/// API configures no `JsonStringEnumConverter`), so the fixtures use those types
/// rather than Dart-native ones — otherwise the tests would exercise a parser
/// that never sees real input.
Map<String, dynamic> messageJson({
  required String id,
  required String body,
  required String senderId,
  required String clientId,
  String trainerId = FakeChatSignalRClient.trainerId,
  DateTime? sentAt,
}) {
  return {
    'id': id,
    'body': body,
    'sentAt': (sentAt ?? DateTime.now().toUtc()).toIso8601String(),
    'senderId': senderId,
    'trainerId': trainerId,
    'clientId': clientId,
    'mediaType': null,
    'url': null,
    'thumbnailUrl': null,
  };
}

/// Writes an outbox row directly, for tests that need a pre-existing unsent
/// message (e.g. "a pending message from a previous launch is replayed").
Future<void> seedOutboxRow(
  AppDatabase db, {
  required String messageId,
  required String otherPartyId,
  required String body,
  required DateTime createdAt,
  ChatMessageStatus status = ChatMessageStatus.pending,
}) {
  return db.chatoutboxDao.insertMessagePending(
    ChatOutBoxTableCompanion.insert(
      messageId: messageId,
      otherPartyId: otherPartyId,
      body: body,
      createdAt: createdAt,
      chatMessageStatus: Value(status.index),
    ),
  );
}
