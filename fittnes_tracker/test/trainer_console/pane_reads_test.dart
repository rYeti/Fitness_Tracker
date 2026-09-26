import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/active_client_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/client_detail_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/nutrition_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/pane_reads.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/session_review_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/trainer_console_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/workout_builder_provider.dart';

import 'fakes.dart';

/// The one "latest read wins, keep what's shown" rule every console pane
/// reads through, and the failed refresh it now reports instead of hiding.
/// `docs/sync-architecture.md` §52.
///
/// Each test was run with the rule it pins taken out, and failed there.
void main() {
  group('PaneReads', () {
    test('applies only the latest read', () {
      final reads = PaneReads();
      final older = reads.start();
      final newer = reads.start();

      expect(newer.settle(), isTrue);
      expect(older.settle(), isFalse);
      expect(reads.isLoading, isFalse);
    });

    test('makes a refresh during a load a load of its own', () {
      final reads = PaneReads();
      reads.start();

      final refresh = reads.start(keepShown: true);

      expect(refresh.isLoad, isTrue);
      expect(reads.isLoading, isTrue);
    });

    test('makes a refresh with nothing of its own on screen a load', () {
      final reads = PaneReads();
      reads.start().settle();

      expect(reads.start(keepShown: true, shown: false).isLoad, isTrue);
    });

    test('marks a failed refresh, and clears it on the next success', () {
      final reads = PaneReads();
      reads.start().settle();

      final refresh = reads.start(keepShown: true);
      expect(refresh.keep, isTrue);
      expect(reads.isLoading, isFalse, reason: 'a refresh shows no skeleton');
      refresh.settle(failed: true);
      expect(reads.refreshFailed, isTrue);

      reads.start(keepShown: true).settle();
      expect(reads.refreshFailed, isFalse);
    });

    test('clears a failed refresh as soon as a load starts', () {
      final reads = PaneReads();
      reads.start().settle();
      reads.start(keepShown: true).settle(failed: true);

      reads.start(keepShown: true, shown: false);

      expect(
        reads.refreshFailed,
        isFalse,
        reason: 'another client or day is loading, not the one that failed',
      );
    });

    test('leaves a failed load to the pane\'s own error', () {
      final reads = PaneReads();

      expect(reads.start().settle(failed: true), isTrue);
      expect(reads.refreshFailed, isFalse);
    });

    test('drops a refresh a write overlapped, and owes it once the write settles', () async {
      var owed = 0;
      final reads = PaneReads(onRefreshOwed: () => owed++);
      reads.start().settle();

      final refresh = reads.start(keepShown: true);
      await reads.write(() async {
        expect(refresh.settle(), isFalse, reason: 'from before the write');
        expect(owed, 0, reason: 'not while the write is in flight');
      });

      expect(owed, 1);
    });

    test('owes a refresh asked for during a write', () async {
      var owed = 0;
      final reads = PaneReads(onRefreshOwed: () => owed++);
      reads.start().settle();

      late PaneRead refresh;
      await reads.write(() async {
        refresh = reads.start(keepShown: true);
      });
      expect(refresh.settle(), isFalse, reason: 'it read during the write');

      expect(owed, 1);
    });

    test('says whether a write is still in flight', () async {
      final reads = PaneReads();
      final first = Completer<void>();
      final second = Completer<void>();

      final writing = reads.write(() => first.future);
      final alsoWriting = reads.write(() => second.future);
      expect(reads.isWriting, isTrue);

      first.complete();
      await writing;
      expect(reads.isWriting, isTrue, reason: 'the second is in flight');

      second.complete();
      await alsoWriting;
      expect(reads.isWriting, isFalse);
    });

    test('tells a load a write overlapped it, and one that did not', () async {
      final reads = PaneReads();

      final before = reads.start();
      expect(before.settle(), isTrue);
      expect(before.overlappedWrite, isFalse);

      final across = reads.start();
      await reads.write(() async {});
      expect(across.settle(), isTrue, reason: 'a load is still applied');
      expect(across.overlappedWrite, isTrue);

      late PaneRead during;
      await reads.write(() async => during = reads.start());
      expect(during.settle(), isTrue);
      expect(during.overlappedWrite, isTrue);

      final after = reads.start();
      expect(after.settle(), isTrue);
      expect(after.overlappedWrite, isFalse);
    });

    test('lets a load run across a write', () async {
      final reads = PaneReads(onRefreshOwed: () => fail('nothing is owed'));

      final load = reads.start();
      await reads.write(() async {});

      expect(load.settle(), isTrue);
    });
  });

  group('a failed refresh is said, not hidden, by', () {
    FakeTrainerConsoleRepository repository() => FakeTrainerConsoleRepository(
      rosterWithStats: [fakeRosterEntry()],
      sessions: [fakeSession()],
      nutrition: fakeNutrition(),
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

    test('the roster', () async {
      final server = repository();
      final roster = ActiveClientProvider(repository: server);
      await roster.loadClients();

      server.throwOnRoster = true;
      await roster.loadClients(keepShown: true);
      expect(roster.refreshFailed, isTrue);
      expect(roster.error, isNull);
      expect(roster.clients, isNotEmpty);

      server.throwOnRoster = false;
      await roster.loadClients(keepShown: true);
      expect(roster.refreshFailed, isFalse);
    });

    test('the KPIs', () async {
      final server = repository();
      final kpis = TrainerConsoleProvider(repository: server);
      await kpis.load();

      server.throwOnDashboard = true;
      await kpis.load(keepShown: true);
      expect(kpis.refreshFailed, isTrue);
      expect(kpis.error, isNull);
      expect(kpis.kpis, isNotNull);

      server.throwOnDashboard = false;
      await kpis.load(keepShown: true);
      expect(kpis.refreshFailed, isFalse);
    });

    test('Session Review', () async {
      final server = repository();
      final review = SessionReviewProvider(repository: server);
      await review.load('client-1');

      server.throwOnSessions = true;
      await review.load('client-1', keepShown: true);
      expect(review.refreshFailed, isTrue);
      expect(review.error, isNull);
      expect(review.sessions, isNotEmpty);

      server.throwOnSessions = false;
      await review.load('client-1', keepShown: true);
      expect(review.refreshFailed, isFalse);
    });

    test('Nutrition', () async {
      final server = repository();
      final nutrition = NutritionProvider(repository: server);
      await nutrition.load('client-1');

      server.throwOnNutrition = true;
      await nutrition.load('client-1', keepShown: true);
      expect(nutrition.refreshFailed, isTrue);
      expect(nutrition.error, isNull);
      expect(nutrition.summary, isNotNull);

      server.throwOnNutrition = false;
      await nutrition.load('client-1', keepShown: true);
      expect(nutrition.refreshFailed, isFalse);
    });

    test('Client Detail, for any one section', () async {
      final server = repository();
      final detail = ClientDetailProvider(
        clientId: 'client-1',
        repository: server,
      );
      await detail.load();

      server.throwOnNutrition = true;
      await detail.load(keepShown: true);
      expect(detail.refreshFailed, isTrue);
      expect(detail.error, isNull);
      expect(detail.nutrition, isNotNull);

      server.throwOnNutrition = false;
      await detail.load(keepShown: true);
      expect(detail.refreshFailed, isFalse);
    });

    test('the Workout Builder', () async {
      final server = repository();
      final builder = WorkoutBuilderProvider(repository: server);
      await builder.load('client-1');

      server.throwOnClientWorkouts = true;
      await builder.refresh('client-1');
      expect(builder.refreshFailed, isTrue);
      expect(builder.error, isNull);
      expect(builder.draft?.name, 'Push Day');

      server.throwOnClientWorkouts = false;
      await builder.refresh('client-1');
      expect(builder.refreshFailed, isFalse);
    });

    test('nobody while the pane shows its own error', () async {
      final server = repository()..throwOnSessions = true;
      final review = SessionReviewProvider(repository: server);
      await review.load('client-1');
      expect(review.error, isNotNull);

      await review.load('client-1', keepShown: true);
      expect(
        review.refreshFailed,
        isFalse,
        reason: 'the error state already has its retry',
      );
    });
  });

  group('a refresh that reads everything', () {
    test('clears the error of a Client Detail whose first load failed a section', () async {
      final server = FakeTrainerConsoleRepository(nutrition: fakeNutrition())
        ..throwOnNutrition = true;
      final detail = ClientDetailProvider(
        clientId: 'client-1',
        repository: server,
      );
      await detail.load();
      expect(detail.error, isNotNull, reason: 'one section failed to load');

      server.throwOnNutrition = false;
      await detail.load(keepShown: true);
      expect(detail.error, isNull);
      expect(detail.nutrition, isNotNull);
    });
  });
}
