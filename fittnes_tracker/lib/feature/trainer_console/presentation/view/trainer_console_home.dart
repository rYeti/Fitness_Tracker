import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/active_client_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/trainer_licence_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/client_detail_screen.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/nutrition_screen.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/session_review_screen.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/trainer_dashboard_screen.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/workout_builder_screen.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/console_widgets.dart';
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

  /// Injection seam for tests. Defaults to a live provider.
  final TrainerLicenceProvider? licenceProvider;

  final TrainerConsoleRoute initialRoute;

  /// Leaves the console for the trainee app. Set on web, where the console is
  /// the landing surface and there's no route to pop back to.
  final VoidCallback? onExitConsole;

  const TrainerConsoleHome({
    super.key,
    this.repository,
    this.licenceProvider,
    this.initialRoute = TrainerConsoleRoute.dashboard,
    this.onExitConsole,
  });

  @override
  State<TrainerConsoleHome> createState() => _TrainerConsoleHomeState();
}

class _TrainerConsoleHomeState extends State<TrainerConsoleHome> {
  late final ActiveClientProvider _activeClient;
  late final TrainerLicenceProvider _licence;
  late final bool _ownsLicenceProvider;
  late TrainerConsoleRoute _route;

  @override
  void initState() {
    super.initState();
    _route = widget.initialRoute;
    _activeClient = ActiveClientProvider(repository: widget.repository);
    _activeClient.loadClients();

    _ownsLicenceProvider = widget.licenceProvider == null;
    _licence = widget.licenceProvider ?? TrainerLicenceProvider();
  }

  @override
  void dispose() {
    _activeClient.dispose();
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
    return ChangeNotifierProvider<ActiveClientProvider>.value(
      value: _activeClient,
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
            const _MessagesPlaceholder(),
            WorkoutBuilderScreen(repository: widget.repository),
            NutritionScreen(repository: widget.repository),
            SessionReviewScreen(repository: widget.repository),
          ],
        ),
      ),
    );
  }
}

/// Messages is the one section with no implementation behind it yet: the
/// SignalR client package is still an open decision (see
/// chat_signalr_client.dart and chat-flutter-roadmap.md §3), so the repository
/// and provider are signatures only. Saying so beats a tab that opens onto a
/// blank screen.
class _MessagesPlaceholder extends StatelessWidget {
  const _MessagesPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: const SafeArea(
        child: ConsoleEmptyState(
          icon: Icons.forum_outlined,
          title: 'Messaging isn’t wired up yet',
          message:
              'The chat backend is ready, but the client needs a SignalR '
              'package chosen before messages can be sent or received.',
        ),
      ),
    );
  }
}
