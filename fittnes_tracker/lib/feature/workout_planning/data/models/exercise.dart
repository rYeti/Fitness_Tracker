/// Defines the type of exercise
enum ExerciseType {
  strength, // Strength training (weights)
  cardio, // Cardiovascular exercise
  flexibility, // Stretching, yoga, etc.
  calisthenics, // Bodyweight exercises
}

/// Defines the primary muscle group targeted by the exercise
enum MuscleGroup {
  chest,
  back,
  shoulders,
  biceps,
  triceps,
  legs,
  abs,
  fullBody,
}

/// Represents a single exercise that can be included in workouts
class Exercise {
  final int? id;
  final String name;
  final String? description;
  final ExerciseType type;
  final List<MuscleGroup> targetMuscleGroups;
  final String? imageUrl;
  final bool
  isCustom; // Whether this is a custom user exercise or a predefined one

  Exercise({
    this.id,
    required this.name,
    this.description,
    required this.type,
    required this.targetMuscleGroups,
    this.imageUrl,
    this.isCustom = false,
  });

  // Convert to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description ?? '',
      'type': type.index,
      'targetMuscleGroups': targetMuscleGroups.map((mg) => mg.index).toList(),
      'imageUrl': imageUrl,
      'isCustom': isCustom ? 1 : 0,
    };
  }

  // Create from Map (e.g., from database)
  factory Exercise.fromMap(Map<String, dynamic> map) {
    List<dynamic> muscleGroupIndices =
        map['targetMuscleGroups'] is String
            ? List<int>.from(
              map['targetMuscleGroups']
                  .split(',')
                  .map((e) => int.parse(e.trim())),
            )
            : List<int>.from(map['targetMuscleGroups'] ?? []);

    return Exercise(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      type: ExerciseType.values[map['type'] ?? 0],
      targetMuscleGroups:
          muscleGroupIndices.map((index) => MuscleGroup.values[index]).toList(),
      imageUrl: map['imageUrl'],
      isCustom: map['isCustom'] == 1,
    );
  }

  // Clone the exercise with ability to override specific properties
  Exercise copyWith({
    int? id,
    String? name,
    String? description,
    ExerciseType? type,
    List<MuscleGroup>? targetMuscleGroups,
    String? imageUrl,
    bool? isCustom,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      targetMuscleGroups: targetMuscleGroups ?? this.targetMuscleGroups,
      imageUrl: imageUrl ?? this.imageUrl,
      isCustom: isCustom ?? this.isCustom,
    );
  }
}
