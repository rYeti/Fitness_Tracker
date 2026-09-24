import 'package:drift/drift.dart';

import 'sync_tables.dart';

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

  /// The row's global id, minted on insert ([newSyncId]) or taken from the
  /// server on pull. Whether the server has it yet is [syncStatus]'s to say.
  TextColumn get serverId => text().nullable().clientDefault(newSyncId)();
}
