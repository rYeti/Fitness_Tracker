class SetTemplates {
  final int setNumber;
  final String targetRange;
  final String targetReps;

  SetTemplates({
    required this.setNumber,
    required this.targetRange,
    required this.targetReps,
  });

  SetTemplates copyWith({
    int? setNumber,
    String? targetRange,
    String? targetReps,
  }) {
    return SetTemplates(
      setNumber: setNumber ?? this.setNumber,
      targetRange: targetRange ?? this.targetRange,
      targetReps: targetReps ?? this.targetReps,
    );
  }
}
