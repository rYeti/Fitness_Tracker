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

  /// Every thread with at least one message still `pending`, not just the one
  /// on screen.
  ///
  /// What the reconnect handler replays against. A trainer's outbox is not
  /// scoped to one conversation — sending to several clients queues rows
  /// across several `otherPartyId`s, and a reconnect that only replayed the
  /// thread currently open would leave the rest pending forever, because
  /// nothing else ever revisits them.
  Future<List<String>> getOtherPartyIdsWithPendingMessages() {
    final query = selectOnly(chatOutBoxTable, distinct: true)
      ..addColumns([chatOutBoxTable.otherPartyId])
      ..where(chatOutBoxTable.chatMessageStatus
          .equals(ChatMessageStatus.pending.index));
    return query
        .map((row) => row.read(chatOutBoxTable.otherPartyId)!)
        .get();
  }

  /// Moves an attachment's own upload state along, independent of the
  /// message's send status — the two are tracked separately, see
  /// [ChatOutBoxTable.uploadStatus]'s own doc comment for why.
  Future<void> markUploadStatus(String messageId, AttachmentUploadStatus status) =>
      (update(chatOutBoxTable)..where(
        (t) => t.messageId.equals(messageId),
      )).write(
        ChatOutBoxTableCompanion(uploadStatus: Value(status.index)),
      );

  /// Every row still at `uploading` — what a restart after a kill mid-upload
  /// resumes from. See [ChatOutBoxTable.attachmentLocalPath]'s own comment on
  /// why this only means anything on native platforms.
  Future<List<ChatOutBoxTableData>> getUploadingMessages() {
    return (select(chatOutBoxTable)
          ..where((t) => t.uploadStatus.equals(AttachmentUploadStatus.uploading.index)))
        .get();
  }

  /// Deletes `sent` rows older than [age] and returns the local file paths
  /// their attachments were writing to, so the caller can unlink them.
  ///
  /// Nothing pruned the outbox before this feature, and nothing had to: a
  /// stale `sent` row was just a few bytes of text, harmless to leave
  /// forever. A row can now hold a 32-byte AES key and point at a temp file,
  /// which makes an unpruned outbox a slowly growing key archive rather than
  /// a merely untidy table.
  Future<List<String>> pruneSent(Duration age) async {
    final cutoff = DateTime.now().toUtc().subtract(age);
    final toDelete = await (select(chatOutBoxTable)
          ..where((t) =>
              t.chatMessageStatus.equals(ChatMessageStatus.sent.index) &
              t.createdAt.isSmallerThanValue(cutoff)))
        .get();

    if (toDelete.isEmpty) return [];

    await (delete(chatOutBoxTable)
          ..where((t) => t.messageId.isIn(toDelete.map((r) => r.messageId))))
        .go();

    return [
      for (final row in toDelete)
        if (row.attachmentLocalPath != null) row.attachmentLocalPath!,
    ];
  }
}
