import 'package:flutter/material.dart';

import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/feature/chat/domain/models/conversation_summary.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/client_avatar.dart';

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
      label: _semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: selected
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
                  color: selected ? ForgeColors.forgeOrange : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(13, 12, 16, 12),
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
                                fontSize: 13.5,
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
                        conversation.lastMessagePreview ?? 'No messages yet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Exo 2',
                          fontSize: 12.5,
                          color: colors.onSurface.withValues(alpha: 0.62),
                        ),
                      ),
                    ],
                  ),
                ),
                if (conversation.hasUnread) ...[
                  const SizedBox(width: 8),
                  _UnreadBadge(count: conversation.unreadCount),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _semanticsLabel {
    final unread = conversation.hasUnread
        ? ', ${conversation.unreadCount} unread'
        : '';
    final preview = conversation.lastMessagePreview;
    return '${conversation.clientName}$unread'
        '${preview == null ? '' : ', last message: $preview'}';
  }

  /// Time for today, weekday inside the last week, date beyond that — the
  /// resolution a reader actually needs at each distance.
  static String _timeLabel(DateTime at) {
    final local = at.toLocal();
    final now = DateTime.now();
    final sameDay =
        local.year == now.year && local.month == now.month && local.day == now.day;
    if (sameDay) {
      final hour = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    if (now.difference(local).inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[local.weekday - 1];
    }
    return '${local.day}/${local.month}';
  }
}

/// The count itself, not just a coloured dot: a dot tells a colourblind trainer
/// nothing, and "how many" is the useful part anyway.
class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        color: ForgeColors.forgeOrange,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: Colors.white,
        ),
      ),
    );
  }
}
