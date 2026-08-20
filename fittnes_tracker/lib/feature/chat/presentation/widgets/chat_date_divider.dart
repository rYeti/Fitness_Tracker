import 'package:flutter/material.dart';

/// Day separator between runs of messages.
class ChatDateDivider extends StatelessWidget {
  final DateTime date;

  const ChatDateDivider({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Exo 2',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  String get label {
    final local = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(local).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    return '${local.day}/${local.month}/${local.year}';
  }

  /// Whether a divider belongs between [previous] and [next].
  static bool needed(DateTime? previous, DateTime next) {
    if (previous == null) return true;
    final a = previous.toLocal();
    final b = next.toLocal();
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }
}
