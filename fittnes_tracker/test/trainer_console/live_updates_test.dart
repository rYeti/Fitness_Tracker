import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/widgets/app_widgets.dart';
import 'package:ForgeForm/feature/chat/data/chat_repository.dart';
import 'package:ForgeForm/feature/chat/data/chat_signalr_client.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/client_data_change.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/console_live_updates.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/trainer_licence_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/workout_builder_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/client_detail_screen.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/trainer_console_home.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/trainer_console_shell.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

import '../chat/fakes.dart';
import 'fakes.dart';
import 'licence_fakes.dart';

/// Part four of the sync rework, the console's half: the server says a
/// client's data changed (`ClientDataChanged`, on the chat socket), and the
/// console reads again what it shows — debounced, without taking it off
/// screen, and also on focus and reconnect, since an event can be missed.
/// See `docs/sync-architecture.md`, part four.
///
/// Each test was run with the one rule it pins taken out, and failed there.

/// Stands in for the hub: a test says "client X's nutrition changed" or "the
/// socket came back" with one line.
class _Hub {
  final _changes = StreamController<ClientDataChange>.broadcast();
  final _reconnects = StreamController<void>.broadcast();

  late final ConsoleLiveUpdates live = ConsoleLiveUpdates(
    changes: _changes.stream,
    reconnected: _reconnects.stream,
  );

  void changed(String clientId, Set<ClientDataArea> areas) =>
      _changes.add(ClientDataChange(clientId: clientId, areas: areas));

  void reconnected() => _reconnects.add(null);

  /// Unmounts the console and stops every timer, so none is left pending
  /// when the test ends. The console doesn't dispose an injected one.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    live.dispose();
    unawaited(_changes.close());
    unawaited(_reconnects.close());
  }
}

