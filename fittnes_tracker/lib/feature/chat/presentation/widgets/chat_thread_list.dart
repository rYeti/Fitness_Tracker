import 'package:flutter/material.dart';

import 'package:ForgeForm/feature/chat/domain/models/thread_message.dart';
import 'package:ForgeForm/feature/chat/presentation/providers/chat_provider.dart';
import 'package:ForgeForm/feature/chat/presentation/widgets/chat_bubble.dart';
import 'package:ForgeForm/feature/chat/presentation/widgets/chat_date_divider.dart';
import 'package:ForgeForm/core/widgets/app_widgets.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// The message list, in all four of its states.
///
/// One widget rather than two near-identical copies: the Trainer Console's
/// thread pane and the trainee's coach chat had the same loading/error/empty
/// branches, the same date-divider interleaving and the same `ListView.builder`
/// written out twice, which is exactly the duplication CLAUDE.md's "one shared
/// widget per repeated pattern" rule exists to stop. Only the empty-state copy
/// actually differs between the two surfaces, so only that is a parameter.
class ChatThreadList extends StatefulWidget {
  final ChatProvider chat;

  /// Body copy for the empty state — the trainer and the trainee are told
  /// different things about a thread nobody has written in yet.
  final String emptyMessage;

  /// Retries the thread load. The console re-opens the active thread; the
  /// trainee re-opens its one and only coach thread.
  final VoidCallback onRetry;

  const ChatThreadList({
    super.key,
    required this.chat,
    required this.emptyMessage,
    required this.onRetry,
  });

  @override
  State<ChatThreadList> createState() => _ChatThreadListState();
}

class _ChatThreadListState extends State<ChatThreadList> {
  final _controller = ScrollController();

  /// Thread length at the last scroll, so growth is distinguishable from a
  /// rebuild that changed nothing about where the bottom is.
  int _lastCount = 0;

  /// The thread [_lastCount] was counted in. Switching clients in the console
  /// reuses this State, so without this a shorter thread looks like a thread
  /// that shrank — and shrinking is the one thing that never needs a scroll.
  String? _lastThreadId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatThreadList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scrollToBottomIfGrown();
  }

  /// Puts a newly arrived message on screen.
  ///
  /// The list is reversed, so the newest message sits at offset 0 and a thread
  /// opens at the bottom without any scrolling at all. This only covers the one
  /// case the framework can't: the user has scrolled up into history and a
  /// message — usually their own — arrives at the other end.
  void _scrollToBottomIfGrown() {
    final threadId = widget.chat.activeThreadId;
    final count = widget.chat.thread.length;
    if (threadId != _lastThreadId) {
      // A different thread's list starts life at offset 0, which is already the
      // bottom. Adopt its length so its first message doesn't read as growth.
      _lastThreadId = threadId;
      _lastCount = count;
      return;
    }
    if (count <= _lastCount) {
      _lastCount = count;
      return;
    }
    _lastCount = count;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;

      // minScrollExtent, not maxScrollExtent: in a lazy list the far end is an
      // estimate extrapolated from the children built so far, so scrolling to
      // it lands somewhere arbitrary. The near end is always exactly 0.
      final bottom = _controller.position.minScrollExtent;
      // Reduced motion is an accessibility setting, not a preference to weigh:
      // jump instead of animating, but still make the move.
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _controller.jumpTo(bottom);
      } else {
        _controller.animateTo(
          bottom,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chat = widget.chat;

    if (chat.isThreadLoading) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: LoadingSkeleton(
          rows: 4,
          rowHeight: 40,
          semanticsLabel: l10n.messagesLoading,
        ),
      );
    }
    if (chat.threadError != null) {
      return ErrorStateView(
        message: l10n.coachChatLoadError,
        onRetry: widget.onRetry,
      );
    }
    if (chat.thread.isEmpty) {
      return EmptyStateView(
        icon: Icons.waving_hand_outlined,
        title: l10n.coachChatEmpty,
        message: widget.emptyMessage,
      );
    }

    final items = _withDateDividers(chat.thread);

    return ListView.builder(
      // A fresh scroll position per thread — otherwise switching clients in
      // the console keeps the previous thread's offset into the new one.
      key: ValueKey(chat.activeThreadId),
      controller: _controller,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        // items is forward-ordered (dividers precede the day's first message);
        // reverse: true paints index 0 at the bottom, so read from the end.
        final item = items[items.length - 1 - index];
        if (item is DateTime) return ChatDateDivider(date: item);
        final message = item as ThreadMessage;
        return ChatBubble(
          // Without this, `ListView.builder` matches elements by index, not
          // identity — a day divider spliced in when older history loads
          // shifts every later index by one, and a video bubble's
          // `_VideoTileState` (a live `Player`, an open fullscreen route, a
          // temp file) gets silently reassociated with a different message.
          // Invisible before this feature (inline playback was short-lived);
          // a fullscreen route makes it a real, user-visible bug.
          key: ValueKey(message.messageId),
          message: message,
          threadId: chat.activeThreadId,
          onRetry: chat.retryMessage,
        );
      },
    );
  }

  /// Interleaves day markers into the message list so the builder stays flat —
  /// grouping into sections would complicate scroll position for no gain.
  static List<Object> _withDateDividers(List<ThreadMessage> messages) {
    final items = <Object>[];
    DateTime? previous;
    for (final message in messages) {
      if (ChatDateDivider.needed(previous, message.timestamp)) {
        items.add(message.timestamp);
      }
      items.add(message);
      previous = message.timestamp;
    }
    return items;
  }
}
