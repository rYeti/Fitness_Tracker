import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/core/providers/access_provider.dart';
import 'package:ForgeForm/feature/chat/domain/models/thread_message.dart';
import 'package:ForgeForm/feature/chat/presentation/providers/chat_provider.dart';
import 'package:ForgeForm/feature/chat/presentation/widgets/chat_bubble.dart';
import 'package:ForgeForm/feature/chat/presentation/widgets/chat_composer.dart';
import 'package:ForgeForm/feature/chat/presentation/widgets/chat_connection_banner.dart';
import 'package:ForgeForm/feature/chat/presentation/widgets/chat_date_divider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/client_avatar.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/console_widgets.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// The trainee's side of the conversation.
///
/// One thread and no list, because a trainee has exactly one trainer. Everything
/// below the header is the same widget set the Trainer Console uses — the
/// repository deals in "the other party" rather than in roles, so the only
/// difference between the two surfaces is which id gets passed in.
class CoachChatScreen extends StatefulWidget {
  const CoachChatScreen({super.key});

  @override
  State<CoachChatScreen> createState() => _CoachChatScreenState();
}

class _CoachChatScreenState extends State<CoachChatScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final trainerId = context.read<AccessProvider>().trainerId;
      if (trainerId != null) {
        context.read<ChatProvider>().openThread(trainerId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessProvider>();
    final l10n = AppLocalizations.of(context)!;
    final trainerId = access.trainerId;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: _CoachAppBar(
        trainerId: trainerId,
        trainerName: access.trainerName,
        fallbackTitle: l10n.coachChat,
      ),
      body: SafeArea(
        child: trainerId == null
            ? ConsoleEmptyState(
                icon: Icons.person_search_outlined,
                title: l10n.coachChatNoCoach,
                message: l10n.coachChatNoCoachBody,
              )
            : Consumer<ChatProvider>(
                builder: (context, chat, _) => Column(
                  children: [
                    ChatConnectionBanner(status: chat.connectionStatus),
                    Expanded(child: _CoachThread(chat: chat, trainerId: trainerId)),
                    ChatComposer(
                      onSend: (body) => chat.sendMessage(trainerId, body),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _CoachAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? trainerId;
  final String? trainerName;

  /// Shown until the roster check resolves a name.
  final String fallbackTitle;

  const _CoachAppBar({
    required this.trainerId,
    required this.trainerName,
    required this.fallbackTitle,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // Charcoal in both themes, matching the console — this is brand chrome.
      backgroundColor: ForgeColors.charcoal,
      foregroundColor: Colors.white,
      title: Row(
        children: [
          if (trainerId != null && trainerName != null) ...[
            ClientAvatar(
              initials: _initials(trainerName!),
              clientId: trainerId!,
              size: 30,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              trainerName ?? fallbackTitle,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _CoachThread extends StatelessWidget {
  final ChatProvider chat;
  final String trainerId;

  const _CoachThread({required this.chat, required this.trainerId});

  @override
  Widget build(BuildContext context) {
    if (chat.isThreadLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: ConsoleSkeleton(
          rows: 4,
          rowHeight: 40,
          semanticsLabel: 'Loading messages',
        ),
      );
    }
    final l10n = AppLocalizations.of(context)!;
    if (chat.threadError != null) {
      return ConsoleErrorState(
        message: l10n.coachChatLoadError,
        onRetry: () => chat.openThread(trainerId),
      );
    }
    if (chat.thread.isEmpty) {
      return ConsoleEmptyState(
        icon: Icons.waving_hand_outlined,
        title: l10n.coachChatEmpty,
        message: l10n.coachChatEmptyBody,
      );
    }

    final items = <Object>[];
    DateTime? previous;
    for (final message in chat.thread) {
      if (ChatDateDivider.needed(previous, message.timestamp)) {
        items.add(message.timestamp);
      }
      items.add(message);
      previous = message.timestamp;
    }

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
}
