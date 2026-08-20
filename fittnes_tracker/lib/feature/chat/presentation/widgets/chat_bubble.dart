import 'package:flutter/material.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/feature/chat/domain/models/thread_message.dart';

/// One message in a thread.
///
/// Takes a [ThreadMessage], so it neither knows nor cares whether the message
/// came from the server or is still sitting in this device's outbox — the three
/// states below are the only thing it reacts to.
class ChatBubble extends StatelessWidget {
  final ThreadMessage message;

  /// Invoked when the user taps a failed message to send it again.
  final ValueChanged<String>? onRetry;

  const ChatBubble({super.key, required this.message, this.onRetry});

  static const _mineRadius = BorderRadius.only(
    topLeft: Radius.circular(14),
    topRight: Radius.circular(4),
    bottomLeft: Radius.circular(14),
    bottomRight: Radius.circular(14),
  );

  static const _theirsRadius = BorderRadius.only(
    topLeft: Radius.circular(4),
    topRight: Radius.circular(14),
    bottomLeft: Radius.circular(14),
    bottomRight: Radius.circular(14),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final mine = message.isMine;
    final pending = message.status == ChatMessageStatus.pending;
    final failed = message.status == ChatMessageStatus.failed;

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: mine ? ForgeColors.forgeOrange : colors.surfaceContainerHighest,
        borderRadius: mine ? _mineRadius : _theirsRadius,
      ),
      child: Text(
        message.body ?? '',
        style: TextStyle(
          fontFamily: 'Exo 2',
          fontSize: 13.5,
          height: 1.35,
          color: mine ? Colors.white : colors.onSurface,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Semantics(
            label: mine ? 'You said' : 'They said',
            value: message.body ?? '',
            excludeSemantics: true,
            child: Opacity(
              // Dimmed rather than hidden: the message is real and the user
              // should keep seeing it, just not as settled yet.
              opacity: pending ? 0.6 : 1,
              child: bubble,
            ),
          ),
          if (pending) const _SendingMarker(),
          if (failed) _FailedMarker(onTap: () => onRetry?.call(message.messageId)),
        ],
      ),
    );
  }
}

class _SendingMarker extends StatelessWidget {
  const _SendingMarker();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 3, right: 2),
      child: Tooltip(
        message: 'Sending',
        child: Icon(
          Icons.schedule_rounded,
          size: 13,
          color: colors.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

/// The one message state with no automatic way out.
///
/// A pending message is the reconnect loop's problem; a failed one has already
/// exhausted it, so this is the only place the user has to act.
class _FailedMarker extends StatelessWidget {
  final VoidCallback onTap;

  const _FailedMarker({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Semantics(
        button: true,
        label: 'Failed to send. Tap to retry.',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 14,
                  color: ForgeColors.statusBad,
                ),
                const SizedBox(width: 4),
                // Icon plus words, never colour alone.
                const Text(
                  'Failed to send — tap to retry',
                  style: TextStyle(
                    fontFamily: 'Exo 2',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: ForgeColors.statusBad,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
