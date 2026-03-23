import 'package:ForgeForm/core/app_database.dart';

class ScheduledWorkoutUi {
  final ScheduledWorkoutTableData scheduled;
  final String workoutName;
  final int estimatedDurationMinutes;
  final List<ScheduledWorkoutExerciseUi> exercises;

  ScheduledWorkoutUi({
    required this.scheduled,
    required this.workoutName,
    required this.estimatedDurationMinutes,
    required this.exercises,
  });
}

class ScheduledWorkoutExerciseUi {
  final int scheduledWorkoutExerciseId;
  final int workoutExerciseId;
  final int exerciseId;
  final String exerciseName;
  final List<WorkoutSetTemplateData> templates;
  final Map<int, WorkoutSetTableData> previousSets;

  ScheduledWorkoutExerciseUi({
    required this.scheduledWorkoutExerciseId,
    required this.workoutExerciseId,
    required this.exerciseId,
    required this.exerciseName,
    required this.templates,
    required this.previousSets,
  });
}
