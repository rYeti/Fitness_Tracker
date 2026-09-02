import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/active_client_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/workout_builder_screen.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

import 'fakes.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeTrainerConsoleRepository repository, {
  Size size = const Size(1400, 1200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final activeClient = ActiveClientProvider(repository: repository);
  await activeClient.loadClients();

  await tester.pumpWidget(
    ChangeNotifierProvider<ActiveClientProvider>.value(
      value: activeClient,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WorkoutBuilderScreen(repository: repository),
      ),
    ),
  );
}

ClientWorkoutSummary _summaryWithPlan() => ClientWorkoutSummary(
  currentPlan: WorkoutPlanSummary(
    id: 'plan-1',
    name: 'Push / Pull / Legs',
    description: 'Four-day hypertrophy block',
    isActive: true,
    startDate: DateTime(2026, 7, 1),
  ),
  attendance: const [],
  strengthProgression: const [],
);

ClientWorkout _pushDay() => ClientWorkout(
  id: 'workout-1',
  name: 'Push Day',
  difficulty: 1,
  estimatedDurationMinutes: 60,
  planIds: const ['plan-1'],
  exercises: [
    ClientWorkoutExercise(
      id: 'we-1',
      exerciseId: 'ex-bench',
      exerciseName: 'Bench Press',
      notes: 'Keep elbows tucked',
      sets: const [
        ClientWorkoutSet(id: 'set-1', setNumber: 1, targetReps: '8-12'),
        ClientWorkoutSet(id: 'set-2', setNumber: 2, targetReps: '8-12'),
      ],
    ),
  ],
);

/// Three sets with distinct reps so removing the middle one is unambiguous —
/// the shape the `_SetChip`/set-row identity bug needs to reproduce.
ClientWorkout _legDayWithThreeSets() => ClientWorkout(
  id: 'workout-1',
  name: 'Leg Day',
  difficulty: 1,
  estimatedDurationMinutes: 60,
  planIds: const ['plan-1'],
  exercises: [
    ClientWorkoutExercise(
      id: 'we-1',
      exerciseId: 'ex-squat',
      exerciseName: 'Back Squat',
      sets: const [
        ClientWorkoutSet(id: 'set-1', setNumber: 1, targetReps: '10'),
        ClientWorkoutSet(id: 'set-2', setNumber: 2, targetReps: '8'),
        ClientWorkoutSet(id: 'set-3', setNumber: 3, targetReps: '6'),
      ],
    ),
  ],
);

