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

void main() {
  testWidgets('a client with no plan lands in the create flow', (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(roster: [fakeClient()]),
    );
    await tester.pumpAndSettle();

    expect(find.text('New plan'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Plan name'), findsOneWidget);
  });

  testWidgets('a client with a plan sees it read-only', (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        roster: [fakeClient()],
        workoutSummary: _summaryWithPlan(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Push / Pull / Legs'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    // The unsupported editor is disclosed rather than faked.
    expect(find.text('Exercise editing isn’t available yet'), findsOneWidget);
  });

  testWidgets('submitting an empty name is rejected before any request', (
    tester,
  ) async {
    final repository = FakeTrainerConsoleRepository(roster: [fakeClient()]);
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Assign to'));
    await tester.pumpAndSettle();

    expect(find.text('Give the plan a name'), findsOneWidget);
    expect(repository.createdPlans, isEmpty);
  });

  testWidgets('creating a plan sends the name and confirms', (tester) async {
    final repository = FakeTrainerConsoleRepository(roster: [fakeClient()]);
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
        roster: [fakeClient()],
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
}
