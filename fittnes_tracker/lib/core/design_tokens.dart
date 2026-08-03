import 'package:flutter/material.dart';

/// Fixed brand and macro colors from the design handoff (CLAUDE.md
/// "Design tokens" section) — do not deviate. Single source of truth so a
/// color literal can't silently drift (e.g. Forge Orange typo'd as
/// `#FF6B35` instead of `#FF6B3E`).
abstract final class ForgeColors {
  static const forgeOrange = Color(0xFFFF6B3E);
  static const charcoal = Color(0xFF333333);

  static const proteinColor = Color(0xFFE53935);
  static const carbsColor = Color(0xFF1E88E5);
  static const fatColor = Color(0xFF43A047);
}
