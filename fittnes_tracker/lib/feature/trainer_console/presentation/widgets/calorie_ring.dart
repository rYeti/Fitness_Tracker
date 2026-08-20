import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ForgeForm/core/design_tokens.dart';

/// Calorie ring (kcal consumed / goal) used by Nutrition and Client Detail.
///
/// Turns red past the goal rather than simply capping the sweep — a trainer
/// needs "over budget" to be visible at a glance, not just "full".
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
    final colors = Theme.of(context).colorScheme;
    final hasGoal = kcalGoal > 0;
    final progress = hasGoal ? kcalConsumed / kcalGoal : 0.0;
    final isOver = hasGoal && kcalConsumed > kcalGoal;
    final remaining = kcalGoal - kcalConsumed;

    final label = !hasGoal
        ? '$kcalConsumed kcal logged, no goal set'
        : isOver
        ? '$kcalConsumed of $kcalGoal kcal, over by ${-remaining}'
        : '$kcalConsumed of $kcalGoal kcal, $remaining remaining';

    // One node for the whole ring: the label already states consumed, goal and
    // remaining, so letting the three Texts announce separately would just
    // repeat it in fragments.
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: label,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            progress: progress.clamp(0.0, 1.0),
            isOver: isOver,
            trackColor: colors.onSurface.withValues(alpha: 0.1),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$kcalConsumed',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w800,
                    fontSize: size * 0.22,
                    height: 1.1,
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  hasGoal ? '/ $kcalGoal kcal' : 'kcal',
                  style: TextStyle(
                    fontFamily: 'Exo 2',
                    fontSize: size * 0.085,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                if (hasGoal) ...[
                  const SizedBox(height: 4),
                  Text(
                    isOver ? 'over by ${-remaining}' : '$remaining left',
                    style: TextStyle(
                      fontFamily: 'Exo 2',
                      fontSize: size * 0.08,
                      fontWeight: FontWeight.w700,
                      color: isOver
                          ? ForgeColors.statusBad
                          : ForgeColors.forgeOrange,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final bool isOver;
  final Color trackColor;

  _RingPainter({
    required this.progress,
    required this.isOver,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.09;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.width - stroke) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;

    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = isOver ? ForgeColors.statusBad : ForgeColors.forgeOrange;

    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // 12 o'clock
      progress * 2 * math.pi,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.isOver != isOver ||
      old.trackColor != trackColor;
}
