import 'package:flutter/material.dart';

/// Pill-shaped progress bar — the one in the design handoff, in one place.
///
/// `LinearProgressIndicator` was re-clipped, re-coloured and re-sized inline in
/// seven files: the seat meter, the roster adherence bar, the daily calorie
/// bar, the weight-goal card, the active-workout header and two food screens.
/// Each spelled the same three decisions slightly differently, which is how a
/// "pill" ends up with four different corner radii across one product.
///
/// `CLAUDE.md`: pill (999px) for progress bars, and one shared widget per
/// repeated pattern.
class ProgressBar extends StatelessWidget {
  /// 0.0–1.0. Values outside are clamped rather than throwing — callers
  /// computing `done / planned` overshoot legitimately (a client can complete
  /// more sessions than were scheduled) and a bar that renders past its track
  /// is a rendering bug, not a data one.
  final double value;

  /// Null uses the theme's primary. Pass a status tone to carry meaning —
  /// and pair it with a label, since colour is never the only signal.
  final Color? color;

  final double height;

  /// Announced to screen readers. A bare bar reads as a meaningless
  /// percentage, so callers should say what is progressing.
  final String? semanticsLabel;

  const ProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 8,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: colors.onSurface.withValues(alpha: 0.1),
        valueColor: AlwaysStoppedAnimation<Color>(color ?? colors.primary),
      ),
    );

    if (semanticsLabel == null) return bar;
    return Semantics(
      label: semanticsLabel,
      value: '${(value.clamp(0.0, 1.0) * 100).round()}%',
      child: ExcludeSemantics(child: bar),
    );
  }
}
