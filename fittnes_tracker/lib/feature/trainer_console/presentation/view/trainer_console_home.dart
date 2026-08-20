import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/di/service_locator.dart';
import 'package:ForgeForm/feature/chat/data/chat_repository.dart';
import 'package:ForgeForm/feature/chat/data/signalr_hub_chat_client.dart';
import 'package:ForgeForm/feature/chat/presentation/providers/chat_provider.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/active_client_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/trainer_licence_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/client_detail_screen.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/messages_screen.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/nutrition_screen.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/session_review_screen.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/trainer_dashboard_screen.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/workout_builder_screen.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/trainer_console_shell.dart';

/// Entry point for the Trainer Console.
///
/// Owns the things that must outlive any single screen: the shared
/// [ActiveClientProvider] (CLAUDE.md — one active client across Chat, Builder,
/// Nutrition and Session Review, switching without a navigation reload), the
/// current route, and the [TrainerLicenceProvider] — seat usage is
/// console-wide state, not the Dashboard's private business, and minting an
/// invite from one screen has to move the seat meter on another.
///
/// Screens are kept alive in an [IndexedStack] so switching sections doesn't
/// re-fetch everything; a screen reloads only when the active client actually
/// changes, which each screen watches for itself.
class TrainerConsoleHome extends StatefulWidget {
  /// Injection seam for tests.
  final TrainerConsoleRepository? repository;

  /// Injection seam for chat, so tests never open a socket or need a database.
  final ChatRepository? chatRepository;
  /// Injection seam for tests. Defaults to a live provider.
  final TrainerLicenceProvider? licenceProvider;

  final TrainerConsoleRoute initialRoute;

  /// Leaves the console for the trainee app. Set on web, where the console is
  /// the landing surface and there's no route to pop back to.
  final VoidCallback? onExitConsole;

  const TrainerConsoleHome({
    super.key,
    this.repository,
    this.chatRepository,
    this.licenceProvider,
    this.initialRoute = TrainerConsoleRoute.dashboard,
    this.onExitConsole,
  });

  @override
  State<TrainerConsoleHome> createState() => _TrainerConsoleHomeState();
}

class _TrainerConsoleHomeState extends State<TrainerConsoleHome> {
  late final ActiveClientProvider _activeClient;
  late final ChatProvider _chat;

  /// Only set when this widget built the transport itself, so an injected one
  /// is never closed out from under its owner.
  SignalRHubChatClient? _signalR;

  late final TrainerLicenceProvider _licence;
  late final bool _ownsLicenceProvider;
  late TrainerConsoleRoute _route;

  @override
  void initState() {
    super.initState();
    _route = widget.initialRoute;
    _activeClient = ActiveClientProvider(repository: widget.repository);
    _activeClient.loadClients();

    // Built here rather than inside MessagesScreen: it owns the SignalR
    // connection, which has to survive switching to Nutrition and back. A
    // provider created by the screen would drop the socket on every tab change.
    final injected = widget.chatRepository;
    if (injected != null) {
      _chat = ChatProvider(repository: injected);
    } else {
      final signalR = SignalRHubChatClient();
      _signalR = signalR;
      _chat = ChatProvider(
        repository: ChatRepository(db: sl<AppDatabase>(), signalR: signalR),
      );
      // Not awaited: the console renders its roster and KPIs fine while the
      // socket is still opening, and the connection banner covers the gap.
      unawaited(signalR.connect());
    }
    _ownsLicenceProvider = widget.licenceProvider == null;
    _licence = widget.licenceProvider ?? TrainerLicenceProvider();
  }

  @override
  void dispose() {
    _activeClient.dispose();
    _chat.dispose();
    unawaited(_signalR?.dispose() ?? Future<void>.value());
    if (_ownsLicenceProvider) _licence.dispose();
    super.dispose();
  }

  void _openClientDetail(String clientId, String clientName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientDetailScreen(
          clientId: clientId,
          clientName: clientName,
          repository: widget.repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ActiveClientProvider>.value(value: _activeClient),
        ChangeNotifierProvider<ChatProvider>.value(value: _chat),
      ],
      child: TrainerConsoleShell(
        currentRoute: _route,
        onRouteSelected: (route) => setState(() => _route = route),
        onExitConsole: widget.onExitConsole,
        child: IndexedStack(
          index: TrainerConsoleRoute.values.indexOf(_route),
          children: [
            TrainerDashboardScreen(
              repository: widget.repository,
              licenceProvider: _licence,
              onClientSelected: (entry) =>
                  _openClientDetail(entry.clientId, entry.clientName),
            ),
            const MessagesScreen(),
            WorkoutBuilderScreen(repository: widget.repository),
            NutritionScreen(repository: widget.repository),
            SessionReviewScreen(repository: widget.repository),
          ],
        ),
      ),
    );
  }
}
