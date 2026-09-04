import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/core/providers/access_provider.dart';
import 'package:ForgeForm/feature/chat/presentation/providers/chat_attachment_provider.dart';
import 'package:ForgeForm/feature/chat/presentation/providers/chat_provider.dart';
import 'package:ForgeForm/feature/chat/presentation/widgets/chat_composer.dart';
import 'package:ForgeForm/feature/chat/presentation/widgets/chat_connection_banner.dart';
import 'package:ForgeForm/feature/chat/presentation/widgets/chat_send_error_strip.dart';
import 'package:ForgeForm/feature/chat/presentation/widgets/chat_thread_list.dart';
import 'package:ForgeForm/core/widgets/client_avatar.dart';
import 'package:ForgeForm/core/widgets/app_widgets.dart';
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
        child:
            trainerId == null
                ? EmptyStateView(
                  icon: Icons.person_search_outlined,
                  title: l10n.coachChatNoCoach,
                  message: l10n.coachChatNoCoachBody,
                )
                : ChangeNotifierProvider(
                  create: (_) => ChatAttachmentProvider(),
                  child: Consumer<ChatProvider>(
                    builder:
                        (context, chat, _) => Column(
                          children: [
                            ChatConnectionBanner(status: chat.connectionStatus),
                            Expanded(
                              child: ChatThreadList(
                                chat: chat,
                                emptyMessage: l10n.coachChatEmptyBody,
                                onRetry: () => chat.openThread(trainerId),
                              ),
                            ),
                            ChatSendErrorStrip(
                              error: chat.sendError,
                              onDismiss: chat.clearSendError,
                            ),
                            ChatComposer(
                              onSend:
                                  (draft) => chat.sendMessage(
                                    trainerId,
                                    draft.caption,
                                    attachment: draft.attachment,
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
              initials: ClientAvatar.initialsFor(trainerName!),
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
}
