import 'package:flutter/material.dart';
import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// Protein/carbs/fat bar — CLAUDE.md design-system component name
/// `MacroSummary`. Reused by Client Detail and Nutrition, never
/// re-implemented per screen.
///
/// Macro colours are fixed brand-wide (protein red / carbs blue / fat green)
/// and never themed — see design_tokens.dart.
class MacroSummary extends StatelessWidget {
  final int protein;
  final int carbs;
  final int fat;

  /// Kept for API compatibility with existing call sites. The bar is
  /// proportioned by macro grams, not calories, so this isn't used for layout.
  final int calorieGoal;

  /// Hides the gram labels for tight spaces (e.g. a roster row).
  final bool showLabels;

  const MacroSummary({
    super.key,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.calorieGoal,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final total = protein + carbs + fat;

    final segments = <({Color color, int grams, String label})>[
      (color: ForgeColors.proteinColor, grams: protein, label: l10n.proteinLabel),
      (color: ForgeColors.carbsColor, grams: carbs, label: l10n.carbsLabel),
      (color: ForgeColors.fatColor, grams: fat, label: l10n.fatLabel),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: total == 0
              ? l10n.macroSummaryNone
              : l10n.macroSummarySemantics('$protein', '$carbs', '$fat'),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 8,
              child: total == 0
                  // An empty day still shows the track, so the bar doesn't
                  // vanish and leave an unexplained gap.
                  ? ColoredBox(
                      color: colors.onSurface.withValues(alpha: 0.08),
                      child: const SizedBox.expand(),
                    )
                  : Row(
                      children: [
                        for (final segment in segments)
                          if (segment.grams > 0)
                            Expanded(
                              flex: segment.grams,
                              child: ColoredBox(color: segment.color),
                            ),
                      ],
                    ),
            ),
          ),
        ),
        if (showLabels) ...[
          const SizedBox(height: 8),
          // Wrap, not Row: three legends don't fit side by side in a narrow
          // card (e.g. the 340px Nutrition ring column), and a Row overflows
          // rather than reflowing.
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              for (final segment in segments)
                _Legend(
                  color: segment.color,
                  label: segment.label,
                  grams: segment.grams,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final int grams;

  const _Legend({
    required this.color,
    required this.label,
    required this.grams,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$label ${grams}g',
          style: TextStyle(
            fontFamily: 'Exo 2',
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: colors.onSurface.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}
