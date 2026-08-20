import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/feature/chat/domain/models/conversation_summary.dart';
import 'package:ForgeForm/feature/chat/domain/models/thread_message.dart';
import 'package:ForgeForm/feature/chat/presentation/providers/chat_provider.dart';
import 'package:ForgeForm/feature/chat/presentation/widgets/chat_bubble.dart';
import 'package:ForgeForm/feature/chat/presentation/widgets/chat_composer.dart';
import 'package:ForgeForm/feature/chat/presentation/widgets/chat_connection_banner.dart';
import 'package:ForgeForm/feature/chat/presentation/widgets/chat_date_divider.dart';
import 'package:ForgeForm/feature/chat/presentation/widgets/conversation_row.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/active_client_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/client_avatar.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/console_widgets.dart';

/// Desktop: three columns in one card — conversation list (300px) | thread
/// (fluid) | client context (260px). Mobile: the list is the screen, and tapping
/// a row drills into a full-screen thread with a back arrow.
///
/// The `list | thread` split is screen-local state rather than something on
/// ChatProvider: it is presentation, not shared client data, and on desktop it
/// does not exist at all because both panes are visible at once.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _threadOpenOnMobile = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ChatProvider>().loadConversations();
    });
  }

  Future<void> _openThread(String clientId) async {
    final chat = context.read<ChatProvider>();
    // Opening a thread also moves the console's shared selection, so Builder and
    // Nutrition follow along rather than sitting on a different client.
    context.read<ActiveClientProvider>().setActiveClient(clientId);
    setState(() => _threadOpenOnMobile = true);
    await chat.openThread(clientId);
  }

  Future<void> _backToList() async {
    setState(() => _threadOpenOnMobile = false);
    await context.read<ChatProvider>().closeThread();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Consumer<ChatProvider>(
          builder: (context, chat, _) {
            if (chat.isLoading && chat.conversations.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: ConsoleSkeleton(semanticsLabel: 'Loading conversations'),
              );
            }
            if (chat.error != null) {
              return ConsoleErrorState(
                message: chat.error!,
                onRetry: chat.loadConversations,
              );
            }
            if (chat.conversations.isEmpty) {
              return const ConsoleEmptyState(
                icon: Icons.forum_outlined,
                title: 'No conversations yet',
                message:
                    'Once a client accepts your invite you can message them here.',
              );
            }

            return isDesktop
                ? _DesktopLayout(chat: chat, onSelect: _openThread)
                : _MobileLayout(
                    chat: chat,
                    threadOpen: _threadOpenOnMobile,
                    onSelect: _openThread,
                    onBack: _backToList,
                  );
          },
        ),
      ),
    );
  }
}

// ── Desktop ─────────────────────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  final ChatProvider chat;
  final ValueChanged<String> onSelect;

  const _DesktopLayout({required this.chat, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = _activeConversation(chat);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: ConsoleCard(
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            SizedBox(
              width: 300,
              child: _ConversationList(chat: chat, onSelect: onSelect),
            ),
            VerticalDivider(
              width: 1,
              color: colors.outlineVariant.withValues(alpha: 0.5),
            ),
            Expanded(child: _ThreadPane(chat: chat, conversation: active)),
            if (active != null) ...[
              VerticalDivider(
                width: 1,
                color: colors.outlineVariant.withValues(alpha: 0.5),
              ),
              SizedBox(width: 260, child: _ContextPanel(conversation: active)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Mobile ──────────────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final ChatProvider chat;
  final bool threadOpen;
  final ValueChanged<String> onSelect;
  final VoidCallback onBack;

  const _MobileLayout({
    required this.chat,
    required this.threadOpen,
    required this.onSelect,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    if (!threadOpen) {
      return _ConversationList(chat: chat, onSelect: onSelect);
    }

    final active = _activeConversation(chat);
    return Column(
      children: [
        _MobileThreadHeader(conversation: active, onBack: onBack),
        Expanded(child: _ThreadPane(chat: chat, conversation: active)),
      ],
    );
  }
}

class _MobileThreadHeader extends StatelessWidget {
  final ConversationSummary? conversation;
  final VoidCallback onBack;

  const _MobileThreadHeader({required this.conversation, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ForgeColors.charcoal,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Tooltip(
              message: 'Back to conversations',
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                color: Colors.white,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
            ),
            if (conversation != null) ...[
              ClientAvatar(
                initials: conversation!.initials,
                clientId: conversation!.clientId,
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  conversation!.clientName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

// ── Shared panes ────────────────────────────────────────────────────────────

class _ConversationList extends StatelessWidget {
  final ChatProvider chat;
  final ValueChanged<String> onSelect;

  const _ConversationList({required this.chat, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: chat.conversations.length,
      itemBuilder: (context, index) {
        final conversation = chat.conversations[index];
        return ConversationRow(
          conversation: conversation,
          selected: conversation.clientId == chat.activeThreadId,
          onTap: () => onSelect(conversation.clientId),
        );
      },
    );
  }
}

class _ThreadPane extends StatelessWidget {
  final ChatProvider chat;
  final ConversationSummary? conversation;

  const _ThreadPane({required this.chat, required this.conversation});

  @override
  Widget build(BuildContext context) {
    if (conversation == null) {
      return const ConsoleEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Pick a conversation',
        message: 'Choose a client on the left to see your messages.',
      );
    }

    final clientId = conversation!.clientId;

    return Column(
      children: [
        ChatConnectionBanner(status: chat.connectionStatus),
        Expanded(child: _ThreadBody(chat: chat)),
        ChatComposer(onSend: (body) => chat.sendMessage(clientId, body)),
      ],
    );
  }
}

class _ThreadBody extends StatelessWidget {
  final ChatProvider chat;

  const _ThreadBody({required this.chat});

  @override
  Widget build(BuildContext context) {
    if (chat.isThreadLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: ConsoleSkeleton(rows: 4, rowHeight: 40, semanticsLabel: 'Loading messages'),
      );
    }
    if (chat.threadError != null) {
      return ConsoleErrorState(
        message: chat.threadError!,
        onRetry: () {
          final id = chat.activeThreadId;
          if (id != null) chat.openThread(id);
        },
      );
    }
    if (chat.thread.isEmpty) {
      return const ConsoleEmptyState(
        icon: Icons.waving_hand_outlined,
        title: 'No messages yet',
        message: 'Say hello — this is the start of your conversation.',
      );
    }

    final items = _withDateDividers(chat.thread);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is DateTime) return ChatDateDivider(date: item);
        return ChatBubble(
          message: item as ThreadMessage,
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

/// Desktop-only right column: who you are talking to, at a glance.
class _ContextPanel extends StatelessWidget {
  final ConversationSummary conversation;

  const _ContextPanel({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClientAvatar(
            initials: conversation.initials,
            clientId: conversation.clientId,
            size: 64,
          ),
          const SizedBox(height: 12),
          Text(
            conversation.clientName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            // Adherence and week-progress belong here per the handoff, but the
            // conversations endpoint doesn't carry them and refetching the whole
            // roster to fill one panel isn't worth it yet.
            'Client stats appear on the dashboard and client detail screens.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Exo 2',
              fontSize: 12,
              color: colors.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

ConversationSummary? _activeConversation(ChatProvider chat) {
  final id = chat.activeThreadId;
  if (id == null) return null;
  for (final conversation in chat.conversations) {
    if (conversation.clientId == id) return conversation;
  }
  return null;
}