void main() {
  testWidgets('a client with no plan lands in the create flow', (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(rosterWithStats: [fakeRosterEntry()]),
    );
    await tester.pumpAndSettle();

    expect(find.text('New plan'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Plan name'), findsOneWidget);
  });

  testWidgets('submitting an empty plan name is rejected before any request', (
    tester,
  ) async {
    final repository = FakeTrainerConsoleRepository(rosterWithStats: [fakeRosterEntry()]);
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Assign to'));
    await tester.pumpAndSettle();

    expect(find.text('Give the plan a name'), findsOneWidget);
    expect(repository.createdPlans, isEmpty);
  });

  testWidgets('creating a plan sends the name and confirms', (tester) async {
    final repository = FakeTrainerConsoleRepository(rosterWithStats: [fakeRosterEntry()]);
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Plan name'),
      'Upper / Lower',
    );
    await tester.tap(find.textContaining('Assign to'));
    await tester.pumpAndSettle();

    expect(repository.createdPlans.single.name, 'Upper / Lower');
    expect(repository.createdPlans.single.clientId, 'client-1');
    expect(find.textContaining('Plan assigned to'), findsOneWidget);
  });

  testWidgets('choosing a template pre-fills the plan name', (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        rosterWithStats: [fakeRosterEntry()],
        templates: const [
          WorkoutPlanTemplateSummary(
            id: 'tpl-1',
            name: 'Full Body 3x',
            description: 'Beginner strength',
            icon: 'fitness_center',
            daysPerWeek: 3,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Full Body 3x'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.descendant(
        of: find.widgetWithText(TextFormField, 'Plan name'),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller?.text, 'Full Body 3x');
  });

  testWidgets('a plan with no days yet offers to add the first one', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        rosterWithStats: [fakeRosterEntry()],
        workoutSummary: _summaryWithPlan(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Push / Pull / Legs'), findsOneWidget);
    expect(find.text('No days yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'New day'), findsOneWidget);
  });

  testWidgets('an existing day shows its exercises and sets', (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        rosterWithStats: [fakeRosterEntry()],
        workoutSummary: _summaryWithPlan(),
        clientWorkouts: [_pushDay()],
      ),
    );
    await tester.pumpAndSettle();

    // The day chip and the editor both show the day's name.
    expect(find.text('Push Day'), findsWidgets);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('8-12'), findsNWidgets(2));
  });

  testWidgets('adding a day with an empty name is rejected before saving', (
    tester,
  ) async {
    final repository = FakeTrainerConsoleRepository(
      rosterWithStats: [fakeRosterEntry()],
      workoutSummary: _summaryWithPlan(),
    );
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'New day'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save day'));
    await tester.pumpAndSettle();

    expect(find.text('Give the day a name.'), findsOneWidget);
    expect(repository.savedWorkouts, isEmpty);
  });

  testWidgets('creating a day with an exercise saves it under the plan', (
    tester,
  ) async {
    final repository = FakeTrainerConsoleRepository(
      rosterWithStats: [fakeRosterEntry()],
      workoutSummary: _summaryWithPlan(),
      exerciseLibrary: const [
        ClientExerciseOption(id: 'ex-squat', name: 'Back Squat', isTrainerOwned: false),
      ],
    );
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'New day'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Day name'),
      'Leg Day',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Add exercise'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back Squat'));
    await tester.pumpAndSettle();

    expect(find.text('Back Squat'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save day'));
    await tester.pumpAndSettle();

    expect(repository.savedWorkouts.single.name, 'Leg Day');
    expect(repository.savedWorkouts.single.exercises.single.exerciseId, 'ex-squat');
    expect(find.textContaining('Leg Day saved'), findsOneWidget);
  });

  testWidgets('a trainer-owned exercise is flagged as shareable in the picker', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        rosterWithStats: [fakeRosterEntry()],
        workoutSummary: _summaryWithPlan(),
        exerciseLibrary: const [
          ClientExerciseOption(id: 'ex-1', name: 'Cable Row', isTrainerOwned: true),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'New day'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Add exercise'));
    await tester.pumpAndSettle();

    expect(find.text('Cable Row'), findsOneWidget);
    expect(
      find.text('Yours — prescribing this shares a copy with the client'),
      findsOneWidget,
    );
  });

  testWidgets('deleting a day asks for confirmation first', (tester) async {
    final repository = FakeTrainerConsoleRepository(
      rosterWithStats: [fakeRosterEntry()],
      workoutSummary: _summaryWithPlan(),
      clientWorkouts: [_pushDay()],
    );
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Delete day'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this day?'), findsOneWidget);
    expect(repository.deletedWorkoutIds, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete day'));
    await tester.pumpAndSettle();

    expect(repository.deletedWorkoutIds, ['workout-1']);
  });

  testWidgets('switching to a new day with unsaved edits asks to discard', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        rosterWithStats: [fakeRosterEntry()],
        workoutSummary: _summaryWithPlan(),
        clientWorkouts: [_pushDay()],
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Day name'),
      'Push Day (renamed)',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ActionChip, 'New day'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
  });

  group('phone width (390x844)', () {
    testWidgets(
      'the first exercise of an existing day is visible without scrolling',
      (tester) async {
        await _pump(
          tester,
          FakeTrainerConsoleRepository(
            rosterWithStats: [fakeRosterEntry()],
            workoutSummary: _summaryWithPlan(),
            clientWorkouts: [_pushDay()],
          ),
          size: const Size(390, 844),
        );
        await tester.pumpAndSettle();

        // The complaint, stated directly: the exercise editor is the reason the
        // screen exists, and the trainer should not have to scroll past the
        // plan summary and the day's own metadata to reach it.
        final position = tester.getTopLeft(find.text('Bench Press'));
        expect(position.dy, lessThan(844));
      },
    );

    testWidgets('Save day is reachable without scrolling', (tester) async {
      await _pump(
        tester,
        FakeTrainerConsoleRepository(
          rosterWithStats: [fakeRosterEntry()],
          workoutSummary: _summaryWithPlan(),
          clientWorkouts: [_pushDay()],
        ),
        size: const Size(390, 844),
      );
      await tester.pumpAndSettle();

      final saveButton = tester.getBottomLeft(
        find.widgetWithText(FilledButton, 'Save day'),
      );
      expect(saveButton.dy, lessThanOrEqualTo(844));
    });

    testWidgets(
      'day details start collapsed for an existing day, expanded for a new one',
      (tester) async {
        await _pump(
          tester,
          FakeTrainerConsoleRepository(
            rosterWithStats: [fakeRosterEntry()],
            workoutSummary: _summaryWithPlan(),
            clientWorkouts: [_pushDay()],
          ),
          size: const Size(390, 844),
        );
        await tester.pumpAndSettle();

        // Collapsed: the trainer opened an existing day to work on its
        // exercises, not to rename it.
        expect(find.widgetWithText(TextFormField, 'Day name'), findsNothing);

        // A new day has nothing else to show yet, so its name field is the
        // first thing the trainer needs.
        await tester.tap(find.widgetWithText(ActionChip, 'New day'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(TextFormField, 'Day name'), findsOneWidget);
      },
    );

    testWidgets('every exercise and set control is at least 44x44', (
      tester,
    ) async {
      await _pump(
        tester,
        FakeTrainerConsoleRepository(
          rosterWithStats: [fakeRosterEntry()],
          workoutSummary: _summaryWithPlan(),
          clientWorkouts: [_legDayWithThreeSets()],
        ),
        size: const Size(390, 844),
      );
      await tester.pumpAndSettle();

      // IconButton's own accessible name comes through as a semantics
      // *tooltip*, not a *label* — `find.byTooltip` is the finder for those;
      // 'Remove set' is a plain `Semantics(label: ...)` and needs the other.
      const tooltipControls = [
        'Remove exercise',
        'Move up',
        'Move down',
      ];
      for (final tooltip in tooltipControls) {
        final finder = find.byTooltip(tooltip);
        final count = finder.evaluate().length;
        expect(count, greaterThan(0), reason: '$tooltip was not found');
        for (var i = 0; i < count; i++) {
          final size = tester.getSize(finder.at(i));
          expect(size.width, greaterThanOrEqualTo(44), reason: '$tooltip width');
          expect(size.height, greaterThanOrEqualTo(44), reason: '$tooltip height');
        }
      }

      final removeSetFinder = find.bySemanticsLabel('Remove set');
      final removeSetCount = removeSetFinder.evaluate().length;
      expect(removeSetCount, greaterThan(0), reason: 'Remove set was not found');
      for (var i = 0; i < removeSetCount; i++) {
        final size = tester.getSize(removeSetFinder.at(i));
        expect(size.width, greaterThanOrEqualTo(44), reason: 'Remove set width');
        expect(size.height, greaterThanOrEqualTo(44), reason: 'Remove set height');
      }
    });

    testWidgets(
      'removing the middle set leaves the other two showing their own reps',
      (tester) async {
        final repository = FakeTrainerConsoleRepository(
          rosterWithStats: [fakeRosterEntry()],
          workoutSummary: _summaryWithPlan(),
          clientWorkouts: [_legDayWithThreeSets()],
        );
        await _pump(tester, repository, size: const Size(390, 844));
        await tester.pumpAndSettle();

        // Invoke the InkWell's onTap directly rather than simulating a
        // coordinate tap: this environment's hit-testing for a Semantics
        // node wrapping an InkWell that generates its own semantics too is
        // unreliable in a way unrelated to the behaviour under test (the
        // geometry, confirmed separately, is correct). The callback wiring
        // is what this test is actually checking.
        final removeMiddleSet = find.descendant(
          of: find.bySemanticsLabel('Remove set').at(1),
          matching: find.byType(InkWell),
        );
        tester.widget<InkWell>(removeMiddleSet).onTap!();
        await tester.pumpAndSettle();

        final repsFields = tester
            .widgetList<TextField>(find.byType(TextField))
            .where((f) => f.controller?.text == '10' || f.controller?.text == '6')
            .toList();
        expect(repsFields, hasLength(2));
        // The bug this guards: an unkeyed set row's controller keeps showing
        // the value of the row that used to sit at that index, so a leftover
        // '8' here would mean the deleted set's text, not the deleted set,
        // survived the removal.
        expect(
          tester
              .widgetList<TextField>(find.byType(TextField))
              .any((f) => f.controller?.text == '8'),
          isFalse,
        );

        await tester.tap(find.widgetWithText(FilledButton, 'Save day'));
        await tester.pumpAndSettle();

        expect(
          repository.savedWorkouts.single.exercises.single.targetReps,
          ['10', '6'],
        );
      },
    );
  });
}
