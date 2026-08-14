import 'package:drift/drift.dart';

// Weight tracking table definition
/// Sync state for a locally-stored weight record.
///
/// - [pending]       New record, never pushed to the API.
/// - [synced]        Successfully pushed; [serverId] is set.
/// - [pendingUpdate] Edited locally after a successful sync.
/// - [pendingDelete] Deleted locally; must be removed on the API before the
///                   local row is dropped.
enum WeightSyncStatus { pending, synced, pendingUpdate, pendingDelete }

class WeightRecord extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  RealColumn get weight => real()();
  TextColumn get note => text().nullable()();

  /// Maps to [WeightSyncStatus] by index. Defaults to [WeightSyncStatus.pending].
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  /// The UUID assigned by the remote API after the first successful sync.
  /// Null until the record has been synced at least once.
  TextColumn get serverId => text().nullable()();
}
