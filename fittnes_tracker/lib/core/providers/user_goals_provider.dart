import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/utils/app_logger.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../feature/food_tracking/data/repositories/nutrition_repository.dart';
import '../../feature/weight_tracking/data/repositories/weight_repository.dart';
import 'enums.dart';

class UserGoalsProvider with ChangeNotifier {
  // Backing fields (defaults used until DB loads)
  int _calorieGoal = 2000;
  double _goalWeight = 80.0;
  double _startingWeight = 90.0;
  double _currentWeight = 85.0;
  String _name = '';

  int get calorieGoal => _calorieGoal;
  double get dailyCalorieGoal => _calorieGoal.toDouble();
  double get goalWeight => _goalWeight;
  double get startingWeight => _startingWeight;
  double get currentWeight => _currentWeight;
  String get name => _name;

  final AppDatabase db;
  late final NutritionRepository repo;
  late final WeightRepository weightRepo;
  bool _loadedFromDb = false;

  UserGoalsProvider(this.db) {
    repo = NutritionRepository(db);
    weightRepo = WeightRepository(db);
    _init();
  }

  Future<void> _init() async {
    await loadCalorieGoal();
    await loadLatestWeight();
    await loadWeightGoals();
  }

  // Loads the latest weight record from the database
  Future<void> loadLatestWeight() async {
    try {
      final latestWeight = await weightRepo.getLatestWeightRecord();
      if (latestWeight != null) {
        _currentWeight = latestWeight.weight;
        notifyListeners();
      }
    } catch (e) {
      // If there's an error, keep the default weight
      AppLogger.i('Error loading latest weight: $e');
    }
  }

  // Load weight goals from user settings
  Future<void> loadWeightGoals() async {
    try {
      final settings = await db.userSettingsDao.getSettings();
      if (settings != null) {
        // These fields will exist after we regenerate the database code
        _startingWeight = settings.startingWeight;
        _goalWeight = settings.goalWeight;
        notifyListeners();
      }
    } catch (e) {
      AppLogger.i('Error loading weight goals: $e');
    }
  }

  Future<void> loadCalorieGoal() async {
    try {
      final settings = await db.userSettingsDao.getSettings();
      if (settings != null) {
        _calorieGoal = settings.dailyCalorieGoal;
        _name = settings.name;
      }
      _loadedFromDb = true;
    } catch (_) {
      // swallow errors; keep defaults
    }
    notifyListeners();
  }

  Future<void> saveCalorieGoal(int goal) async {
    _calorieGoal = goal;
    await repo.setCalorieGoal(goal);
    notifyListeners();
  }

  Future<void> setDailyCalorieGoal(int goal) async {
    _calorieGoal = goal;
    notifyListeners();
  }

  Future<void> setGoalWeight(double weight) async {
    _goalWeight = weight;
    notifyListeners();
    await setWeightGoals(_startingWeight, weight);
  }

  Future<void> setStartingWeight(double weight) async {
    _startingWeight = weight;
    notifyListeners();
    await setWeightGoals(weight, _goalWeight);
  }

  Future<void> setWeightGoals(double startingWeight, double goalWeight) async {
    _startingWeight = startingWeight;
    _goalWeight = goalWeight;
    notifyListeners();
    try {
      await db.userSettingsDao.updateWeightGoals(
        startingWeight: startingWeight,
        goalWeight: goalWeight,
      );
    } catch (e) {
      AppLogger.i('Error saving weight goals: $e');
    }
  }

  Future<void> setCurrentWeight(double weight) async {
    _currentWeight = weight;
    notifyListeners();

    // Current weight is tracked through weight records, not user settings
    try {
      await weightRepo.addWeightRecord(date: DateTime.now(), weight: weight);
    } catch (e) {
      AppLogger.i('Error saving current weight: $e');
    }
  }

  bool get isLoaded => _loadedFromDb;

  // Progress calculations
  double getWeightProgress() {
    if (startingWeight == goalWeight) return 1.0;

    // Determine if goal is weight loss or gain
    final isWeightLoss = startingWeight > goalWeight;

    // Calculate total change needed
    final totalChange = (goalWeight - startingWeight).abs();

    // Calculate current change from starting point
    final currentChange = currentWeight - startingWeight;

    // Calculate progress based on direction
    double progress;
    if (isWeightLoss) {
      // For weight loss, negative change is progress
      progress = -currentChange / totalChange;
    } else {
      // For weight gain, positive change is progress
      progress = currentChange / totalChange;
    }

    // Ensure progress is between 0 and 1
    return progress.clamp(0.0, 1.0);
  }

