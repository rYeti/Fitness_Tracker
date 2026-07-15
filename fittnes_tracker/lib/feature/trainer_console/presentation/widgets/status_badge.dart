import 'package:flutter/material.dart';

enum StatusTone { ok, warn, bad }

/// Reusable ok/warn/bad indicator (adherence, attendance, etc.).
/// Must pair color with a label/icon — never color alone (see CLAUDE.md
/// Accessibility: color is never the only signal).
class StatusBadge extends StatelessWidget {
  final StatusTone tone;
  final String label;

  const StatusBadge({super.key, required this.tone, required this.label});

  @override
  Widget build(BuildContext context) {
    // TODO: pill-shaped badge, tone-tinted background/text (green/amber/red),
    // per design handoff STATUS map. Pair with an icon, not color alone.
    return const SizedBox.shrink();
  }
}
