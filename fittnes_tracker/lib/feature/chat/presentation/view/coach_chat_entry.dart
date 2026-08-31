import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/di/service_locator.dart';
import 'package:ForgeForm/feature/chat/data/chat_repository.dart';
import 'package:ForgeForm/feature/chat/data/signalr_hub_chat_client.dart';
import 'package:ForgeForm/feature/chat/presentation/providers/chat_provider.dart';
import 'package:ForgeForm/feature/chat/presentation/view/coach_chat_screen.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/console_widgets.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// Owns the chat connection for the trainee app.
///
/// The Trainer Console keeps its ChatProvider at the shell so the socket
/// survives tab switches. The trainee has no equivalent shell — chat is a pushed
/// route — so the lifetime is this widget's: connect on push, close on pop.
/// Building it here rather than at app root also means a trainee who never opens
/// chat never opens a socket.
class CoachChatEntry extends StatefulWidget {
  /// Injection seam for tests, so they never open a socket or need a database.
  final ChatRepository? repository;

  const CoachChatEntry({super.key, this.repository});

  @override
  State<CoachChatEntry> createState() => _CoachChatEntryState();
}

class _CoachChatEntryState extends State<CoachChatEntry> {
  /// Null when the chat stack could not be built — same reasoning as the
  /// console's: the local outbox needs the database, and a missing one should
  /// produce an explanation rather than a crash on push.
  ChatProvider? _chat;
  SignalRHubChatClient? _signalR;

  @override
  void initState() {
    super.initState();
    final injected = widget.repository;
    if (injected != null) {
      _chat = ChatProvider(repository: injected);
    } else if (sl.isRegistered<AppDatabase>()) {
      final signalR = SignalRHubChatClient();
      _signalR = signalR;
      final repository = ChatRepository(db: sl<AppDatabase>(), signalR: signalR);
      _chat = ChatProvider(repository: repository);

      // Publishing this device's chat key, alongside the connect and for the
      // same reason: a network round trip that must not hold up the screen.
      unawaited(repository.prepareKeys().catchError((Object _) {}));

      // Errors dropped rather than left unhandled: the failure reaches the user
      // through the connection banner, and the next joinGroup/send retries it.
      unawaited(signalR.connect().catchError((Object _) {}));
    }
  }

  @override
  void dispose() {
    _chat?.dispose();
    unawaited(_signalR?.dispose() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = _chat;
    if (chat == null) {
      final l10n = AppLocalizations.of(context)!;
      return Scaffold(
        appBar: AppBar(title: Text(l10n.coachChat)),
        body: SafeArea(
          child: ConsoleEmptyState(
            icon: Icons.forum_outlined,
            title: l10n.chatUnavailable,
            message: l10n.chatUnavailableBody,
          ),
        ),
      );
    }
    return ChangeNotifierProvider<ChatProvider>.value(
      value: chat,
      child: const CoachChatScreen(),
    );
  }
}
