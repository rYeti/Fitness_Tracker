import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/providers/enums.dart';
import 'package:drift/drift.dart';

/// Result of the adaptive TDEE estimation. When [sufficientData] is false the
/// numeric fields are null and the UI shows the "keep logging" state instead.
class AdaptiveTdeeResult {
  final bool sufficientData;
  final int daysUsed;
  final double? tdee;
  final double? recommendedTarget;

  const AdaptiveTdeeResult({
    required this.sufficientData,
    required this.daysUsed,
    this.tdee,
    this.recommendedTarget,
  });
}

/// Estimates true daily energy expenditure from the trend of logged intake
/// versus trend body weight (MacroFactor's published approach), instead of a
/// static formula. Deliberately ignores wearable expenditure data.
///
/// TDEE ≈ mean daily intake − (Δ trend weight in kcal ÷ days), at ~7,700
/// kcal per kg of body weight. Scale noise is smoothed with an exponentially
/// weighted moving average before the delta is taken. Estimates are withheld
/// until there is enough consistent logging to be meaningful — a bad estimate
/// is worse than none.
class AdaptiveTdeeService {
  final AppDatabase db;

  AdaptiveTdeeService(this.db);

  static const _windowDays = 28;
  static const _kcalPerKg = 7700.0;
  static const _ewmaAlpha = 0.25;
  // Minimums before an estimate is shown: logging span, days with food
  // logged, and weigh-ins. Below these the noise dominates the signal.
  static const _minSpanDays = 14;
  static const _minLoggedDays = 10;
  static const _minWeighIns = 5;

  Future<AdaptiveTdeeResult> compute() async {
    final now = DateTime.now();
    final windowStart = now.subtract(const Duration(days: _windowDays));

    // Daily intake totals from logged meals.
    final mealRows = await (db.select(db.mealTable).join([
      innerJoin(db.foodItem, db.foodItem.id.equalsExp(db.mealTable.foodItemId)),
    ])..where(db.mealTable.date.isBiggerOrEqualValue(windowStart))).get();

    final intakeByDay = <DateTime, double>{};
    for (final row in mealRows) {
      final meal = row.readTable(db.mealTable);
      final food = row.readTable(db.foodItem);
      final day = DateTime(meal.date.year, meal.date.month, meal.date.day);
      intakeByDay[day] = (intakeByDay[day] ?? 0) + food.calories;
    }

    // Weigh-ins in the window, oldest first.
    final weights = (await db.weightRecordDao.getAllWeightRecords())
        .where((w) => !w.date.isBefore(windowStart))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final spanDays = weights.isEmpty
        ? 0
        : weights.last.date.difference(weights.first.date).inDays;

    if (weights.length < _minWeighIns ||
        intakeByDay.length < _minLoggedDays ||
        spanDays < _minSpanDays) {
      return AdaptiveTdeeResult(
        sufficientData: false,
        daysUsed: intakeByDay.length,
      );
    }

    // EWMA over the weigh-in series; the delta is smoothed-end minus start.
    double trend = weights.first.weight;
    for (final w in weights.skip(1)) {
      trend += _ewmaAlpha * (w.weight - trend);
    }
    final deltaKg = trend - weights.first.weight;

    final meanIntake =
        intakeByDay.values.reduce((a, b) => a + b) / intakeByDay.length;
    final tdee = meanIntake - (deltaKg * _kcalPerKg / spanDays);

    final settings = await db.userSettingsDao.getSettings();
    final goalIndex = settings?.goalType ?? GoalType.maintenance.index;
    final goal = (goalIndex >= 0 && goalIndex < GoalType.values.length)
        ? GoalType.values[goalIndex]
        : GoalType.maintenance;
    final recommended = switch (goal) {
      // ~0.35 kg/week loss and a conservative lean-gain surplus.
      GoalType.weightLoss => tdee - 400,
      GoalType.muscleGain => tdee + 250,
      GoalType.maintenance => tdee,
    };

    return AdaptiveTdeeResult(
      sufficientData: true,
      daysUsed: spanDays,
      tdee: tdee,
      recommendedTarget: recommended,
    );
  }
}
