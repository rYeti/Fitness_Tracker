import 'dart:async';
import 'package:ForgeForm/core/app_router.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/di/service_locator.dart';
import 'package:ForgeForm/core/widgets/lazy_indexed_stack.dart';
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
import 'package:ForgeForm/core/widgets/app_widgets.dart';
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
/// Screens are built on their first visit and kept alive from then on, so switching
/// sections doesn't re-fetch everything; a screen reloads only when the active client
/// actually changes, which each screen watches for itself.
///
/// The "kept alive" half used to be spelled as a plain [IndexedStack], which also builds
/// every child immediately — so opening the console mounted all five sections at once and
/// each fired its own loads for a screen nobody was looking at. [LazyIndexedStack] keeps
/// the part that was wanted and drops the part that wasn't.
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

  /// Whether switching sections should also update the address bar via
  /// `GoRouter.go`.
  ///
  /// True only for the instance [PostAuthHome] mounts at `/` or
  /// `/console/:section` — the one that actually owns that location. A
  /// console reached by pushing `/trainer-console` (Settings, on any
  /// platform) or by a notification tap is a second, independent instance
  /// layered on top of whatever page is already showing; it must never call
  /// `go()`. `go()` rebuilds the router's *entire* match list for the target
  /// location, and because `/console/:section` is a single route matched by
  /// pattern, that rebuild reuses the page already in the stack for that
  /// pattern — the original PostAuthHome instance sitting under the push —
  /// rather than the freshly pushed one. That page still carries whatever
  /// `_showTraineeApp` was last set to, so a trainer who had switched to "My
  /// Training" before opening this second console got dropped straight back
  /// into it the moment they picked a section, instead of seeing the section
  /// they tapped. See `docs/trainer-console-route-collision.md`.
  final bool syncUrl;

  const TrainerConsoleHome({
    super.key,
    this.repository,
    this.chatRepository,
    this.licenceProvider,
    this.initialRoute = TrainerConsoleRoute.dashboard,
    this.onExitConsole,
    this.syncUrl = false,
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
      final repository = ChatRepository(db: sl<AppDatabase>(), signalR: signalR);
      _chat = ChatProvider(repository: repository);

      // Started next to the connect, and for the same reason: it is a network
      // round trip that must not block the console's first paint. A failure
      // leaves this device with no published key, which shows up as messages
      // the other side cannot read -- so it is retried on the next visit rather
      // than swallowed forever.
      unawaited(repository.prepareKeys().catchError((Object _) {}));

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

    // Conversations are loaded here rather than by MessagesScreen, for the same reason the
    // socket is: the sidebar's unread badge is folded from them, and loading them is what
    // joins this device to every thread's hub group. Both have to happen whether or not the
    // trainer ever opens Messages.
    unawaited(_chat?.loadConversations() ?? Future<void>.value());
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

  /// Switches section *and* puts it in the address bar.
  ///
  /// The URL is written with `go` rather than `push` so the five sections stay
  /// siblings rather than stacking: a trainer moving Dashboard → Messages →
  /// Nutrition and pressing back expects Messages, not a history entry per
  /// visit. Keeping `_route` as the source of truth for the visible pane means
  /// `LazyIndexedStack` still holds each section's state across switches —
  /// routing rebuilds the URL, not the panes.
  void _selectRoute(TrainerConsoleRoute route) {
    if (route == _route) return;
    setState(() => _route = route);
    // Only the instance PostAuthHome mounts at the current location owns the
    // address bar — see the doc comment on [TrainerConsoleHome.syncUrl].
    if (!widget.syncUrl) return;
    // maybeOf, not of: the console is mounted directly in widget tests and
    // could be embedded anywhere else, and it should not require a router to
    // function. The URL is an enhancement on top of the section state, not
    // the state itself.
    GoRouter.maybeOf(context)?.go('/console/${AppRouter.segmentFor(route)}');
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
        onRouteSelected: _selectRoute,
        onExitConsole: widget.onExitConsole,
        child: LazyIndexedStack(
          index: TrainerConsoleRoute.values.indexOf(_route),
          builders: [
            (_) => TrainerDashboardScreen(
              repository: widget.repository,
              licenceProvider: _licence,
              onClientSelected: (entry) =>
                  _openClientDetail(entry.clientId, entry.clientName),
            ),
            (_) => chat != null ? const MessagesScreen() : const _ChatUnavailable(),
            (_) => WorkoutBuilderScreen(repository: widget.repository),
            (_) => NutritionScreen(repository: widget.repository),
            (_) => SessionReviewScreen(repository: widget.repository),
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
      body: SafeArea(
        child: EmptyStateView(
          icon: Icons.forum_outlined,
          title: l10n.chatUnavailable,
          message: l10n.chatUnavailableBody,
        ),
      ),
    );
  }
}
