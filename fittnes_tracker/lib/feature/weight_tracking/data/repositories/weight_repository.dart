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
    final existing = await db.weightRecordDao.getWeightRecordById(id);
    if (existing == null) return false;

    // Promote sync status: synced → pendingUpdate so the next sync pass
    // sends a PUT. pending/pendingUpdate stay as-is — they haven't been
    // pushed yet so there's nothing to update on the server.
    final newSyncStatus =
        existing.syncStatus == WeightSyncStatus.synced.index
            ? WeightSyncStatus.pendingUpdate.index
            : existing.syncStatus;

    return db.weightRecordDao.updateWeightRecord(
      WeightRecordData(
        id: id,
        date: date,
        weight: weight,
        note: note,
        syncStatus: newSyncStatus,
        serverId: existing.serverId,
      ),
    );
  }

  // Delete a weight record
  Future<void> deleteWeightRecord(int id) async {
    final existing = await db.weightRecordDao.getWeightRecordById(id);
    if (existing == null) return;

    if (existing.serverId != null) {
      // Already synced — mark for deletion so the sync pass can issue
      // DELETE on the API before removing the local row.
      await db.weightRecordDao.markPendingDelete(id);
    } else {
      // Never synced — safe to remove locally right away.
      await db.weightRecordDao.deleteWeightRecord(id);
    }
  }
}
