import 'package:flutter/material.dart';

import 'package:ForgeForm/feature/chat/domain/chat_timestamps.dart';

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
        child: Semantics(
          header: true,
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
      ),
    );
  }

  /// The day this divider announces, in the reader's timezone.
  ///
  /// Local, and that is the fix rather than a detail: this used to read the
  /// calendar fields straight off a UTC instant while [needed] compared local
  /// ones, so either side of midnight the pill could name a different day than
  /// the one whose messages it sat above.
  String get label => ChatTimestamps.dayLabel(date);

  /// Whether a divider belongs between [previous] and [next].
  static bool needed(DateTime? previous, DateTime next) =>
      ChatTimestamps.crossesDay(previous, next);
}
