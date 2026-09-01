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
}
