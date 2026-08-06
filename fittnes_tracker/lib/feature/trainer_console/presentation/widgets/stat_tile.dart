import 'package:flutter/material.dart';

/// KPI tile: icon-in-tinted-square + Montserrat bold value + Exo 2 label.
/// Shared across the trainee Dashboard and the Trainer Console Dashboard —
/// don't reimplement this pattern inline in either screen.
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
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Icon(icon, color: accentColor, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Exo 2',
            fontSize: 11,
            color: colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}
