/// The kind of set being performed. Warmup sets are excluded from volume and
/// PR calculations by default; dropset/failure exist for accurate history.
enum SetType { normal, warmup, dropset, failure }

/// Which side a unilateral set was performed with. [both] for normal bilateral
/// sets; left/right sets show separately in progression charts so strength
/// imbalances stay visible.
enum SetSide { both, left, right }

/// Represents a single set within a workout exercise
/// For example: "12 reps at 50kg" or "60 seconds of jumping jacks"
class WorkoutSet {
  final int? id;
  final int
  exerciseInstanceId; // Links to the specific exercise instance in a workout
  final int setNumber; // The sequence of this set (1, 2, 3, etc.)
  final int? reps; // Number of repetitions (null for time-based)
  final double? weight; // Weight used (null for bodyweight)
  final String? weightUnit; // kg, lbs, etc.
  final int? durationSeconds; // Duration in seconds (null for rep-based)
  final bool isCompleted; // Whether this set has been completed
  final String? notes; // Any notes for this specific set
  final String? targetReps;
  final int? rpe; // Rate of Perceived Exertion (6-10), null when not logged
  final SetType setType;
  final SetSide side;

  WorkoutSet({
    this.id,
    required this.exerciseInstanceId,
    required this.setNumber,
    this.reps,
    this.weight,
    this.weightUnit,
    this.durationSeconds,
    this.isCompleted = false,
    this.notes,
    this.targetReps,
    this.rpe,
    this.setType = SetType.normal,
    this.side = SetSide.both,
  });

  // Convert to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'exerciseInstanceId': exerciseInstanceId,
      'setNumber': setNumber,
      'reps': reps,
      'weight': weight,
      'weightUnit': weightUnit,
      'durationSeconds': durationSeconds,
      'isCompleted': isCompleted ? 1 : 0,
      'notes': notes,
      'targetReps': targetReps,
      'rpe': rpe,
      'setType': setType.index,
      'side': side.index,
    };
  }

  // Create from Map (e.g., from database)
  factory WorkoutSet.fromMap(Map<String, dynamic> map) {
    return WorkoutSet(
      id: map['id'],
      exerciseInstanceId: map['exerciseInstanceId'],
      setNumber: map['setNumber'],
      reps: map['reps'],
      weight: map['weight'],
      weightUnit: map['weightUnit'],
      durationSeconds: map['durationSeconds'],
      isCompleted: map['isCompleted'] == 1,
      notes: map['notes'],
      targetReps: map['targetReps'],
      rpe: map['rpe'],
      setType: SetType.values[map['setType'] ?? 0],
      side: SetSide.values[map['side'] ?? 0],
    );
  }

  // Clone with ability to override properties
  WorkoutSet copyWith({
    int? id,
    int? exerciseInstanceId,
    int? setNumber,
    int? reps,
    double? weight,
    String? weightUnit,
    int? durationSeconds,
    bool? isCompleted,
    String? notes,
    String? targetReps,
    int? rpe,
    SetType? setType,
    SetSide? side,
  }) {
    return WorkoutSet(
      id: id ?? this.id,
      exerciseInstanceId: exerciseInstanceId ?? this.exerciseInstanceId,
      setNumber: setNumber ?? this.setNumber,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      weightUnit: weightUnit ?? this.weightUnit,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isCompleted: isCompleted ?? this.isCompleted,
      notes: notes ?? this.notes,
      targetReps: targetReps ?? this.targetReps,
      rpe: rpe ?? this.rpe,
      setType: setType ?? this.setType,
      side: side ?? this.side,
    );
  }
}
