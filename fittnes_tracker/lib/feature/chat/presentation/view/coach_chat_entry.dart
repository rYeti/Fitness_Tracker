import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/di/service_locator.dart';
import 'package:ForgeForm/feature/chat/data/chat_repository.dart';
import 'package:ForgeForm/feature/chat/data/signalr_hub_chat_client.dart';
import 'package:ForgeForm/feature/chat/presentation/providers/chat_provider.dart';
import 'package:ForgeForm/feature/chat/presentation/view/coach_chat_screen.dart';

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
  late final ChatProvider _chat;
  SignalRHubChatClient? _signalR;

  @override
  void initState() {
    super.initState();
    final injected = widget.repository;
    if (injected != null) {
      _chat = ChatProvider(repository: injected);
    } else {
      final signalR = SignalRHubChatClient();
      _signalR = signalR;
      _chat = ChatProvider(
        repository: ChatRepository(db: sl<AppDatabase>(), signalR: signalR),
      );
      unawaited(signalR.connect());
    }
  }

  @override
  void dispose() {
    _chat.dispose();
    unawaited(_signalR?.dispose() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ChatProvider>.value(
      value: _chat,
      child: const CoachChatScreen(),
    );
  }
}
