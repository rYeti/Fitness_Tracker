import 'package:flutter/material.dart';

/// Motion durations that respect the OS "reduce motion" setting.
///
/// `CLAUDE.md` requires it — *"Respect the OS-level reduced-motion setting —
/// fall back to instant/cross-fade transitions rather than skipping the state
/// change entirely"* — under an accessibility section marked non-negotiable.
/// Exactly one place in the codebase honoured it (`meal_detail_sheet.dart`,
/// via `MediaQuery.disableAnimationsOf`), and nine animation sites did not.
///
/// The reason it went missing nine times is that honouring it requires
/// remembering to, at every call site, with no compiler or test to notice the
/// omission. Making it the *default* path is the fix: a screen that asks for a
/// duration gets a respectful one without knowing the setting exists.
///
/// Note the fallback is [Duration.zero], not "no animation". The state change
/// still happens and the widget still rebuilds — it simply arrives instantly.
/// Skipping the transition entirely would drop the state change with it.
abstract final class ForgeMotion {
  /// Standard duration for UI chrome: opening a sheet, switching a tab,
  /// expanding a card. `CLAUDE.md`: 150–250ms, ease-out, nothing over 300ms.
  static const Duration standard = Duration(milliseconds: 200);

  /// For a change that needs to read as deliberate — a page transition, say.
  /// Still inside the 300ms ceiling.
  static const Duration emphasis = Duration(milliseconds: 300);

  /// Small state flips: a chip selecting, an icon swapping.
  static const Duration quick = Duration(milliseconds: 150);

  /// [duration], or [Duration.zero] when the viewer has asked for reduced
  /// motion. Pass this to `AnimatedContainer`, `AnimatedSize`, an
  /// `AnimationController`, or anything else taking a duration.
  static Duration of(BuildContext context, [Duration duration = standard]) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;

  /// Whether the viewer has asked for reduced motion.
  ///
  /// For the cases a duration cannot express: a looping decorative animation
  /// has no "instant" version, so the caller has to stop driving it. The
  /// barcode scanner's scan line is the example — a continuous loop in front
  /// of someone trying to aim a camera is what this OS setting exists to stop.
  static bool isReduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// Ease-out for entering, per `CLAUDE.md`.
  static const Curve curve = Curves.easeOut;
}
