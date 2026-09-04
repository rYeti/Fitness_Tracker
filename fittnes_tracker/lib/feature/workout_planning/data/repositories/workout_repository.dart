import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/utils/app_logger.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/exercise.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout_set.dart';

class WorkoutRepository {
  final AppDatabase db;

  WorkoutRepository(this.db);

  Future<List<Exercise>> getAllExercises() async {
    final exerciseData = await db.exerciseDao.getAllExercises();
    return exerciseData.map(db.exerciseDao.entityToModel).toList();
  }

  Future<List<Workout>> getWorkoutsForCurrentWeek() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    final workouts = await db.workoutDao.getWorkoutsInDateRange(
      startOfWeek,
      endOfWeek,
    );

    final completeWorkouts = await Future.wait(
      workouts.map((w) => db.workoutDao.getCompleteWorkoutById(w.id)),
    );

    return completeWorkouts.whereType<Workout>().toList();
  }

  Future<int> saveWorkout(Workout workout) async {
    return db.workoutDao.saveCompleteWorkout(workout);
  }

  Future<Workout?> getWorkoutById(int id) async {
    return db.workoutDao.getCompleteWorkoutById(id);
  }

  /// Marks the workout for deletion rather than deleting it outright — the
  /// row survives locally until the next sync push actually tells the
  /// server (or, for a workout that never reached the server, is dropped
  /// straight away by that same push) — see `SyncService._syncDeleteWorkout`.
  Future<void> deleteWorkoutById(int id) async {
    await db.workoutDao.markWorkoutPendingDelete(id);
  }

  Future<bool> updateWorkout(Workout workout) async {
    if (workout.id == null) {
      throw ArgumentError('Cannot update a workout without an ID');
    }

    try {
      final result = await db.workoutDao.saveCompleteWorkout(workout);
      return result > 0;
    } catch (e) {
      // Log error
      AppLogger.i('Error updating workout: $e');
      return false;
    }
  }

  // Method for marking a workout as completed
  Future<bool> markWorkoutCompleted(
    int workoutId, {
    DateTime? completedDate,
  }) async {
    // First fetch the complete workout
    final workout = await getWorkoutById(workoutId);
    if (workout == null) return false;

    // Update the completion date
    final updatedWorkout = workout.copyWith(
      completedDate: completedDate ?? DateTime.now(),
    );

    // Save the updated workout
    return updateWorkout(updatedWorkout);
  }

  // Method for updating exercise sets in a workout
  Future<bool> updateWorkoutSets(
    int workoutId,
    int exerciseInstanceId,
    List<WorkoutSet> updatedSets,
  ) async {
    final workout = await getWorkoutById(workoutId);
    if (workout == null) return false;

    // Find the exercise to update
    final updatedExercises =
        workout.exercises.map((exercise) {
          if (exercise.id == exerciseInstanceId) {
            // Replace the sets with updated ones
            return exercise.copyWith(sets: updatedSets);
          }
          return exercise;
        }).toList();

    // Create updated workout with new exercise data
    final updatedWorkout = workout.copyWith(exercises: updatedExercises);

    // Save the updated workout
    return updateWorkout(updatedWorkout);
  }

  // Get the completion percentage of a workout
  Future<double> getWorkoutCompletionPercentage(int workoutId) async {
    final workout = await getWorkoutById(workoutId);
    if (workout == null) return 0.0;

    int totalSets = 0;
    int completedSets = 0;

    for (final exercise in workout.exercises) {
      for (final set in exercise.sets) {
        totalSets++;
        if (set.isCompleted) completedSets++;
      }
    }

    return totalSets > 0 ? completedSets / totalSets : 0.0;
  }
}
