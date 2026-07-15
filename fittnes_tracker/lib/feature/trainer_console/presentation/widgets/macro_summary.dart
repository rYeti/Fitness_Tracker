import 'package:flutter/material.dart';

/// Protein/carbs/fat bar — CLAUDE.md design-system component name
/// `MacroSummary`. Reused by Client Detail and Nutrition, never
/// re-implemented per screen.
class MacroSummary extends StatelessWidget {
  final int protein;
  final int carbs;
  final int fat;
  final int calorieGoal;

  const MacroSummary({
    super.key,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.calorieGoal,
  });

  @override
  Widget build(BuildContext context) {
    // TODO: stacked/segmented bar in fixed macro colors (protein #E53935,
    // carbs #1E88E5, fat #43A047) + gram labels, per design handoff.
    return const SizedBox.shrink();
  }
}
