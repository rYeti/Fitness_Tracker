import 'package:flutter/material.dart';

/// Calorie ring (kcal consumed / goal) used by Nutrition and Client Detail.
class CalorieRing extends StatelessWidget {
  final int kcalConsumed;
  final int kcalGoal;
  final double size;

  const CalorieRing({
    super.key,
    required this.kcalConsumed,
    required this.kcalGoal,
    this.size = 132,
  });

  @override
  Widget build(BuildContext context) {
    // TODO: CustomPainter ring (progress = kcalConsumed / kcalGoal, orange
    // normally / danger red if over), kcal + "/goal" text centered, per
    // design handoff's SVG ring markup.
    return const SizedBox.shrink();
  }
}
