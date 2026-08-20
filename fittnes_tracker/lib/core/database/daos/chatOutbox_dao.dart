import 'package:drift/drift.dart';
import '../../app_database.dart';

part 'chatOutbox_dao.g.dart';

@DriftAccessor(tables: [ChatOutBoxTable])
class ChatoutboxDao extends DatabaseAccessor<AppDatabase>
    with _$ChatoutboxDaoMixin {
  ChatoutboxDao(super.attachedDatabase);

  Future<int> insertMessagePending(Insertable<ChatOutBoxTableData> message) {
    return into(chatOutBoxTable).insert(message);
  }

  Future<void> markMessagePendingAsSent(String messageId) =>
      (update(chatOutBoxTable)..where(
        (t) => t.messageId.equals(messageId),
      )).write(
        ChatOutBoxTableCompanion(
          chatMessageStatus: Value(ChatMessageStatus.sent.index),
        ),
      );

  /// Gives up on a message: the reconnect-replay loop has spent its retry budget.
  ///
  /// This state exists only on this device. The server never saw the message, so
  /// from its side there is nothing to have failed — which is why it is also the
  /// one state needing a manual "tap to retry" in the UI.
  Future<void> markMessageFailed(String messageId) =>
      (update(chatOutBoxTable)..where(
        (t) => t.messageId.equals(messageId),
      )).write(
        ChatOutBoxTableCompanion(
          chatMessageStatus: Value(ChatMessageStatus.failed.index),
        ),
      );

  /// Puts a failed message back in the queue, keeping its original id so the
  /// server can still recognise the retry as the same message.
  Future<void> resetToPending(String messageId) =>
      (update(chatOutBoxTable)..where(
        (t) => t.messageId.equals(messageId),
      )).write(
        ChatOutBoxTableCompanion(
          chatMessageStatus: Value(ChatMessageStatus.pending.index),
        ),
      );

  Future<List<ChatOutBoxTableData>> getPendingMessages(String otherPartyId) {
    return (select(chatOutBoxTable)
          ..where((t) =>
              t.chatMessageStatus.equals(ChatMessageStatus.pending.index) &
              t.otherPartyId.equals(otherPartyId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
  }

  /// Everything not yet acknowledged — pending *and* failed.
  ///
  /// What the thread view merges with server history: both states are messages
  /// the user wrote that the server has no record of, so both have to stay on
  /// screen across a restart or they look like they were silently dropped.
  Future<List<ChatOutBoxTableData>> getUnsentMessages(String otherPartyId) {
    return (select(chatOutBoxTable)
          ..where((t) =>
              t.chatMessageStatus.isNotValue(ChatMessageStatus.sent.index) &
              t.otherPartyId.equals(otherPartyId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
  }

  Future<ChatOutBoxTableData?> findMessage(String messageId) {
    return (select(chatOutBoxTable)
          ..where((t) => t.messageId.equals(messageId)))
        .getSingleOrNull();
  }
}
