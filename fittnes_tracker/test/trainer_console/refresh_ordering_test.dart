import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/nutrition_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/workout_builder_provider.dart';

import 'fakes.dart';

/// A refresh against a pane that also loads and writes: which answer wins,
/// what a changed plan does to the Workout Builder, and what a day switch
/// does to a pin still being saved. `docs/sync-architecture.md` §52–§53.
///
/// Every test here uses only what the providers exposed before the fixes,
/// and each was run against the code before them and failed there — except
/// the three that say they held before too.

/// Answers a held read with what the server held when the request arrived,
/// once released: a read whose answer is still on its way back when a later
/// change is committed.
class _HeldRepository extends FakeTrainerConsoleRepository {
  _HeldRepository({
    super.workoutSummary,
    super.clientWorkouts,
    super.saveWorkoutFailure,
  });

  /// Holds each workouts read from now on, until [release]d.
  bool holdWorkouts = false;
  final _held = <Completer<void>>[];

  /// Holds each workout save from now on, until completed.
  Completer<void>? saveGate;

  void release(int read) => _held[read].complete();

  /// What the server holds from now on.
  void serverHolds(List<ClientWorkout> workouts) {
    clientWorkouts
      ..clear()
      ..addAll(workouts);
  }

  @override
  Future<List<ClientWorkout>> getClientWorkouts(String clientId) async {
    final atArrival = List.of(await super.getClientWorkouts(clientId));
    if (holdWorkouts) {
      final held = Completer<void>();
      _held.add(held);
      await held.future;
    }
    return atArrival;
  }

  @override
  Future<ClientWorkout> updateClientWorkout(
    String clientId,
    String workoutId, {
    required String name,
    String? description,
    required int difficulty,
    required int estimatedDurationMinutes,
    required List<ClientWorkoutExerciseDraft> exercises,
  }) async {
    await saveGate?.future;
    return super.updateClientWorkout(
      clientId,
      workoutId,
      name: name,
      description: description,
      difficulty: difficulty,
      estimatedDurationMinutes: estimatedDurationMinutes,
      exercises: exercises,
    );
  }
}

WorkoutPlanSummary _plan(String id) => WorkoutPlanSummary(
  id: id,
  name: id == 'plan-1' ? 'Push / Pull / Legs' : 'Upper / Lower',
  isActive: true,
  startDate: DateTime(2026, 7, 1),
);

ClientWorkoutSummary _summaryWith(String? planId) => ClientWorkoutSummary(
  currentPlan: planId == null ? null : _plan(planId),
  attendance: const [],
  strengthProgression: const [],
);

ClientWorkout _day(
  String name, {
  String id = 'workout-1',
  String planId = 'plan-1',
}) => ClientWorkout(
  id: id,
  name: name,
  difficulty: 1,
  estimatedDurationMinutes: 60,
  planIds: [planId],
  exercises: const [],
);

/// Lets every answer that isn't held arrive, and whatever it starts run.
Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Holds each pin write until the test settles it, one by one.
class _PinWrites extends FakeTrainerConsoleRepository {
  _PinWrites() : super(nutrition: fakeNutrition(micronutrientsLocked: false));

  final writes = <Completer<void>>[];

  @override
  Future<void> setClientNutrientPins(
    String clientId,
    List<String> nutrientKeys,
  ) {
    final write = Completer<void>();
    writes.add(write);
    return write.future;
  }
}

