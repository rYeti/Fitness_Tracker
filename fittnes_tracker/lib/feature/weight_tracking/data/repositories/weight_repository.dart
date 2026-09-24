import 'package:ForgeForm/core/app_database.dart';
import 'package:drift/drift.dart';

class WeightRepository {
  final AppDatabase db;

  WeightRepository(this.db);

  // Get all weight records
  Future<List<WeightRecordData>> getAllWeightRecords() {
    return db.weightRecordDao.getAllWeightRecords();
  }

  // Watch all weight records as a stream
  Stream<List<WeightRecordData>> watchAllWeightRecords() {
    return db.weightRecordDao.watchAllWeightRecords();
  }

  // Get the latest weight record
  Future<WeightRecordData?> getLatestWeightRecord() {
    return db.weightRecordDao.getLatestWeightRecord();
  }

  // Add a new weight record
  Future<int> addWeightRecord({
    required DateTime date,
    required double weight,
    String? note,
  }) {
    return db.weightRecordDao.addWeightRecord(
      WeightRecordCompanion.insert(
        date: date,
        weight: weight,
        note: note == null ? const Value.absent() : Value(note),
      ),
    );
  }

  // Update an existing weight record
  Future<bool> updateWeightRecord({
    required int id,
    required DateTime date,
    required double weight,
    String? note,
  }) async {
    // Only the fields the user changed. The database marks a synced record
    // pendingUpdate by itself (`lib/core/sync/sync_triggers.dart`); this used
    // to read the row, work the status out here and write the whole row back
    // — including a server id and status that a sync finishing in between
    // could already have changed.
    final updated = await (db.update(db.weightRecord)
      ..where((t) => t.id.equals(id))).write(
      WeightRecordCompanion(
        date: Value(date),
        weight: Value(weight),
        note: Value(note),
      ),
    );
    return updated > 0;
  }

  // Delete a weight record
  Future<void> deleteWeightRecord(int id) async {
    final existing = await db.weightRecordDao.getWeightRecordById(id);
    if (existing == null) return;

    // Every record has a server id from the moment it is made, so it is the
    // status that says whether the server has it.
    if (SyncStatus.fromDb(existing.syncStatus) != SyncStatus.pending) {
      // Already synced — mark for deletion so the sync pass can issue
      // DELETE on the API before removing the local row.
      await db.weightRecordDao.markPendingDelete(id);
    } else {
      // Never synced — safe to remove locally right away.
      await db.weightRecordDao.deleteWeightRecord(id);
    }
  }
}
