import 'package:flutter/material.dart';

/// Fixed brand and macro colors from the design handoff (CLAUDE.md
/// "Design tokens" section) — do not deviate. Single source of truth so a
/// color literal can't silently drift (e.g. Forge Orange typo'd as
/// `#FF6B35` instead of `#FF6B3E`).
abstract final class ForgeColors {
  static const forgeOrange = Color(0xFFFF6B3E);
  static const charcoal = Color(0xFF333333);

  /// Forge Orange for **light** surfaces. The brand orange is a 2.83:1 pair
  /// with white, so it cannot carry white-on-orange fill, text or an icon on
  /// anything light — it fails even the 3:1 large-text bar.
  ///
  /// This is the same hue darkened 30% toward black, which clears AA against
  /// *both* light surfaces: 5.32:1 on `#FFFFFF` and 4.88:1 on
  /// [backgroundLight]. The page background is the binding constraint — a
  /// shallower 25% darkening reaches 4.75 on white but only 4.36 on
  /// `#F5F5F5`, which is how the first attempt at this token shipped a value
  /// that failed on half the surfaces it was for. `contrast_test.dart` now
  /// asserts both.
  ///
  /// Dark surfaces keep [forgeOrange]: it measures 4.94:1 on [cardDark] and
  /// 5.89:1 on [surfaceDark], so darkening there would cost brand fidelity
  /// for no accessibility gain.
  ///
  /// Rejected alternative: charcoal on orange is 4.47:1 — still short of AA,
  /// and it loses the white-on-orange look entirely.
  static const forgeOrangeOnLight = Color(0xFFB24B2B);

  /// Page background behind [surfaceLight] cards. White cards on a white page
  /// are a 1.00:1 pair, which left the 2dp drop shadow as the only thing
  /// making a card visible; this is the value the design handoff specifies.
  static const backgroundLight = Color(0xFFF5F5F5);
  static const surfaceLight = Color(0xFFFFFFFF);

  static const backgroundDark = Color(0xFF121212);
  static const surfaceDark = Color(0xFF1E1E1E);
  static const cardDark = Color(0xFF2C2C2C);

  /// Input borders. A border is the only thing marking where a field is, so
  /// it is a non-text UI component under WCAG 1.4.11 and needs 3:1. The old
  /// values (`#E0E0E0` on white, `#404040` on the dark card) measured 1.32
  /// and 1.35 — roughly a quarter of the requirement.
  static const borderLight = Color(0xFF949494);
  static const borderDark = Color(0xFF7A7A7A);

  static const proteinColor = Color(0xFFE53935);
  static const carbsColor = Color(0xFF1E88E5);
  static const fatColor = Color(0xFF43A047);

  /// Status tones (CLAUDE.md "Status tones: ok = green, warn = amber,
  /// bad = red"). Always pair with a label/icon — never color alone.
  static const statusOk = Color(0xFF43A047);
  static const statusWarn = Color(0xFFFFA000);
  static const statusBad = Color(0xFFE53935);
}
