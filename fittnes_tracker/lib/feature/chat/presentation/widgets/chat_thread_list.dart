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

  @override
  void initState() {
    super.initState();
    // Opening a thread should land on the newest message, not the oldest. The
    // list is forward-ordered, so without this a thread with any history opens
    // scrolled to the top — reading as "nothing recent here".
    _scrollToBottomIfGrown();
  }

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
  /// Messages are appended to the end of a forward-ordered list, so without this
  /// anything sent into a thread longer than the viewport lands below the fold —
  /// indistinguishable, from the user's side, from a message that was never sent
  /// at all.
  void _scrollToBottomIfGrown() {
    final count = widget.chat.thread.length;
    if (count <= _lastCount) {
      _lastCount = count;
      return;
    }
    _lastCount = count;

    // After the frame that lays the new item out, or maxScrollExtent is still
    // the old bottom.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;

      final bottom = _controller.position.maxScrollExtent;
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
      controller: _controller,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is DateTime) return ChatDateDivider(date: item);
        return ChatBubble(
          message: item as ThreadMessage,
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
