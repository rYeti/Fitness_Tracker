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
  }) {
    return db.weightRecordDao.updateWeightRecord(
      WeightRecordData(id: id, date: date, weight: weight, note: note),
    );
  }

  // Delete a weight record
  Future<int> deleteWeightRecord(int id) {
    return db.weightRecordDao.deleteWeightRecord(id);
  }
}
