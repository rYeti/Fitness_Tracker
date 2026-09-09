import 'package:flutter/material.dart';

/// How a [PersonalBestCard] is dressed. The three forms exist because a PB is
/// rendered in three different surroundings, not because the widget wants
/// options: on its own in a column, on its own but secondary to a bigger
/// number, and inside a tile that already draws its own surface.
enum PersonalBestStyle {
  /// Card chrome, label above a large value. Reads as a headline number.
  hero,

  /// Card chrome, one line — `label: 100 kg × 5 reps`. Secondary to whatever
  /// it sits under.
  compact,

  /// No chrome at all, one line. For slotting into a widget that already owns
  /// its background, such as an `ExpansionTile` subtitle.
  inline,
}

/// A personal best — one set that actually happened — rendered the same way
/// everywhere it appears.
///
/// Takes the set rather than a formatted string so that the weight is
/// formatted in exactly one place: a PB shown as `100 kg` on one screen and
/// `100.0 kg` on another reads as two different numbers.
///
/// The record type is written structurally rather than importing
/// `PersonalBestSet` from the data layer, so a presentation widget doesn't
/// drag the database in behind it; the two types are the same shape and are
/// assignable in both directions.
class PersonalBestCard extends StatelessWidget {
  final ({double weight, int reps}) best;
  final String label;
  final IconData icon;
  final PersonalBestStyle style;
  final Color foreground;

  /// Card fill. Unused by [PersonalBestStyle.inline], which draws no surface.
  final Color? background;

  const PersonalBestCard({
    super.key,
    required this.best,
    required this.label,
    required this.icon,
    required this.foreground,
    this.style = PersonalBestStyle.compact,
    this.background,
  });

  /// `100 kg`, not `100.0 kg` — but `102.5 kg` keeps its half-plate.
  static String formatWeight(double weight) =>
      weight.truncateToDouble() == weight
          ? weight.toStringAsFixed(0)
          : weight.toStringAsFixed(1);

  static String formatSet(({double weight, int reps}) best) =>
      '${formatWeight(best.weight)} kg × ${best.reps} reps';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueText = formatSet(best);

    // The icon is decoration on top of a label that already says what this is
    // — per CLAUDE.md a status is never carried by colour or glyph alone — so
    // the screen reader gets the pair as one phrase and not the trophy.
    return Semantics(
      label: '$label: $valueText',
      excludeSemantics: true,
      child: switch (style) {
        PersonalBestStyle.hero => Card(
          color: background,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _labelRow(theme, bold: false),
                const SizedBox(height: 8),
                Text(
                  valueText,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        PersonalBestStyle.compact => Card(
          color: background,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: _oneLine(theme, valueText),
          ),
        ),
        PersonalBestStyle.inline => _oneLine(
          theme,
          valueText,
          alignment: MainAxisAlignment.start,
        ),
      },
    );
  }

  Widget _labelRow(ThemeData theme, {required bool bold}) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 20, color: foreground),
      const SizedBox(width: 8),
      Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: foreground,
          fontWeight: bold ? FontWeight.bold : null,
        ),
      ),
    ],
  );

  Widget _oneLine(
    ThemeData theme,
    String valueText, {
    MainAxisAlignment alignment = MainAxisAlignment.center,
  }) => Row(
    mainAxisAlignment: alignment,
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 20, color: foreground),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          '$label: $valueText',
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(
            color: foreground,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ],
  );
}
