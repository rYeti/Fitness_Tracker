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
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/console_widgets.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/trainer_console_shell.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

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
  /// Null when chat could not be constructed — see [initState]. Everything else
  /// in the console still works, so this is a missing tab, not a broken screen.
  ChatProvider? _chat;

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
    } else if (sl.isRegistered<AppDatabase>()) {
      final signalR = SignalRHubChatClient();
      _signalR = signalR;
      _chat = ChatProvider(
        repository: ChatRepository(db: sl<AppDatabase>(), signalR: signalR),
      );
      // Not awaited: the console renders its roster and KPIs fine while the
      // socket is still opening, and the connection banner covers the gap.
      // Errors are dropped here rather than left unhandled — the failure is
      // already reported twice over, on the status stream that drives the banner
      // and again from the next joinGroup/send, which retries the connect.
      unawaited(signalR.connect().catchError((Object _) {}));
    }
    // Otherwise chat stays null. The outbox needs the local database, and
    // reaching for it unguarded meant a console that could not open *at all*
    // when it was missing — four of five sections have nothing to do with chat.
    _ownsLicenceProvider = widget.licenceProvider == null;
    _licence = widget.licenceProvider ?? TrainerLicenceProvider();
  }

  @override
  void dispose() {
    _activeClient.dispose();
    _chat?.dispose();
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
    final chat = _chat;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ActiveClientProvider>.value(value: _activeClient),
        if (chat != null)
          ChangeNotifierProvider<ChatProvider>.value(value: chat),
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
            if (chat != null)
              const MessagesScreen()
            else
              const _ChatUnavailable(),
            WorkoutBuilderScreen(repository: widget.repository),
            NutritionScreen(repository: widget.repository),
            SessionReviewScreen(repository: widget.repository),
          ],
        ),
      ),
    );
  }
}

/// Shown in place of Messages when the chat stack could not be built.
///
/// Says so plainly rather than rendering an empty thread: a trainer who sees a
/// blank inbox assumes nobody has written to them.
class _ChatUnavailable extends StatelessWidget {
  const _ChatUnavailable();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: ConsoleEmptyState(
          icon: Icons.forum_outlined,
          title: l10n.chatUnavailable,
          message: l10n.chatUnavailableBody,
        ),
      ),
    );
  }
}
