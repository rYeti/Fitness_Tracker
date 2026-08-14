import 'package:drift/drift.dart';
import '../../app_database.dart';

part 'weight_record_dao.g.dart';

// Weight tracking DAO
@DriftAccessor(tables: [WeightRecord])
class WeightRecordDao extends DatabaseAccessor<AppDatabase>
    with _$WeightRecordDaoMixin {
  WeightRecordDao(super.db);

  // Get all weight records ordered by date
  Future<List<WeightRecordData>> getAllWeightRecords() =>
      (select(weightRecord)
            ..where(
              (t) =>
                  t.syncStatus.isNotValue(WeightSyncStatus.pendingDelete.index),
            )
            ..orderBy([
              (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
            ]))
          .get();

  // Watch all weight records (reactive stream)
  Stream<List<WeightRecordData>> watchAllWeightRecords() =>
      (select(weightRecord)
            ..where(
              (t) =>
                  t.syncStatus.isNotValue(WeightSyncStatus.pendingDelete.index),
            )
            ..orderBy([
              (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
            ]))
          .watch();

  // Get the most recent weight record
  Future<WeightRecordData?> getLatestWeightRecord() =>
      (select(weightRecord)
            ..where(
              (t) =>
                  t.syncStatus.isNotValue(WeightSyncStatus.pendingDelete.index),
            )
            ..orderBy([
              (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<WeightRecordData?> getWeightRecordById(int id) =>
      (select(weightRecord)..where((t) => t.id.equals(id))).getSingleOrNull();

  // Add a new weight record
  Future<int> addWeightRecord(Insertable<WeightRecordData> record) =>
      into(weightRecord).insert(record);

  // Update an existing weight record
  Future<bool> updateWeightRecord(Insertable<WeightRecordData> record) =>
      update(weightRecord).replace(record);

  // Delete a weight record
  Future<int> deleteWeightRecord(int id) =>
      (delete(weightRecord)..where((tbl) => tbl.id.equals(id))).go();

  // Get weight records within a date range, ordered by date ascending
  Future<List<WeightRecordData>> getRecordsInRange(
    DateTime start,
    DateTime end,
  ) =>
      (select(weightRecord)
            ..where((t) => t.date.isBiggerOrEqualValue(start))
            ..where((t) => t.date.isSmallerOrEqualValue(end))
            ..orderBy([(t) => OrderingTerm.asc(t.date)]))
          .get();

  // --- Sync helpers ---

  /// Returns every record that needs to be pushed to the API
  /// (pending, pendingUpdate, or pendingDelete).
  Future<List<WeightRecordData>> getUnsyncedRecords() =>
      (select(weightRecord)..where(
        (t) => t.syncStatus.isNotIn([WeightSyncStatus.synced.index]),
      )).get();

  /// Marks a record as [WeightSyncStatus.synced] and stores the [serverId]
  /// returned by the API.
  Future<void> markSynced({required int localId, required String serverId}) =>
      (update(weightRecord)..where((t) => t.id.equals(localId))).write(
        WeightRecordCompanion(
          syncStatus: Value(WeightSyncStatus.synced.index),
          serverId: Value(serverId),
        ),
      );

  /// Marks an already-synced record as [WeightSyncStatus.pendingUpdate] so
  /// the next sync pass will push the change via PUT.
  Future<void> markPendingUpdate(int localId) =>
      (update(weightRecord)..where((t) => t.id.equals(localId))).write(
        WeightRecordCompanion(
          syncStatus: Value(WeightSyncStatus.pendingUpdate.index),
        ),
      );

  /// Marks a record as [WeightSyncStatus.pendingDelete].
  /// Call this instead of [deleteWeightRecord] when the record has a [serverId]
  /// so the sync pass can delete it on the API first.
  Future<void> markPendingDelete(int localId) =>
      (update(weightRecord)..where((t) => t.id.equals(localId))).write(
        WeightRecordCompanion(
          syncStatus: Value(WeightSyncStatus.pendingDelete.index),
        ),
      );

  Future<WeightRecordData?> getByServerId(String serverId) =>
      (select(weightRecord)
            ..where((t) => t.serverId.equals(serverId))
            ..limit(1))
          .getSingleOrNull();
}
