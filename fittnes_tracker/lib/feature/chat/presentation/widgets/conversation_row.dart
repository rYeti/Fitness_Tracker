import 'package:flutter/material.dart';

import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/feature/chat/domain/chat_timestamps.dart';
import 'package:ForgeForm/feature/chat/domain/models/conversation_summary.dart';
import 'package:ForgeForm/feature/chat/presentation/widgets/unread_badge.dart';
import 'package:ForgeForm/core/widgets/client_avatar.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// One row in the conversation list: avatar, name, time, truncated preview and
/// an unread count. Shared by the console's list pane and any other surface that
/// needs the same row, so the selected/unread treatment can't drift between them.
class ConversationRow extends StatelessWidget {
  final ConversationSummary conversation;
  final bool selected;
  final VoidCallback onTap;

  const ConversationRow({
    super.key,
    required this.conversation,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: _semanticsLabel(context),
      excludeSemantics: true,
      child: Material(
        color:
            selected
                ? ForgeColors.forgeOrange.withValues(alpha: 0.08)
                : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            // Comfortably past the 44px minimum tap target on mobile.
            constraints: const BoxConstraints(minHeight: 64),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color:
                      selected ? ForgeColors.forgeOrange : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
            child: Row(
              children: [
                ClientAvatar(
                  initials: conversation.initials,
                  clientId: conversation.clientId,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.clientName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (conversation.lastMessageAt != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              _timeLabel(conversation.lastMessageAt!),
                              style: TextStyle(
                                fontFamily: 'Exo 2',
                                fontSize: 11,
                                color: colors.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _preview(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Exo 2',
                          fontSize: 12,
                          color: colors.onSurface.withValues(alpha: 0.62),
                        ),
                      ),
                    ],
                  ),
                ),
                if (conversation.hasUnread) ...[
                  const SizedBox(width: 8),
                  UnreadBadge(count: conversation.unreadCount),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// What this row says the last message was.
  ///
  /// Three cases, not two. A thread with no messages says so; a thread whose
  /// last message this device cannot decrypt says "New message", because
  /// something *was* said and the row must not claim otherwise; and everything
  /// else shows the text.
  ///
  /// The unreadable case is told apart from the empty one by the timestamp: a
  /// conversation that has never been used has no [ConversationSummary.lastMessageAt]
  /// either, and one that has is simply unreadable here.
  String _preview(BuildContext context) {
    final preview = conversation.lastMessagePreview;
    if (preview != null) return preview;

    return conversation.lastMessageAt == null
        ? 'No messages yet'
        : AppLocalizations.of(context)!.chatNewMessage;
  }

  String _semanticsLabel(BuildContext context) {
    final unread =
        conversation.hasUnread ? ', ${conversation.unreadCount} unread' : '';
    // Reads out whatever the row draws, including the unreadable fallback: a
    // screen reader user must not be told a conversation is empty when the
    // sighted one beside them can see it is not.
    final preview =
        conversation.lastMessageAt == null ? null : _preview(context);
    return '${conversation.clientName}$unread'
        '${preview == null ? '' : ', last message: $preview'}';
  }

  /// Time for today, weekday inside the last week, date beyond that — the
  /// resolution a reader actually needs at each distance. Shared with the
  /// thread's own timestamps so the two cannot disagree about what day a
  /// message landed on.
  static String _timeLabel(DateTime at) => ChatTimestamps.listLabel(at);
}
