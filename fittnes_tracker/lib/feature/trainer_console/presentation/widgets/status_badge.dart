import 'package:flutter/material.dart';
import 'package:ForgeForm/core/design_tokens.dart';

enum StatusTone { ok, warn, bad }

/// Reusable ok/warn/bad indicator (adherence, attendance, etc.).
/// Must pair color with a label/icon — never color alone (see CLAUDE.md
/// Accessibility: color is never the only signal).
class StatusBadge extends StatelessWidget {
  final StatusTone tone;
  final String label;

  /// Drops the icon for dense contexts (table cells). The *label* still
  /// carries the meaning, so this never leaves colour as the only signal.
  final bool compact;

  const StatusBadge({
    super.key,
    required this.tone,
    required this.label,
    this.compact = false,
  });

  static Color _base(StatusTone tone) => switch (tone) {
    StatusTone.ok => ForgeColors.statusOk,
    StatusTone.warn => ForgeColors.statusWarn,
    StatusTone.bad => ForgeColors.statusBad,
  };

  IconData get _icon => switch (tone) {
    StatusTone.ok => Icons.check_circle_rounded,
    StatusTone.warn => Icons.error_rounded,
    StatusTone.bad => Icons.cancel_rounded,
  };

  /// The tone's wash: what a badge's label sits on, and what anything else
  /// toned like a badge sits on — `RefreshFailedNotice`, for one — so the two
  /// can't drift apart.
  ///
  /// The flat tint that works on white is too dim to read on #121212, so the
  /// dark theme gets a stronger wash.
  static Color tintOf(StatusTone tone, Brightness brightness) => _base(
    tone,
  ).withValues(alpha: brightness == Brightness.dark ? 0.22 : 0.14);

  /// The tone's colour for a label or an icon on its own [tintOf].
  ///
  /// Lifted toward white in the dark theme, and darkened in the light one.
  /// Both lerps are sized by measurement against the tone's own tint, at the
  /// 11px label size — which is body text, so the bar is 4.5:1, not 3:1.
  ///
  ///          raw    lerped
  ///   light  ok   2.86 -> 5.20   (30% toward black)
  ///          warn 1.85 -> 4.70   (40%; amber starts far brighter)
  ///          bad  3.46 -> 6.09   (30%)
  ///   dark   bad       -> 5.06   (45% toward white)
  ///
  /// The dark lerp was 0.35 and gave `bad` only 4.34 — a pre-existing miss
  /// that no test could see until contrast_test.dart named the pair. 0.45
  /// clears all three tones with margin.
  static Color foregroundOf(StatusTone tone, Brightness brightness) {
    final color = _base(tone);
    return brightness == Brightness.dark
        ? Color.lerp(color, Colors.white, 0.45)!
        : Color.lerp(
            color,
            Colors.black,
            tone == StatusTone.warn ? 0.40 : 0.30,
          )!;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final background = tintOf(tone, brightness);
    final foreground = foregroundOf(tone, brightness);

    return Semantics(
      label: label,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact) ...[
              Icon(_icon, size: 13, color: foreground),
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
