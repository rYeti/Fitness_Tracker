import 'package:ForgeForm/core/app_database.dart';

class ScheduledWorkoutExerciseRepository {
  final ScheduledWorkoutExerciseDao scheduledDao;
  final WorkoutDao workoutDao;
  final ScheduledWorkoutDao dao;
  final AppDatabase db;

  ScheduledWorkoutExerciseRepository({
    required this.scheduledDao,
    required this.workoutDao,
    required this.db,
    required this.dao,
  });

  Stream<List<ScheduledWorkoutExerciseFull>> watchForWorkout(
    int scheduledWorkoutId,
  ) {
    return scheduledDao.watchForScheduledWorkout(scheduledWorkoutId);
  }

  Future<List<ScheduledWorkoutExerciseFull>> getForWorkout(
    int scheduledWorkoutId,
  ) {
    return scheduledDao.getForScheduledWorkout(scheduledWorkoutId);
  }

  Future<void> saveExerciseNotes({
    required int scheduledWorkoutExerciseId,
    String? notes,
  }) {
    return scheduledDao.updateNotes(scheduledWorkoutExerciseId, notes);
  }

  Future<void> setExerciseCompleted({
    required int scheduledWorkoutExerciseId,
    required bool completed,
  }) {
    return scheduledDao.setCompleted(scheduledWorkoutExerciseId, completed);
  }

  Stream<List<ScheduledWorkoutTableData>> watchForDate(DateTime date) {
    return dao.watchForDate(date);
  }
}
