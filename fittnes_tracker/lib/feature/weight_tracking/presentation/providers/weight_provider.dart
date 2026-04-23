import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/providers/user_goals_provider.dart';
import 'package:ForgeForm/core/utils/app_logger.dart';
import 'package:ForgeForm/feature/weight_tracking/data/repositories/weight_repository.dart';
import 'package:flutter/foundation.dart';

class WeightProvider with ChangeNotifier {
  final WeightRepository _repository;
  final UserGoalsProvider userGoalsProvider;
  List<WeightRecordData> _weightRecords = [];
  bool _isLoading = false;

  WeightProvider(AppDatabase db, {required this.userGoalsProvider})
    : _repository = WeightRepository(db) {
    _loadWeightRecords();
  }

  List<WeightRecordData> get weightRecords => _weightRecords;
  bool get isLoading => _isLoading;

  // Load all weight records
  Future<void> _loadWeightRecords() async {
    _isLoading = true;
    notifyListeners();

    try {
      _weightRecords = await _repository.getAllWeightRecords();
    } catch (e) {
      AppLogger.i('Error loading weight records: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get the most recent weight record
  WeightRecordData? get latestWeightRecord {
    if (_weightRecords.isEmpty) return null;
    return _weightRecords.first; // Records are already sorted by date desc
  }

  // Add a new weight record
  Future<void> addWeightRecord({
    required DateTime date,
    required double weight,
    String? note,
  }) async {
    await _repository.addWeightRecord(date: date, weight: weight, note: note);
    await _loadWeightRecords();

    // Notify UserGoalsProvider if this is the latest record
    if (date.isAfter(DateTime.now().subtract(const Duration(days: 1)))) {
      userGoalsProvider.updateCurrentWeightValue(weight);
    }
  }

  Future<void> updateWeightRecord({
    required int id,
    required DateTime date,
    required double weight,
    String? note,
  }) async {
    await _repository.updateWeightRecord(
      id: id,
      date: date,
      weight: weight,
      note: note,
    );
    await _loadWeightRecords();

    // Notify UserGoalsProvider if this is the latest record (no null check needed)
    final latest = latestWeightRecord;
    if (latest != null &&
        latest.id == id &&
        date.isAfter(DateTime.now().subtract(const Duration(days: 1)))) {
      userGoalsProvider.updateCurrentWeightValue(weight);
    }
  }

  Future<void> reload() => _loadWeightRecords();

  // Delete a weight record
  Future<void> deleteWeightRecord(int id) async {
    await _repository.deleteWeightRecord(id);
    await _loadWeightRecords();
  }

  // Calculate weight change over time (e.g., for the last week, month)
  double getWeightChange({required Duration period}) {
    if (_weightRecords.isEmpty || _weightRecords.length < 2) return 0;

    final now = DateTime.now();
    final cutoffDate = now.subtract(period);

    // Find the closest weight record before the cutoff date
    WeightRecordData? oldestInPeriod;
    for (final record in _weightRecords.reversed) {
      if (record.date.isAfter(cutoffDate)) {
        oldestInPeriod = record;
      } else {
        break;
      }
    }

    if (oldestInPeriod == null) return 0;

    final latestWeight = latestWeightRecord?.weight ?? 0;
    return latestWeight - oldestInPeriod.weight;
  }
}
