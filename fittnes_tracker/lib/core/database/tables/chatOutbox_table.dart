import 'package:drift/drift.dart';

/// Sync state for a locally-stored food item.
enum ChatMessageStatus { pending, sent, failed }

class ChatOutBoxTable extends Table {
  @override
  Set<Column> get primaryKey => {messageId};
  TextColumn get messageId => text()();
  TextColumn get otherPartyId => text()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();

  /// Maps to [ChatMessageStatus] by index.
  IntColumn get chatMessageStatus => integer().withDefault(const Constant(0))();
}
