import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/di/service_locator.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout_plan.dart';
import 'package:flutter/foundation.dart';

class WorkoutProvider extends ChangeNotifier {
  final WorkoutDao _dao = sl<AppDatabase>().workoutDao;
  final WorkoutPlanDao _planDao = sl<AppDatabase>().workoutPlanDao;

  List<WorkoutTableData> _templates = [];
  List<WorkoutTableData> get templates => _templates;
  List<WorkoutPlan> _plans = [];
  List<WorkoutPlan> get plans => _plans;

  bool _loading = false;
  bool get loading => _loading;

  Future<void> loadTemplates() async {
    _loading = true;
    notifyListeners();
    try {
      _templates = await _dao.getWorkoutTemplates();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadCompletePlans() async {
    _loading = true;
    notifyListeners();

    try {
      final plans = await _planDao.getAllPlans();

      final completePlans = <WorkoutPlan>[];

      for (final plan in plans) {
        final full = await _planDao.getCompletePlanById(plan.id);
        if (full != null) {
          completePlans.add(full);
        }
      }

      _plans = completePlans;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