void main() {
  group('the Workout Builder orders its reads', () {
    test('two refreshes in flight: the later answer stands', () async {
      final repository = _HeldRepository(
        workoutSummary: _summaryWith('plan-1'),
        clientWorkouts: [_day('Push Day')],
      );
      final builder = WorkoutBuilderProvider(repository: repository);
      await builder.load('client-1');
      repository.holdWorkouts = true;

      repository.serverHolds([_day('Push Day A')]);
      final first = builder.refresh('client-1');
      await _settle();
      repository.serverHolds([_day('Push Day B')]);
      final second = builder.refresh('client-1');
      await _settle();

      repository.release(1);
      await second;
      expect(builder.draft?.name, 'Push Day B');

      // The older answer arrives last — a slow link, a cold instance — and
      // must not put the older day back.
      repository.release(0);
      await first;
      await _settle();
      expect(builder.draft?.name, 'Push Day B');
      expect(builder.planWorkouts.single.name, 'Push Day B');
    });

    test('a refresh during a read reads again instead of being dropped', () async {
      final repository = _HeldRepository(
        workoutSummary: _summaryWith('plan-1'),
        clientWorkouts: [_day('Push Day')],
      );
      final builder = WorkoutBuilderProvider(repository: repository);
      repository.holdWorkouts = true;
      final loading = builder.load('client-1');
      await _settle();
      expect(builder.isLoadingDays, isTrue, reason: 'the days read is held');

      // The server has answered that read; the client's phone then commits a
      // change, and its event arrives while the answer is still on its way.
      repository
        ..serverHolds([_day('Push Day A')])
        ..holdWorkouts = false;
      final refreshing = builder.refresh('client-1');
      repository.release(0);
      await loading;
      await refreshing;
      await _settle();

      expect(builder.draft?.name, 'Push Day A');
      expect(builder.isLoadingDays, isFalse);
    });

    // Held before the fixes too, by the epoch every write bumped by hand; it
    // is here because that rule now lives in PaneReads.write instead.
    test('a refresh that started before a save never puts the old day back', () async {
      final repository = _HeldRepository(
        workoutSummary: _summaryWith('plan-1'),
        clientWorkouts: [_day('Push Day')],
      );
      final builder = WorkoutBuilderProvider(repository: repository);
      await builder.load('client-1');

      repository.holdWorkouts = true;
      final refreshing = builder.refresh('client-1');
      await _settle();
      repository.holdWorkouts = false;
      builder.updateDayName('Push Day (heavy)');
      expect(await builder.saveDraft('client-1'), isTrue);

      repository.release(0);
      await refreshing;
      await _settle();

      expect(builder.draft?.name, 'Push Day (heavy)');
      expect(builder.isDraftDirty, isFalse);
    });

    test('a refresh a failed save overlapped is read again after it', () async {
      final repository = _HeldRepository(
        workoutSummary: _summaryWith('plan-1'),
        clientWorkouts: [
          _day('Push Day'),
          _day('Pull Day', id: 'workout-2'),
        ],
        saveWorkoutFailure: const WorkoutSaveException(
          WorkoutSaveFailure.other,
        ),
      );
      final builder = WorkoutBuilderProvider(repository: repository);
      await builder.load('client-1');
      builder.updateDayName('Push Day (heavy)');

      // The client renames their other day, and the refresh that brings it
      // is still reading when the trainer's save goes out — and fails, so no
      // event of its own follows.
      repository
        ..serverHolds([_day('Push Day'), _day('Pull Day B', id: 'workout-2')])
        ..holdWorkouts = true;
      final refreshing = builder.refresh('client-1');
      await _settle();
      expect(await builder.saveDraft('client-1'), isFalse);

      repository.holdWorkouts = false;
      repository.release(0);
      await refreshing;
      await _settle();

      expect(builder.planWorkouts.map((w) => w.name), contains('Pull Day B'));
      expect(builder.draft?.name, 'Push Day (heavy)', reason: 'still theirs');
    });

    test('a refresh asked for during a save runs once the save settles', () async {
      final repository = _HeldRepository(
        workoutSummary: _summaryWith('plan-1'),
        clientWorkouts: [
          _day('Push Day'),
          _day('Pull Day', id: 'workout-2'),
        ],
      );
      final builder = WorkoutBuilderProvider(repository: repository);
      await builder.load('client-1');
      builder.updateDayName('Push Day (heavy)');

      final save = Completer<void>();
      repository.saveGate = save;
      final saving = builder.saveDraft('client-1');
      await _settle();
      repository.serverHolds([
        _day('Push Day'),
        _day('Pull Day B', id: 'workout-2'),
      ]);
      await builder.refresh('client-1');

      save.complete();
      expect(await saving, isTrue);
      await _settle();

      expect(
        builder.planWorkouts.map((w) => w.name),
        containsAll(['Push Day (heavy)', 'Pull Day B']),
      );
      expect(builder.isDraftDirty, isFalse);
    });
  });

  group('a refresh that overtakes a days read', () {
    test('keeps a day with unsaved edits, and shows no skeleton', () async {
      final repository = _HeldRepository(
        workoutSummary: _summaryWith('plan-1'),
        clientWorkouts: [_day('Push Day')],
      );
      final builder = WorkoutBuilderProvider(repository: repository);
      await builder.load('client-1');
      builder.updateDayName('Push Day (heavy)');

      // New plan, with the edited day still open. The new plan's days are
      // still loading when the refresh its own event brings arrives.
      builder.startNewPlan();
      repository.holdWorkouts = true;
      expect(
        await builder.createPlan(clientId: 'client-1', name: 'Upper / Lower'),
        isTrue,
      );
      await _settle();
      expect(builder.isLoadingDays, isTrue);
      repository.workoutSummary = _summaryWith('plan-new');
      final refreshing = builder.refresh('client-1');
      await _settle();

      expect(builder.draft?.name, 'Push Day (heavy)');
      expect(builder.isDraftDirty, isTrue);
      expect(builder.isLoading, isFalse, reason: 'no whole-builder skeleton');
      expect(builder.currentPlan?.id, 'plan-new');

      repository
        ..release(0)
        ..release(1);
      await refreshing;
      await _settle();

      expect(builder.draft?.name, 'Push Day (heavy)');
      expect(builder.isDraftDirty, isTrue);
      expect(builder.isLoadingDays, isFalse);
      expect(builder.currentPlan?.id, 'plan-new');
    });

    test('lands on the first day, as the days read would have', () async {
      final repository = _HeldRepository(
        workoutSummary: _summaryWith(null),
        clientWorkouts: [_day('Upper', planId: 'plan-new')],
      );
      final builder = WorkoutBuilderProvider(repository: repository);
      await builder.load('client-1');

      repository.holdWorkouts = true;
      await builder.createPlan(clientId: 'client-1', name: 'Upper / Lower');
      await _settle();
      repository
        ..workoutSummary = _summaryWith('plan-new')
        ..holdWorkouts = false;
      await builder.refresh('client-1');
      repository.release(0);
      await _settle();

      expect(builder.isLoadingDays, isFalse);
      expect(builder.draft?.name, 'Upper');
    });

    test('fails the way the days read would have', () async {
      final repository = _HeldRepository(
        workoutSummary: _summaryWith(null),
        clientWorkouts: [_day('Upper', planId: 'plan-new')],
      );
      final builder = WorkoutBuilderProvider(repository: repository);
      await builder.load('client-1');

      repository.holdWorkouts = true;
      await builder.createPlan(clientId: 'client-1', name: 'Upper / Lower');
      await _settle();
      repository
        ..holdWorkouts = false
        ..throwOnClientWorkouts = true;
      await builder.refresh('client-1');
      repository.release(0);
      await _settle();

      // Not a skeleton that never ends.
      expect(builder.isLoadingDays, isFalse);
      expect(builder.daysError, isNotNull);
    });
  });

  group('the Workout Builder follows a plan that changed elsewhere', () {
    test('a plan that appears ends the create flow, as a load would', () async {
      final repository = FakeTrainerConsoleRepository(
        workoutSummary: _summaryWith(null),
        clientWorkouts: [_day('Push Day')],
      );
      final builder = WorkoutBuilderProvider(repository: repository);
      await builder.load('client-1');
      expect(builder.isNew, isTrue, reason: 'no plan: the create flow');

      repository.workoutSummary = _summaryWith('plan-1');
      await builder.refresh('client-1');

      expect(builder.isNew, isFalse);
      expect(builder.currentPlan?.id, 'plan-1');
      expect(builder.draft?.name, 'Push Day', reason: 'on its first day');
    });

    test('a first load that failed recovers on a refresh', () async {
      final repository = FakeTrainerConsoleRepository(
        workoutSummary: _summaryWith('plan-1'),
        clientWorkouts: [_day('Push Day')],
        templates: const [
          WorkoutPlanTemplateSummary(
            id: 'ppl',
            name: 'Push / Pull / Legs',
            description: 'Hypertrophy',
            icon: 'fitness_center',
            daysPerWeek: 4,
          ),
        ],
      )..throwOnWorkoutSummary = true;
      final builder = WorkoutBuilderProvider(repository: repository);
      await builder.load('client-1');
      expect(builder.error, isNotNull);

      repository.throwOnWorkoutSummary = false;
      await builder.refresh('client-1');

      expect(builder.error, isNull);
      expect(builder.templates, isNotEmpty);
      expect(builder.currentPlan?.id, 'plan-1');
      expect(builder.draft?.name, 'Push Day');
    });

    test('days that failed to load recover on a refresh, on the first day', () async {
      final repository = FakeTrainerConsoleRepository(
        workoutSummary: _summaryWith('plan-1'),
        clientWorkouts: [_day('Push Day')],
      )..throwOnClientWorkouts = true;
      final builder = WorkoutBuilderProvider(repository: repository);
      await builder.load('client-1');
      expect(builder.daysError, isNotNull);

      repository.throwOnClientWorkouts = false;
      await builder.refresh('client-1');

      expect(builder.daysError, isNull);
      expect(builder.draft?.name, 'Push Day', reason: 'where loadDays lands');
    });

    test('a new plan opens a day that is in it', () async {
      final repository = FakeTrainerConsoleRepository(
        workoutSummary: _summaryWith('plan-1'),
        clientWorkouts: [
          _day('Push Day'),
          _day('Upper', id: 'workout-2', planId: 'plan-2'),
        ],
      );
      final builder = WorkoutBuilderProvider(repository: repository);
      await builder.load('client-1');
      expect(builder.selectedWorkoutId, 'workout-1');

      repository.workoutSummary = _summaryWith('plan-2');
      await builder.refresh('client-1');

      expect(builder.currentPlan?.id, 'plan-2');
      expect(builder.selectedWorkoutId, 'workout-2');
      expect(builder.draft?.name, 'Upper');
    });

    // The exception, not a regression: it held before the fixes too.
    test('a new plan leaves a day with unsaved edits open', () async {
      final repository = FakeTrainerConsoleRepository(
        workoutSummary: _summaryWith('plan-1'),
        clientWorkouts: [
          _day('Push Day'),
          _day('Upper', id: 'workout-2', planId: 'plan-2'),
        ],
      );
      final builder = WorkoutBuilderProvider(repository: repository);
      await builder.load('client-1');
      builder.updateDayName('Push Day (heavy)');

      repository.workoutSummary = _summaryWith('plan-2');
      await builder.refresh('client-1');

      expect(builder.currentPlan?.id, 'plan-2');
      expect(builder.planWorkouts.single.name, 'Upper');
      expect(builder.draft?.name, 'Push Day (heavy)');
      expect(builder.isDraftDirty, isTrue);
    });

    // Also an exception: the create flow the trainer opened over a plan is
    // theirs, like a draft.
    test('a create flow the trainer opened stays open', () async {
      final repository = FakeTrainerConsoleRepository(
        workoutSummary: _summaryWith('plan-1'),
        clientWorkouts: [_day('Push Day')],
      );
      final builder = WorkoutBuilderProvider(repository: repository);
      await builder.load('client-1');
      builder.startNewPlan();

      await builder.refresh('client-1');

      expect(builder.isNew, isTrue);
    });
  });

  group('a Workout Builder write that answers after a client switch', () {
    // The trainer acts on client A, then switches to client B while the
    // request is still in flight. Whatever A's answer says belongs to A.
    late _HeldRepository repository;
    late WorkoutBuilderProvider builder;
    late Completer<void> write;

    setUp(() async {
      repository = _HeldRepository(
        workoutSummary: _summaryWith('plan-1'),
        clientWorkouts: [_day('Push Day')],
      );
      builder = WorkoutBuilderProvider(repository: repository);
      await builder.load('client-a');
      write = Completer<void>();
      repository.writeGate = write;
    });

    Future<void> switchToClientB() async {
      await _settle();
      await builder.load('client-b');
      expect(builder.loadedClientId, 'client-b');
    }

    test('a plan delete leaves the new client\'s plan alone', () async {
      final deleting = builder.deletePlan('client-a');
      await switchToClientB();

      write.complete();
      expect(await deleting, isFalse, reason: 'nothing changed on screen');

      // Before, B's builder dropped its plan and opened the create flow, and
      // a plan created there would have been B's second.
      expect(repository.deletedPlanIds, ['plan-1'], reason: 'A\'s was sent');
      expect(builder.currentPlan?.id, 'plan-1');
      expect(builder.isNew, isFalse);
      expect(builder.draft?.name, 'Push Day');
    });

    test('a plan delete that fails says nothing on the new client', () async {
      final deleting = builder.deletePlan('client-a');
      await switchToClientB();

      write.completeError(Exception('boom'));
      expect(await deleting, isFalse);

      expect(builder.planError, isNull);
      expect(builder.isDeletingPlan, isFalse);
    });

    test('a saved day stays out of the new client\'s editor', () async {
      builder.updateDayName('Push Day (heavy)');
      final saving = builder.saveDraft('client-a');
      await switchToClientB();

      write.complete();
      expect(await saving, isFalse);

      expect(builder.draft?.name, 'Push Day');
      expect(builder.isDraftDirty, isFalse);
      expect(builder.planWorkouts.map((w) => w.name), ['Push Day']);
      expect(builder.isSavingDay, isFalse);
    });

    test('a created plan reads no days over the new client', () async {
      builder.startNewPlan();
      final creating = builder.createPlan(
        clientId: 'client-a',
        name: 'Upper / Lower',
      );
      await switchToClientB();
      final daysReads = repository.calls['clientWorkouts'];

      write.complete();
      expect(await creating, isFalse);
      await _settle();

      expect(builder.currentPlan?.id, 'plan-1');
      expect(
        repository.calls['clientWorkouts'],
        daysReads,
        reason: 'A\'s days, read as a load over B',
      );
    });

    test('a created exercise stays out of the new client\'s library', () async {
      final creating = builder.createExercise('client-a', name: 'Landmine Press');
      await switchToClientB();

      write.complete();
      expect(await creating, isNull);

      expect(
        builder.exerciseLibrary.map((e) => e.name),
        isNot(contains('Landmine Press')),
      );
    });
  });

  group('a nutrient pin being saved', () {
    NutritionProvider nutritionOf(FakeTrainerConsoleRepository repository) =>
        NutritionProvider(repository: repository);

    FakeTrainerConsoleRepository repositoryWithNoPins() =>
        FakeTrainerConsoleRepository(
          nutrition: fakeNutrition(micronutrientsLocked: false),
        );

    test('stays pinned when the day changes and the read answers after the write', () async {
      final repository = repositoryWithNoPins();
      final nutrition = nutritionOf(repository);
      await nutrition.load('client-1');

      final write = Completer<void>();
      repository.pinGate = write;
      final pinning = nutrition.togglePin('client-1', 'vitaminD');
      expect(nutrition.summary?.pinnedNutrients, ['vitaminD']);

      // The trainer pages to the previous day at once. Its GET is served
      // before the PUT commits, so it carries the old pins.
      final read = Completer<void>();
      repository.gate = read;
      nutrition.previousDay('client-1');
      await _settle();

      write.complete();
      await pinning;
      read.complete();
      await _settle();

      expect(nutrition.summary?.pinnedNutrients, ['vitaminD']);
    });

    test('stays pinned when the day changes and the read answers first', () async {
      final repository = repositoryWithNoPins();
      final nutrition = nutritionOf(repository);
      await nutrition.load('client-1');

      final write = Completer<void>();
      repository.pinGate = write;
      final pinning = nutrition.togglePin('client-1', 'vitaminD');
      nutrition.previousDay('client-1');
      await _settle();

      write.complete();
      await pinning;
      await _settle();

      expect(nutrition.summary?.pinnedNutrients, ['vitaminD']);
    });

    test('a failed write does not undo a later one on screen', () async {
      final repository = _PinWrites();
      final nutrition = nutritionOf(repository);
      await nutrition.load('client-1');

      final first = nutrition.togglePin('client-1', 'vitaminD');
      final second = nutrition.togglePin('client-1', 'iron');
      expect(nutrition.summary?.pinnedNutrients, ['vitaminD', 'iron']);

      // Each write sends the whole set, so the second one's outcome is the
      // one that settles the pins — not the first one's "before".
      repository.writes[0].completeError(Exception('boom'));
      await first;
      expect(nutrition.summary?.pinnedNutrients, ['vitaminD', 'iron']);
      expect(nutrition.pinError, isNotNull);

      repository.writes[1].complete();
      await second;
      expect(nutrition.summary?.pinnedNutrients, ['vitaminD', 'iron']);
    });
  });
}
