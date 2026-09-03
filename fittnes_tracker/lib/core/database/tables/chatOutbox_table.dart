import 'package:drift/drift.dart';

/// Sync state for a locally-stored food item.
enum ChatMessageStatus { pending, sent, failed }

/// Where a queued attachment's own upload stands, independent of whether the
/// *message* carrying it has been sent. Deliberately not folded into
/// [ChatMessageStatus] — see [ChatOutBoxTable.uploadStatus]'s own doc comment.
enum AttachmentUploadStatus { none, uploading, uploaded, failed }

class ChatOutBoxTable extends Table {
  @override
  Set<Column> get primaryKey => {messageId};
  TextColumn get messageId => text()();
  TextColumn get otherPartyId => text()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();

  /// Maps to [ChatMessageStatus] by index.
  IntColumn get chatMessageStatus => integer().withDefault(const Constant(0))();

  /// The attachment envelope this message carries, if any — everything
  /// [ChatBodyCodec] needs to rebuild the encrypted body on replay: the
  /// per-attachment key, its manifest, the caption. `body` above stays the
  /// plaintext caption alone; this is stored separately so replay can
  /// reconstruct the envelope without re-parsing `body`, and so a schema
  /// reader can see at a glance which rows carry an attachment.
  TextColumn get attachmentManifest => text().nullable()();

  /// Where this device's processed (downscaled, sealed) plaintext bytes live
  /// before upload — a temp file path, native platforms only. Null on web,
  /// where there is no file system to resume an interrupted upload from; see
  /// docs/chat-attachments.md.
  TextColumn get attachmentLocalPath => text().nullable()();

  /// Maps to [AttachmentUploadStatus] by index. `none` for every ordinary
  /// text message — the overwhelmingly common case — so this column changes
  /// nothing about a row that carries no attachment.
  ///
  /// A second column rather than widening [ChatMessageStatus], because the
  /// two axes are genuinely independent (a message can be `pending` and
  /// `uploaded` at once — sent, upload done, ack still outstanding) and
  /// because [ChatMessageStatus]'s indices are read by raw SQL elsewhere
  /// (`AppDatabase.countUnsyncedChanges`'s `chat_message_status != 1`, which
  /// gates the sign-out confirmation) — overloading it would make that
  /// predicate quietly wrong.
  IntColumn get uploadStatus =>
      integer().withDefault(const Constant(0))();
}