  int calculateCalorieTarget({
    required Sex sex,
    required int age,
    required double heightCm,
    required double weightKg,
    required ActivityLevel activity,
    required GoalType goal,
  }) {
    final bmr =
        (10 * weightKg) +
        (6.25 * heightCm) -
        (5 * age) +
        (sex == Sex.male ? 5 : -161);
    double activityFactor;
    switch (activity) {
      case ActivityLevel.sedentary:
        activityFactor = 1.2;
        break;
      case ActivityLevel.lightlyActive:
        activityFactor = 1.375;
        break;
      case ActivityLevel.moderatelyActive:
        activityFactor = 1.55;
        break;
      case ActivityLevel.veryActive:
        activityFactor = 1.725;
        break;
      case ActivityLevel.extremelyActive:
        activityFactor = 1.9;
        break;
    }
    var tdee = bmr * activityFactor;
    double multiplier;
    switch (goal) {
      case GoalType.weightLoss:
        multiplier = 0.85;
        break; // -15%
      case GoalType.maintenance:
        multiplier = 1.0;
        break;
      case GoalType.muscleGain:
        multiplier = 1.10;
        break; // +10%
    }
    final target = (tdee * multiplier).round();
    return target < 1200 ? 1200 : target;
  }

  Future<void> autoSetCalorieGoal({
    required Sex sex,
    required int age,
    required double heightCm,
    required double weightKg,
    required ActivityLevel activity,
    required GoalType goal,
  }) async {
    if (!isLoaded) return;

    final newGoal = calculateCalorieTarget(
      sex: sex,
      age: age,
      heightCm: heightCm,
      weightKg: weightKg,
      activity: activity,
      goal: goal,
    );

    await setDailyCalorieGoal(newGoal);
  }

  Future<void> reload() async {
    await loadCalorieGoal();
    await loadLatestWeight();
    await loadWeightGoals();
  }

  Future<void> updateCurrentWeightValue(double weight) async {
    _currentWeight = weight;
    notifyListeners();
  }

  Future<double> getAverageWeeklyWeightChange() async {
    try {
      final weightRecords = await weightRepo.getAllWeightRecords();
      if (weightRecords.length < 2) return 0.0; // Not enough data

      // Sort by date (newest first)
      weightRecords.sort((a, b) => b.date.compareTo(a.date));

      // Get records from past 4 weeks only
      final now = DateTime.now();
      final fourWeeksAgo = now.subtract(const Duration(days: 28));
      final recentRecords =
          weightRecords
              .where((record) => record.date.isAfter(fourWeeksAgo))
              .toList();

      if (recentRecords.length < 2) return 0.0; // Not enough recent data

      // Calculate weekly change
      final newest = recentRecords.first;
      final oldest = recentRecords.last;
      final weightDifference = newest.weight - oldest.weight;
      final daysDifference = newest.date.difference(oldest.date).inDays;

      if (daysDifference == 0) return 0.0; // Avoid division by zero

      // Convert to weekly rate
      return (weightDifference / daysDifference) * 7;
    } catch (e) {
      AppLogger.i('Error calculating weekly weight change: $e');
      return 0.0;
    }
  }

  // Get projected completion date
  Future<DateTime?> getProjectedCompletionDate() async {
    final weeklyChange = await getAverageWeeklyWeightChange();
    if (weeklyChange.abs() < 0.01) return null; // No significant change

    final isWeightLoss = startingWeight > goalWeight;
    final remainingWeight = (currentWeight - goalWeight).abs();

    // If the direction of change is wrong, return null
    if ((isWeightLoss && weeklyChange >= 0) ||
        (!isWeightLoss && weeklyChange <= 0)) {
      return null;
    }

    // Calculate weeks needed
    final weeksNeeded = remainingWeight / weeklyChange.abs();

    // Convert to days and add to current date
    final daysNeeded = (weeksNeeded * 7).round();
    return DateTime.now().add(Duration(days: daysNeeded));
  }

  // Get human-readable completion estimate
  Future<String?> getCompletionEstimate(AppLocalizations l10n) async {
    final completionDate = await getProjectedCompletionDate();
    if (completionDate == null) return null;

    final difference = completionDate.difference(DateTime.now());
    final days = difference.inDays;

    if (days < 7) {
      return l10n.completionLessThanWeek;
    } else if (days < 30) {
      return l10n.completionWeeks((days / 7).round());
    } else if (days < 365) {
      return l10n.completionMonths((days / 30).round());
    } else {
      return l10n.completionYears((days / 365).round());
    }
  }
}
