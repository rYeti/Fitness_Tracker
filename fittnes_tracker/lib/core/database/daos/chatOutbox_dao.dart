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
      )).write(const ChatOutBoxTableCompanion(chatMessageStatus: Value(1)));

  Future<List<ChatOutBoxTableData>> getPendingMessages(String otherPartyId) {
    return (select(chatOutBoxTable)
          ..where((t) => t.chatMessageStatus.equals(0) & t.otherPartyId.equals(otherPartyId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
  }
}
