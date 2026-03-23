import 'exercise.dart';
import 'workout_set.dart';

/// Represents a specific exercise included in a workout
/// This can be thought of as an "instance" of an exercise within a workout
class WorkoutExercise {
  final int? id;
  final int workoutId; // The workout this exercise belongs to
  final int exerciseId; // Reference to the exercise definition
  final int
  orderPosition; // Order in the workout (1-based), renamed from 'order'
  final Exercise?
  exercise; // The actual exercise data (can be null if not loaded)
  final List<WorkoutSet> sets; // The sets for this exercise
  final String? notes; // Notes specific to this exercise in this workout

  WorkoutExercise({
    this.id,
    required this.workoutId,
    required this.exerciseId,
    required this.orderPosition,
    this.exercise,
    this.sets = const [],
    this.notes,
  });

  // Helper to check if all sets are completed
  bool get isCompleted =>
      sets.isNotEmpty && sets.every((set) => set.isCompleted);

  // Helper to get the total number of sets
  int get totalSets => sets.length;

  // Helper to get the number of completed sets
  int get completedSets => sets.where((set) => set.isCompleted).length;

  // Convert to Map for database operations (without the sets and exercise)
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'workoutId': workoutId,
      'exerciseId': exerciseId,
      'orderPosition': orderPosition,
      'notes': notes,
    };
  }

  // Create from Map (e.g., from database) - note that sets and exercise need to be loaded separately
  factory WorkoutExercise.fromMap(
    Map<String, dynamic> map, {
    Exercise? exercise,
    List<WorkoutSet>? sets,
  }) {
    return WorkoutExercise(
      id: map['id'],
      workoutId: map['workoutId'],
      exerciseId: map['exerciseId'],
      orderPosition: map['orderPosition'],
      exercise: exercise,
      sets: sets ?? [],
      notes: map['notes'],
    );
  }

  // Clone with ability to override properties
  WorkoutExercise copyWith({
    int? id,
    int? workoutId,
    int? exerciseId,
    int? orderPosition,
    Exercise? exercise,
    List<WorkoutSet>? sets,
    String? notes,
  }) {
    return WorkoutExercise(
      id: id ?? this.id,
      workoutId: workoutId ?? this.workoutId,
      exerciseId: exerciseId ?? this.exerciseId,
      orderPosition: orderPosition ?? this.orderPosition,
      exercise: exercise ?? this.exercise,
      sets: sets ?? this.sets,
      notes: notes ?? this.notes,
    );
  }
}
