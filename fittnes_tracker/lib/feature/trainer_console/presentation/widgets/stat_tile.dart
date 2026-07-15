import 'package:flutter/material.dart';

/// KPI card: icon tile (12%-tint color square + glyph) + Montserrat bold
/// number + Exo 2 label. Used in the Dashboard KPI row.
class StatTile extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String value;
  final String label;

  const StatTile({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    // TODO: card (12px radius, 0.5px hairline border, soft shadow), 16px
    // padding, icon tile top-left, value + label below.
    return const SizedBox.shrink();
  }
}
