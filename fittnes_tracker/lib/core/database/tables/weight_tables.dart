import 'package:drift/drift.dart';

// Weight tracking table definition
class WeightRecord extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  RealColumn get weight => real()();
  TextColumn get note => text().nullable()();

  /// Maps to [SyncStatus] by index. Defaults to [SyncStatus.pending].
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  /// Bumped by the database on every local change — see [SyncStatus] and
  /// `lib/core/sync/sync_triggers.dart`.
  IntColumn get localRev => integer().withDefault(const Constant(0))();

  /// The UUID assigned by the remote API after the first successful sync.
  /// Null until the record has been synced at least once.
  TextColumn get serverId => text().nullable()();
}
