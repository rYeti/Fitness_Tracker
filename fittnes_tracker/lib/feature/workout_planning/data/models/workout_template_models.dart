class WorkoutSetTemplate {
  final int id;
  final int setNumber;
  final String targetReps;
  final int orderPosition;

  WorkoutSetTemplate({
    required this.id,
    required this.setNumber,
    required this.targetReps,
    required this.orderPosition,
  });
}

class WorkoutExerciseTemplate {
  final int id;
  final int exerciseId;
  final int orderPosition;
  final List<WorkoutSetTemplate> sets;

  WorkoutExerciseTemplate({
    required this.id,
    required this.exerciseId,
    required this.orderPosition,
    required this.sets,
  });
}
