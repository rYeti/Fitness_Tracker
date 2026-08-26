import 'package:flutter/material.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/feature/chat/domain/chat_timestamps.dart';
import 'package:ForgeForm/feature/chat/domain/models/thread_message.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

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

    // Only a message the server has acknowledged has a real time to show. The
    // other two states carry the moment this device queued them, which is not
    // the same thing and must not be read as one.
    final settled = !pending && !failed;

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
            // The time is part of what was said, not decoration: a screen reader
            // gets no day divider and no small grey text, so without it a thread
            // reads as one undated run of messages.
            value: settled
                ? '${message.body ?? ''}, '
                    '${ChatTimestamps.accessibleLabel(message.timestamp)}'
                : message.body ?? '',
            excludeSemantics: true,
            child: Opacity(
              // Dimmed rather than hidden: the message is real and the user
              // should keep seeing it, just not as settled yet.
              opacity: pending ? 0.6 : 1,
              child: bubble,
            ),
          ),
          // One line under the bubble, and only ever one thing on it: a settled
          // message shows when it was sent, an unsettled one shows why it has no
          // time yet. Pending deliberately shows no clock time — the moment the
          // user pressed send is not the moment the message exists, and printing
          // it would date a message the server may never have received.
          if (pending)
            const _SendingMarker()
          else if (failed)
            _FailedMarker(onTap: () => onRetry?.call(message.messageId))
          else
            // Excluded from the accessibility tree: the bubble's own semantic
            // value already carries this time, spelled out with its day.
            ExcludeSemantics(child: _MessageTime(at: message.timestamp)),
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
        message: AppLocalizations.of(context)!.chatSending,
        child: Icon(
          Icons.schedule_rounded,
          size: 13,
          color: colors.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

/// When a settled message was sent, in the reader's timezone.
class _MessageTime extends StatelessWidget {
  final DateTime at;

  const _MessageTime({required this.at});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 3, left: 2, right: 2),
      child: Tooltip(
        // The time alone stops being enough as soon as a thread is scrolled back
        // past its day divider.
        message: ChatTimestamps.accessibleLabel(at),
        child: Text(
          ChatTimestamps.timeOfDay(at),
          style: TextStyle(
            fontFamily: 'Exo 2',
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            // 0.6 on the surface colour clears WCAG AA for this size against
            // both themes' card backgrounds; the bubble's own colour is not
            // behind it, so the orange/white pairing is not in play here.
            color: colors.onSurface.withValues(alpha: 0.6),
          ),
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
    final label = AppLocalizations.of(context)!.chatFailedRetry;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Semantics(
        button: true,
        label: label,
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
                Text(
                  label,
                  style: const TextStyle(
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
