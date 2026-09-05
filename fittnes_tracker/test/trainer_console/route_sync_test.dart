import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ForgeForm/l10n/app_localizations.dart';

import 'package:ForgeForm/feature/chat/data/chat_repository.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/trainer_console_home.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/trainer_console_shell.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/trainer_licence_provider.dart';

import '../chat/fakes.dart';
import 'fakes.dart';
import 'licence_fakes.dart';

/// Reproduces docs/trainer-console-route-collision.md: a console that isn't
/// the router's current page for `/` or `/console/:section` must never call
/// `GoRouter.go` when a section is switched — doing so lets go_router reuse
/// the *other* console page (matched by route pattern, not by which instance
/// pushed it) and silently swap the trainer onto whatever state that other
/// page happens to hold.
///
/// `shell_test.dart` mounts `TrainerConsoleHome` under a plain `MaterialApp`
/// with no `GoRouter` in the tree at all, so `GoRouter.maybeOf(context)` is
/// always null there and the bug this pins was invisible to it.
void main() {
  /// Stands in for `PostAuthHome`: a single flag that decides whether this
  /// location shows the console or "My Training", exactly like
  /// `_showTraineeApp`. Registered at both `/` and `/console/:section`, the
  /// same as the real app, so go_router's page-identity reuse has the same
  /// route pattern collision to fall into.
  final showTraineeApp = ValueNotifier<bool>(false);

  Widget _consoleHome({
    required TrainerConsoleRoute initialRoute,
    required bool syncUrl,
    VoidCallback? onExitConsole,
  }) {
    final db = newTestDatabase();
    addTearDown(db.close);
    return TrainerConsoleHome(
      repository: FakeTrainerConsoleRepository(
        rosterWithStats: [fakeRosterEntry()],
        nutrition: fakeNutrition(),
      ),
      licenceProvider: TrainerLicenceProvider(
        repository: FakeTrainerLicenceRepository(current: licence()),
      ),
      chatRepository: ChatRepository(
        db: db,
        api: FakeChatApi(),
        signalR: FakeChatSignalRClient(),
        crypto: FakeChatCrypto(),
        attachmentSender: FakeChatAttachmentSender(),
      ),
      initialRoute: initialRoute,
      syncUrl: syncUrl,
      onExitConsole: onExitConsole,
    );
  }

  Widget buildHome(TrainerConsoleRoute? section) {
    return ValueListenableBuilder<bool>(
      valueListenable: showTraineeApp,
      builder: (context, isTrainee, _) {
        if (isTrainee) return const Scaffold(body: Text('MY TRAINING'));
        return _consoleHome(
          initialRoute: section ?? TrainerConsoleRoute.dashboard,
          syncUrl: true,
          onExitConsole: () => showTraineeApp.value = true,
        );
      },
    );
  }

  late GoRouter router;

  setUp(() {
    showTraineeApp.value = false;
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => buildHome(null)),
        GoRoute(
          path: '/console/:section',
          builder: (context, state) {
            final section = switch (state.pathParameters['section']) {
              'messages' => TrainerConsoleRoute.messages,
              'builder' => TrainerConsoleRoute.builder,
              'nutrition' => TrainerConsoleRoute.nutrition,
              'session-review' => TrainerConsoleRoute.sessionReview,
              _ => TrainerConsoleRoute.dashboard,
            };
            return buildHome(section);
          },
        ),
        // Mirrors the pushed `/trainer-console` route: a second, independent
        // console instance with no PostAuthHome wrapper and syncUrl left at
        // its default of false.
        GoRoute(
          path: '/trainer-console',
          builder: (_, __) =>
              _consoleHome(initialRoute: TrainerConsoleRoute.dashboard, syncUrl: false),
        ),
      ],
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'switching sections in a pushed console does not fall back to the '
    'trainee app left showing underneath it',
    (tester) async {
      await pump(tester);

      // Leave the console for "My Training" on the instance PostAuthHome owns
      // at '/' — the state the bug leaves stale.
      showTraineeApp.value = true;
      await tester.pumpAndSettle();
      expect(find.text('MY TRAINING'), findsOneWidget);

      // Reopen the console the way Settings does: push '/trainer-console' on
      // top, a second, independent instance.
      router.push('/trainer-console');
      await tester.pumpAndSettle();
      expect(find.text('MY TRAINING'), findsNothing);
      expect(find.text('Dashboard'), findsWidgets);

      // Switch a section inside the pushed console.
      await tester.tap(find.text('Nutrition').first);
      await tester.pumpAndSettle();

      // Must still be showing the console — specifically the section that
      // was tapped — not the stale "My Training" state from the page
      // underneath the push.
      expect(find.text('MY TRAINING'), findsNothing);
      expect(find.textContaining('Daily intake'), findsOneWidget);
    },
  );
}