Future<_Hub> _pump(
  WidgetTester tester,
  FakeTrainerConsoleRepository repository, {
  TrainerConsoleRoute initialRoute = TrainerConsoleRoute.nutrition,
}) async {
  tester.view.physicalSize = const Size(1400, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final db = newTestDatabase();
  final signalR = FakeChatSignalRClient();
  addTearDown(() async {
    await signalR.dispose();
    await db.close();
  });

  final hub = _Hub();
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TrainerConsoleHome(
        repository: repository,
        initialRoute: initialRoute,
        liveUpdates: hub.live,
        licenceProvider: TrainerLicenceProvider(
          repository: FakeTrainerLicenceRepository(current: licence()),
        ),
        chatRepository: ChatRepository(
          db: db,
          api: FakeChatApi(),
          signalR: signalR,
          crypto: FakeChatCrypto(),
          attachmentSender: FakeChatAttachmentSender(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return hub;
}

FakeTrainerConsoleRepository _repository() => FakeTrainerConsoleRepository(
  rosterWithStats: [
    fakeRosterEntry(),
    fakeRosterEntry(id: 'client-2', name: 'Ana Silva'),
  ],
  nutrition: fakeNutrition(totalCalories: 1850, goal: 2200),
);

Finder _ring(int eaten) =>
    find.bySemanticsLabel('$eaten of 2200 kcal, ${2200 - eaten} remaining');

void main() {
  group('an event', () {
    testWidgets('for the active client refetches its pane once for a burst', (
      tester,
    ) async {
      final repository = _repository();
      final hub = await _pump(tester, repository);
      expect(repository.calls['nutrition'], 1);
      expect(repository.calls['roster'], 1);

      // One push from a phone is several requests, each its own event.
      repository.nutrition = fakeNutrition(totalCalories: 2050, goal: 2200);
      for (var i = 0; i < 5; i++) {
        hub.changed('client-1', {ClientDataArea.nutrition});
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(repository.calls['nutrition'], 1, reason: 'still in the burst');

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(repository.calls['nutrition'], 2);
      expect(_ring(2050), findsOneWidget);

      // The roster summarises every client, so it reads again too, later.
      await tester.pump(const Duration(seconds: 3));
      expect(repository.calls['nutrition'], 2);
      expect(repository.calls['roster'], 2);

      await hub.close(tester);
    });

    testWidgets('in a steady stream still refetches, within a ceiling', (
      tester,
    ) async {
      final repository = _repository();
      final hub = await _pump(tester, repository);

      // A trainer with clients mid-session: an event every half second, from
      // this client and others, and never a quiet second for the debounce.
      repository.nutrition = fakeNutrition(totalCalories: 2050, goal: 2200);
      Future<void> stream(int events) async {
        for (var i = 0; i < events; i++) {
          hub.changed(
            i.isEven ? 'client-1' : 'client-2',
            {ClientDataArea.nutrition},
          );
          await tester.pump(const Duration(milliseconds: 500));
        }
      }

      await stream(12);
      expect(
        repository.calls['nutrition'],
        2,
        reason: 'the pane reads within five seconds of the first event',
      );
      expect(_ring(2050), findsOneWidget);
      expect(repository.calls['roster'], 1, reason: 'still inside its ceiling');

      await stream(20);
      expect(
        repository.calls['roster'],
        2,
        reason: 'the roster reads within fifteen seconds of the first event',
      );

      await hub.close(tester);
    });

    testWidgets('for another client refreshes only the roster', (
      tester,
    ) async {
      final repository = _repository();
      final hub = await _pump(tester, repository);

      hub.changed('client-2', ClientDataArea.values.toSet());
      await tester.pump(const Duration(seconds: 4));

      expect(repository.calls['nutrition'], 1);
      expect(repository.calls['roster'], 2);

      await hub.close(tester);
    });

    testWidgets('for an area the pane does not show leaves it alone', (
      tester,
    ) async {
      final repository = _repository();
      final hub = await _pump(tester, repository);

      hub.changed('client-1', {ClientDataArea.weight});
      await tester.pump(const Duration(seconds: 4));

      expect(repository.calls['nutrition'], 1);
      expect(repository.calls['roster'], 2);

      await hub.close(tester);
    });

    testWidgets('for a section nobody is looking at waits until it is shown', (
      tester,
    ) async {
      final repository = _repository();
      final hub = await _pump(tester, repository);

      // Nutrition stays mounted behind Session Review, not visible.
      await tester.tap(find.text('Session Review').first);
      await tester.pumpAndSettle();

      hub.changed('client-1', {ClientDataArea.nutrition});
      await tester.pump(const Duration(seconds: 4));
      expect(repository.calls['nutrition'], 1);

      await tester.tap(find.text('Nutrition').first);
      await tester.pumpAndSettle();
      expect(repository.calls['nutrition'], 2);

      await hub.close(tester);
    });

    testWidgets('refetches a client detail opened from the roster', (
      tester,
    ) async {
      final repository = _repository();
      final hub = await _pump(
        tester,
        repository,
        initialRoute: TrainerConsoleRoute.dashboard,
      );

      // A pushed route is outside the console's providers; it only hears the
      // event because the console hands its source across.
      await tester.tap(find.text('Robert Meyer').first);
      await tester.pumpAndSettle();
      expect(find.byType(ClientDetailScreen), findsOneWidget);
      expect(repository.calls['weightHistory'], 1);

      hub.changed('client-1', {ClientDataArea.weight});
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(repository.calls['weightHistory'], 2);

      await hub.close(tester);
    });
  });

  group('a refresh', () {
    testWidgets('keeps what is shown on screen while it reads', (
      tester,
    ) async {
      final repository = _repository();
      final hub = await _pump(tester, repository);

      final held = Completer<void>();
      repository.gate = held;
      repository.nutrition = fakeNutrition(totalCalories: 2050, goal: 2200);
      hub.changed('client-1', {ClientDataArea.nutrition});
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(repository.calls['nutrition'], 2, reason: 'the read is in flight');

      expect(find.byType(LoadingSkeleton), findsNothing);
      expect(_ring(1850), findsOneWidget);

      held.complete();
      await tester.pumpAndSettle();
      expect(_ring(2050), findsOneWidget);

      await hub.close(tester);
    });

    testWidgets('that fails keeps what is shown instead of an error', (
      tester,
    ) async {
      final repository = _repository();
      final hub = await _pump(tester, repository);

      repository
        ..throwOnNutrition = true
        ..throwOnRoster = true;
      hub.changed('client-1', {ClientDataArea.nutrition});
      await tester.pump(const Duration(seconds: 4));
      expect(repository.calls['nutrition'], 2);
      expect(repository.calls['roster'], 2);

      // Neither the pane's own failure nor the roster's — which every
      // client-scoped pane turns into a full-page error — replaces it. The
      // pane says it couldn't refresh instead (see below).
      expect(find.byType(ErrorStateView), findsNothing);
      expect(find.byType(LoadingSkeleton), findsNothing);
      expect(_ring(1850), findsOneWidget);

      await hub.close(tester);
    });
  });

  group('a refresh that fails says so, and Retry reads again,', () {
    final notice = find.text("Couldn't refresh");
    final retry = find.widgetWithText(TextButton, 'Retry');

    /// Fails the next refresh of what [route] shows, checks the pane keeps
    /// it and says so, then lets Retry read it again and checks the notice
    /// goes. [shown] finds something of the data on screen.
    Future<void> failThenRetry(
      WidgetTester tester, {
      required FakeTrainerConsoleRepository repository,
      required TrainerConsoleRoute route,
      required Set<ClientDataArea> areas,
      required void Function(bool failing) failing,
      required String read,
      required Finder shown,
      Future<void> Function()? open,
    }) async {
      final hub = await _pump(tester, repository, initialRoute: route);
      await open?.call();
      expect(notice, findsNothing);

      failing(true);
      hub.changed('client-1', areas);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      final reads = repository.calls[read];

      expect(notice, findsOneWidget);
      expect(find.byType(ErrorStateView), findsNothing);
      expect(shown, findsWidgets, reason: 'what was shown stays up');

      failing(false);
      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(repository.calls[read], reads! + 1);
      expect(notice, findsNothing);
      expect(shown, findsWidgets);

      await hub.close(tester);
    }

    testWidgets('on Nutrition', (tester) async {
      final repository = _repository();
      await failThenRetry(
        tester,
        repository: repository,
        route: TrainerConsoleRoute.nutrition,
        areas: {ClientDataArea.nutrition},
        failing: (on) => repository.throwOnNutrition = on,
        read: 'nutrition',
        shown: _ring(1850),
      );
    });

    testWidgets('on Session Review', (tester) async {
      final repository = FakeTrainerConsoleRepository(
        rosterWithStats: [fakeRosterEntry()],
        sessions: [fakeSession()],
      );
      await failThenRetry(
        tester,
        repository: repository,
        route: TrainerConsoleRoute.sessionReview,
        areas: {ClientDataArea.sessions},
        failing: (on) => repository.throwOnSessions = on,
        read: 'sessions',
        shown: find.text(fakeSession().workoutName),
      );
    });

    testWidgets('on the Workout Builder', (tester) async {
      final repository = FakeTrainerConsoleRepository(
        rosterWithStats: [fakeRosterEntry()],
        workoutSummary: ClientWorkoutSummary(
          currentPlan: WorkoutPlanSummary(
            id: 'plan-1',
            name: 'Push / Pull / Legs',
            isActive: true,
            startDate: DateTime(2026, 7, 1),
          ),
          attendance: const [],
          strengthProgression: const [],
        ),
        clientWorkouts: const [
          ClientWorkout(
            id: 'workout-1',
            name: 'Push Day',
            difficulty: 1,
            estimatedDurationMinutes: 60,
            planIds: ['plan-1'],
            exercises: [],
          ),
        ],
      );
      await failThenRetry(
        tester,
        repository: repository,
        route: TrainerConsoleRoute.builder,
        areas: {ClientDataArea.workouts},
        failing: (on) => repository.throwOnClientWorkouts = on,
        read: 'clientWorkouts',
        shown: find.text('Push / Pull / Legs'),
      );
    });

    testWidgets('on the Dashboard, for the roster', (tester) async {
      final repository = _repository();
      await failThenRetry(
        tester,
        repository: repository,
        route: TrainerConsoleRoute.dashboard,
        areas: {ClientDataArea.weight},
        failing: (on) => repository.throwOnRoster = on,
        read: 'roster',
        shown: find.text('Ana Silva'),
      );
    });

    testWidgets('on the Dashboard, for the KPIs', (tester) async {
      final repository = FakeTrainerConsoleRepository(
        rosterWithStats: [fakeRosterEntry()],
        kpis: const TrainerDashboardKpis(
          activeClientCount: 7,
          avgAdherencePercent: 86,
          sessionsThisWeek: 19,
          alertCount: 0,
        ),
      );
      await failThenRetry(
        tester,
        repository: repository,
        route: TrainerConsoleRoute.dashboard,
        areas: {ClientDataArea.sessions},
        failing: (on) => repository.throwOnDashboard = on,
        read: 'kpis',
        shown: find.text('19'),
      );
    });

    testWidgets('on Client Detail', (tester) async {
      final repository = _repository();
      await failThenRetry(
        tester,
        repository: repository,
        route: TrainerConsoleRoute.dashboard,
        open: () async {
          await tester.tap(find.text('Robert Meyer').first);
          await tester.pumpAndSettle();
        },
        areas: {ClientDataArea.nutrition},
        failing: (on) => repository.throwOnNutrition = on,
        read: 'nutrition',
        shown: find.byType(ClientDetailScreen),
      );
    });
  });

  group('the fallback', () {
    testWidgets('refetches when the window comes back into focus', (
      tester,
    ) async {
      final repository = _repository();
      final hub = await _pump(tester, repository);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 4));

      expect(repository.calls['nutrition'], 2);
      expect(repository.calls['roster'], 2);

      await hub.close(tester);
    });

    testWidgets('refetches on focus at most once a cooldown', (tester) async {
      final repository = _repository();
      final hub = await _pump(tester, repository);

      // Alt-tabbing: five returns to the window, two seconds apart.
      for (var i = 0; i < 5; i++) {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump(const Duration(seconds: 2));
      }
      expect(repository.calls['nutrition'], 2);
      expect(repository.calls['roster'], 2);

      // Once more when the cooldown is over, for the last return inside it.
      await tester.pump(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 4));
      expect(repository.calls['nutrition'], 3);
      expect(repository.calls['roster'], 3);

      await hub.close(tester);
    });

    testWidgets('shares one cooldown between focus and reconnect', (
      tester,
    ) async {
      final repository = _repository();
      final hub = await _pump(tester, repository);

      hub.reconnected();
      await tester.pump(const Duration(seconds: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 4));

      expect(repository.calls['nutrition'], 2);
      expect(repository.calls['roster'], 2);

      await tester.pump(const Duration(seconds: 30));
      await hub.close(tester);
    });

    testWidgets('refetches when the socket comes back, at most once a cooldown', (
      tester,
    ) async {
      final repository = _repository();
      final hub = await _pump(tester, repository);

      // A socket that keeps dropping: five reconnects, two seconds apart.
      for (var i = 0; i < 5; i++) {
        hub.reconnected();
        await tester.pump(const Duration(seconds: 2));
      }
      expect(repository.calls['nutrition'], 2);

      // One more once the cooldown is over, for whatever the later drops
      // missed — and then nothing.
      await tester.pump(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 4));
      expect(repository.calls['nutrition'], 3);

      await hub.close(tester);
    });
  });

  group('reconnects', () {
    test('are a connection coming back, not the first connect', () async {
      final status = StreamController<ChatConnectionStatus>();
      final seen = <void>[];
      final subscription =
          ConsoleLiveUpdates.reconnectsOf(status.stream).listen(seen.add);

      status.add(ChatConnectionStatus.connected);
      await Future<void>.delayed(Duration.zero);
      expect(seen, isEmpty, reason: 'the first connect');

      status
        ..add(ChatConnectionStatus.reconnecting)
        ..add(ChatConnectionStatus.connected);
      await Future<void>.delayed(Duration.zero);
      expect(seen, hasLength(1), reason: 'an automatic reconnect');

      // Given up, then started afresh by the next chat call.
      status
        ..add(ChatConnectionStatus.disconnected)
        ..add(ChatConnectionStatus.connected);
      await Future<void>.delayed(Duration.zero);
      expect(seen, hasLength(2), reason: 'a fresh start after a close');

      await subscription.cancel();
      await status.close();
    });
  });

  group('the event', () {
    test('drops an area this build does not know, and keeps the rest', () {
      final change = ClientDataChange.tryParse({
        'clientId': 'client-1',
        'areas': ['nutrition', 'measurements', 'weight'],
      });

      expect(change?.clientId, 'client-1');
      expect(change?.areas, {ClientDataArea.nutrition, ClientDataArea.weight});
    });

    test('with no client to attribute it to is ignored', () {
      expect(ClientDataChange.tryParse({'areas': ['nutrition']}), isNull);
      expect(ClientDataChange.tryParse('client-1'), isNull);
    });
  });

  group('the Workout Builder', () {
    ClientWorkout pushDay(String name) => ClientWorkout(
      id: 'workout-1',
      name: name,
      difficulty: 1,
      estimatedDurationMinutes: 60,
      planIds: const ['plan-1'],
      exercises: const [],
    );

    FakeTrainerConsoleRepository repositoryWith(ClientWorkout workout) =>
        FakeTrainerConsoleRepository(
          rosterWithStats: [fakeRosterEntry()],
          workoutSummary: ClientWorkoutSummary(
            currentPlan: WorkoutPlanSummary(
              id: 'plan-1',
              name: 'Push / Pull / Legs',
              isActive: true,
              startDate: DateTime(2026, 7, 1),
            ),
            attendance: const [],
            strengthProgression: const [],
          ),
          clientWorkouts: [workout],
        );

    void serverNowHolds(
      FakeTrainerConsoleRepository repository,
      ClientWorkout workout,
    ) {
      repository.clientWorkouts
        ..clear()
        ..add(workout);
    }

    test('gives a clean open day the server copy', () async {
      final repository = repositoryWith(pushDay('Push Day'));
      final builder = WorkoutBuilderProvider(repository: repository);
      await builder.load('client-1');
      expect(builder.draft?.name, 'Push Day');

      serverNowHolds(repository, pushDay('Push Day A'));
      await builder.refresh('client-1');

      expect(builder.draft?.name, 'Push Day A');
      expect(builder.isDraftDirty, isFalse);
      // So the editor rebuilds its fields from the new copy.
      expect(builder.draftRevision, 1);
    });

    test('never overwrites a day with unsaved edits', () async {
      final repository = repositoryWith(pushDay('Push Day'));
      final builder = WorkoutBuilderProvider(repository: repository);
      await builder.load('client-1');
      builder.updateDayName('Push Day (heavy)');

      serverNowHolds(repository, pushDay('Push Day A'));
      await builder.refresh('client-1');

      expect(builder.draft?.name, 'Push Day (heavy)');
      expect(builder.isDraftDirty, isTrue);
      expect(builder.draftRevision, 0);
      // The rest of the pane still moves on around it.
      expect(builder.planWorkouts.single.name, 'Push Day A');
    });
  });
}
