import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/di/service_locator.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout_plan.dart';
import 'package:flutter/foundation.dart';

class WorkoutProvider extends ChangeNotifier {
  final WorkoutDao _dao;
  final WorkoutPlanDao _planDao;

  /// Both DAOs default to the registered database, which is how every existing
  /// call site builds this. They are parameters so a test can hand in one that
  /// fails: a load failure is a state this provider now reports, and there is
  /// no other way to reach it.
  WorkoutProvider({WorkoutDao? dao, WorkoutPlanDao? planDao})
    : _dao = dao ?? sl<AppDatabase>().workoutDao,
      _planDao = planDao ?? sl<AppDatabase>().workoutPlanDao;

  List<WorkoutTableData> _templates = [];
  List<WorkoutTableData> get templates => _templates;
  List<WorkoutPlan> _plans = [];
  List<WorkoutPlan> get plans => _plans;

  bool _loading = false;
  bool get loading => _loading;

  /// Null when the last load succeeded.
  ///
  /// Without this a throw left `_plans` empty and `_loading` false, so a
  /// failed load rendered as "No workouts found" with a Create-your-first
  /// button — telling a trainee their workouts are gone when the truth was
  /// that nobody could read them. `finally` restored the flag and swallowed
  /// the reason; a `catch` keeps it.
  Object? _error;
  Object? get error => _error;

  Future<void> loadTemplates() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _templates = await _dao.getWorkoutTemplates();
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadCompletePlans() async {
    _loading = true;
    _error = null;
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
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
