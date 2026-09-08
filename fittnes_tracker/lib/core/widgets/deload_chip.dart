import 'package:flutter/material.dart';

import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/feature/workout_planning/domain/deload_schedule.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// Marks a week, a day or a session as a deload.
///
/// One shared widget for every surface that shows one — the schedule day
/// cards, the active-workout header, the week strip, and the Trainer Console's
/// own views — per CLAUDE.md's "one shared widget per repeated pattern".
///
/// Deliberately **not** a [StatusBadge]. That widget's tone enum is
/// `ok / warn / bad`, and a deload is none of the three: it is information, not
/// a judgement. Rendering a planned recovery week as `warn` tells a trainee
/// their programme has a problem in it.
class DeloadChip extends StatelessWidget {
  const DeloadChip({super.key, this.volumePercent, this.compact = false});

  /// The week's prescribed volume, shown as "Deload · 50%" when given.
  ///
  /// The number is the share of normal volume to *perform*, never the
  /// reduction — see [DeloadWeek.volumePercent].
  final int? volumePercent;

  /// Drops the icon for dense contexts. The *word* still carries the meaning,
  /// so this never leaves colour as the only signal.
  final bool compact;

  /// The tint every deload surface sits on.
  static Color backgroundFor(Brightness brightness) =>
      ForgeColors.statusInfo.withValues(
        alpha: brightness == Brightness.dark ? 0.22 : 0.14,
      );

  /// The colour anything reading *on* [backgroundFor] must use.
  ///
  /// The tone is a *fill*. On its own 22% tint over `#2C2C2C` the raw blue
  /// measures 2.91:1 at label size — a fail only a composited check can see,
  /// and the same one `StatusBadge`'s `bad` tone shipped with. Lifting it 45%
  /// toward white takes it to 5.41:1 on the tightest dark surface. 0.45 is
  /// `StatusBadge`'s own factor, kept identical so the two read as one system.
  ///
  /// Lives here rather than in each widget so there is one pair to name, and
  /// `test/core/contrast_test.dart` pins that one.
  static Color foregroundFor(Brightness brightness) =>
      brightness == Brightness.dark
      ? Color.lerp(ForgeColors.statusInfo, Colors.white, 0.45)!
      : ForgeColors.statusInfoOnLight;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final background = backgroundFor(brightness);
    final foreground = foregroundFor(brightness);

    final l10n = AppLocalizations.of(context)!;
    final percent = volumePercent;
    final label = percent == null
        ? l10n.deloadLabel
        : l10n.deloadLabelWithVolume(percent);

    return Semantics(
      // Spelled out for a screen reader: "50%" beside "Deload" is ambiguous
      // read aloud, and the direction of the number is the one thing about
      // this feature a user must not get backwards.
      label: percent == null
          ? l10n.deloadSemanticPlain
          : l10n.deloadSemanticWithVolume(percent),
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact) ...[
              // Paired with the word, never used alone — colour is never the
              // only signal (CLAUDE.md, non-negotiable).
              Icon(Icons.trending_down_rounded, size: 13, color: foreground),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Exo 2',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: foreground,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
