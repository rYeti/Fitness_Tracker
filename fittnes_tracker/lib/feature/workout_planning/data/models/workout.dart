import 'workout_exercise.dart';

/// Defines the difficulty level of a workout
enum WorkoutDifficulty { beginner, intermediate, advanced }

/// Represents a complete workout with multiple exercises
class Workout {
  final int? id;
  final String name;
  final String? description;
  final WorkoutDifficulty? difficulty;
  final int? estimatedDurationMinutes; // Estimated time to complete
  final bool isTemplate; // Whether this is a template or a scheduled workout
  final DateTime?
  scheduledDate; // The date this workout is scheduled (null for templates)
  final DateTime?
  completedDate; // When this workout was completed (null if not completed)
  final List<WorkoutExercise> exercises; // The exercises in this workout

  Workout({
    this.id,
    required this.name,
    this.description,
    this.difficulty,
    this.estimatedDurationMinutes,
    this.isTemplate = true,
    this.scheduledDate,
    this.completedDate,
    this.exercises = const [],
  });

  // Helper to check if workout is completed
  bool get isCompleted => completedDate != null;

  // Helper to check if all exercises are completed
  bool get allExercisesCompleted =>
      exercises.isNotEmpty &&
      exercises.every((exercise) => exercise.isCompleted);

  // Helper to calculate the completion percentage
  double get completionPercentage {
    if (exercises.isEmpty) return 0;

    int totalSets = 0;
    int completedSets = 0;

    for (var exercise in exercises) {
      totalSets += exercise.totalSets;
      completedSets += exercise.completedSets;
    }

    return totalSets > 0 ? completedSets / totalSets : 0;
  }

  // Convert to Map for database operations (without the exercises)
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description ?? '',
      'difficulty': difficulty?.index,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'isTemplate': isTemplate ? 1 : 0,
      'scheduledDate': scheduledDate?.toIso8601String(),
      'completedDate': completedDate?.toIso8601String(),
    };
  }

  // Create from Map (e.g., from database) - note that exercises need to be loaded separately
  factory Workout.fromMap(
    Map<String, dynamic> map, {
    List<WorkoutExercise>? exercises,
  }) {
    return Workout(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      difficulty: WorkoutDifficulty.values[map['difficulty'] ?? 0],
      estimatedDurationMinutes: map['estimatedDurationMinutes'] ?? 30,
      isTemplate: map['isTemplate'] == 1,
      scheduledDate:
          map['scheduledDate'] != null
              ? DateTime.parse(map['scheduledDate'])
              : null,
      completedDate:
          map['completedDate'] != null
              ? DateTime.parse(map['completedDate'])
              : null,
      exercises: exercises ?? [],
    );
  }

  // Clone with ability to override properties
  Workout copyWith({
    int? id,
    String? name,
    String? description,
    WorkoutDifficulty? difficulty,
    int? estimatedDurationMinutes,
    bool? isTemplate,
    DateTime? scheduledDate,
    DateTime? completedDate,
    List<WorkoutExercise>? exercises,
  }) {
    return Workout(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      difficulty: difficulty ?? this.difficulty,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      isTemplate: isTemplate ?? this.isTemplate,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      completedDate: completedDate ?? this.completedDate,
      exercises: exercises ?? this.exercises,
    );
  }
}
