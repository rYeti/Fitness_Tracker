import 'workout.dart';

/// Represents a workout schedule/plan that can span multiple days/weeks
class WorkoutPlan {
  final int? id;
  final String name;
  final String? description;
  final DateTime startDate;
  final DateTime? endDate; // null for ongoing plans
  final List<Workout> workouts; // Scheduled workouts in this plan
  final bool isActive; // Whether this plan is currently active

  WorkoutPlan({
    this.id,
    required this.name,
    this.description,
    required this.startDate,
    this.endDate,
    this.workouts = const [],
    this.isActive = true,
  });

  // Helper to check if a date is within the plan period
  bool isDateInPlan(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedStart = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );

    if (normalizedDate.isBefore(normalizedStart)) {
      return false;
    }

    if (endDate != null) {
      final normalizedEnd = DateTime(
        endDate!.year,
        endDate!.month,
        endDate!.day,
      );
      return !normalizedDate.isAfter(normalizedEnd);
    }

    return true; // No end date means the plan is ongoing
  }

  // Helper to get workouts scheduled for a specific date
  List<Workout> getWorkoutsForDate(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    return workouts.where((workout) {
      if (workout.scheduledDate == null) return false;

      final normalizedWorkoutDate = DateTime(
        workout.scheduledDate!.year,
        workout.scheduledDate!.month,
        workout.scheduledDate!.day,
      );

      return normalizedWorkoutDate.isAtSameMomentAs(normalizedDate);
    }).toList();
  }

  // Convert to Map for database operations (without the workouts)
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description ?? '',
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isActive': isActive ? 1 : 0,
    };
  }

  // Create from Map (e.g., from database) - note that workouts need to be loaded separately
  factory WorkoutPlan.fromMap(
    Map<String, dynamic> map, {
    List<Workout>? workouts,
  }) {
    return WorkoutPlan(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      startDate: DateTime.parse(map['startDate']),
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      workouts: workouts ?? [],
      isActive: map['isActive'] == 1,
    );
  }

  // Clone with ability to override properties
  WorkoutPlan copyWith({
    int? id,
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    List<Workout>? workouts,
    bool? isActive,
  }) {
    return WorkoutPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      workouts: workouts ?? this.workouts,
      isActive: isActive ?? this.isActive,
    );
  }
}
