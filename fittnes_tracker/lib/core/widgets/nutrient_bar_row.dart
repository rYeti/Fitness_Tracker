import 'package:flutter/material.dart';

import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/core/nutrition/extended_nutrients.dart';
import 'package:ForgeForm/core/nutrition/nutrient_defs.dart';
import 'package:ForgeForm/core/widgets/progress_bar.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// One nutrient row: label, group caption, value, and a progress bar against
/// its daily reference target — the row both the Trainer Console's "Tracked
/// nutrients" card and its meal-detail "Micronutrients" rail are built from,
/// and the only place that decides a bar's colour and "Low"/"Over" state.
///
/// Reuses [ProgressBar] (already pill-shaped, already clamps 0-1) rather than
/// drawing a second bar — CLAUDE.md: one shared widget per repeated pattern.
class NutrientBarRow extends StatelessWidget {
  final NutrientDef def;
  final ExtendedNutrients nutrients;

  /// Only a day-level bar may flag "Low" — the design's own rule: a single
  /// meal cannot structurally reach a daily target, so a per-meal bar sitting
  /// at 20% of the day's iron goal isn't a warning sign the way a day sitting
  /// there is.
  final bool dayScope;

  /// Null hides the pin affordance entirely (the trainee's read-only card).
  /// Non-null shows a pin icon and makes the row tappable.
  final bool? pinned;
  final VoidCallback? onToggle;

  const NutrientBarRow({
    super.key,
    required this.def,
    required this.nutrients,
    required this.dayScope,
    this.pinned,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final value = def.displayValue(nutrients);
    final label = def.label(l10n);
    final group = def.group.label(l10n);

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (pinned == true) ...[
                Icon(Icons.push_pin, size: 14, color: ForgeColors.forgeOrange),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Exo 2',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                group,
                style: TextStyle(
                  fontFamily: 'Exo 2',
                  fontSize: 11,
                  color: colors.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const Spacer(),
              if (value != null)
                Text(
                  formatValue(value, def.displayUnit(l10n)),
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: colors.onSurface,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          if (value == null)
            Text(
              l10n.micronutrientsNoData,
              style: TextStyle(
                fontFamily: 'Exo 2',
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            )
          else ...[
            Row(
              children: [
                Text(
                  l10n.nutrientOfTarget(
                    formatTarget(def.target),
                    def.displayUnit(l10n),
                  ),
                  style: TextStyle(
                    fontFamily: 'Exo 2',
                    fontSize: 11,
                    color: colors.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const Spacer(),
                if (_stateLabel(l10n) != null)
                  Text(
                    _stateLabel(l10n)!,
                    style: TextStyle(
                      fontFamily: 'Exo 2',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _tone(brightness),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            ProgressBar(
              value: value / def.target,
              color: _tone(brightness),
              semanticsLabel: _semanticsLabel(l10n, value),
            ),
          ],
        ],
      ),
    );

    if (onToggle == null) return content;
    return Semantics(
      button: true,
      label: _rowSemanticsLabel(l10n, value),
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onToggle, child: content),
      ),
    );
  }

  bool get _isLow {
    final value = def.displayValue(nutrients);
    if (value == null || !dayScope || def.invert) return false;
    return value < def.target * 0.6;
  }

  bool get _isOver {
    final value = def.displayValue(nutrients);
    if (value == null || !def.invert) return false;
    return value > def.target;
  }

  Color _tone(Brightness brightness) {
    if (_isOver) return ForgeColors.statusBadFor(brightness);
    if (_isLow) return ForgeColors.statusWarnFor(brightness);
    return ForgeColors.forgeOrange;
  }

  String? _stateLabel(AppLocalizations l10n) {
    if (_isOver) return l10n.nutrientOver;
    if (_isLow) return l10n.nutrientLow;
    return null;
  }

  String _semanticsLabel(AppLocalizations l10n, double value) {
    final base = l10n.nutrientBarSemantics(
      def.label(l10n),
      formatValue(value, def.displayUnit(l10n)),
      l10n.nutrientOfTarget(formatTarget(def.target), def.displayUnit(l10n)),
      _isOver
          ? l10n.nutrientBarSemanticsOver
          : _isLow
              ? l10n.nutrientBarSemanticsLow
              : '',
    );
    return base;
  }

  String _rowSemanticsLabel(AppLocalizations l10n, double? value) =>
      value == null
          ? '${def.label(l10n)}, ${l10n.micronutrientsNoData}'
          : _semanticsLabel(l10n, value);

  static String formatValue(double value, String unit) =>
      '${formatNumber(value)} $unit';

  static String formatNumber(double value) =>
      value >= 10 ? value.toStringAsFixed(1) : value.toStringAsFixed(2);

  /// Targets are curated reference constants (30 g, 8 mg, 2.5 µg — see
  /// nutrient_defs.dart), not measured quantities, so [formatNumber]'s
  /// precision rule is wrong for them: it would print an integer target like
  /// 8 as "8.00". This strips the decimal entirely for a whole number and
  /// otherwise prints the value as authored.
  static String formatTarget(double target) => target == target.roundToDouble()
      ? target.toInt().toString()
      : target.toString();
}
