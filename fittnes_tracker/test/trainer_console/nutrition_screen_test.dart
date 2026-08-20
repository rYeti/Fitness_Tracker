import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/active_client_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/nutrition_screen.dart';

import 'fakes.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeTrainerConsoleRepository repository, {
  Size size = const Size(1400, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final activeClient = ActiveClientProvider(repository: repository);
  await activeClient.loadClients();

  await tester.pumpWidget(
    ChangeNotifierProvider<ActiveClientProvider>.value(
      value: activeClient,
      child: MaterialApp(home: NutritionScreen(repository: repository)),
    ),
  );
}

void main() {
  testWidgets('no clients shows the empty state', (tester) async {
    await _pump(tester, FakeTrainerConsoleRepository());
    await tester.pumpAndSettle();

    expect(find.text('No clients yet'), findsOneWidget);
  });

  testWidgets('a failing request shows an inline error with retry', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        roster: [fakeClient()],
        throwOnNutrition: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('ring announces remaining calories and macros render', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        roster: [fakeClient()],
        nutrition: fakeNutrition(totalCalories: 1850, goal: 2200),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('1850 of 2200 kcal, 350 remaining'),
      findsOneWidget,
    );
    expect(find.text('Protein 140g'), findsOneWidget);
    expect(find.text('Carbs 190g'), findsOneWidget);
    expect(find.text('Fat 60g'), findsOneWidget);
  });

  testWidgets('going over the goal is announced as over, not remaining', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        roster: [fakeClient()],
        nutrition: fakeNutrition(totalCalories: 2500, goal: 2200),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('2500 of 2200 kcal, over by 300'),
      findsOneWidget,
    );
  });

  testWidgets('meals are listed in time-of-day order with calories', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        roster: [fakeClient()],
        nutrition: fakeNutrition(
          meals: const [
            // Deliberately out of order — the screen sorts them.
            LoggedMeal(
              mealId: 'm2',
              category: 'dinner',
              foodNames: ['Salmon', 'Rice'],
              calories: 720,
              macros: MacroTotals(protein: 50, carbs: 60, fat: 25),
            ),
            LoggedMeal(
              mealId: 'm1',
              category: 'breakfast',
              foodNames: ['Oats'],
              calories: 410,
              macros: MacroTotals(protein: 20, carbs: 60, fat: 8),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final breakfast = tester.getTopLeft(find.text('Breakfast')).dy;
    final dinner = tester.getTopLeft(find.text('Dinner')).dy;
    expect(breakfast, lessThan(dinner));

    expect(find.text('410 kcal'), findsOneWidget);
    expect(find.text('Salmon, Rice'), findsOneWidget);
  });

  testWidgets('a day with no meals shows the nothing-logged state', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        roster: [fakeClient()],
        nutrition: fakeNutrition(meals: const []),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing logged'), findsOneWidget);
  });

  testWidgets('the day switcher cannot page past today', (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        roster: [fakeClient()],
        nutrition: fakeNutrition(),
      ),
    );
    await tester.pumpAndSettle();

    // Starts on today, so forward is disabled until the trainer goes back.
    final forward = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.chevron_right_rounded),
        matching: find.byType(IconButton),
      ),
    );
    expect(forward.onPressed, isNull);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();

    final forwardAfter = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.chevron_right_rounded),
        matching: find.byType(IconButton),
      ),
    );
    expect(forwardAfter.onPressed, isNotNull);
  });

  testWidgets('over-budget days are announced in the trend', (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        roster: [fakeClient()],
        nutrition: fakeNutrition(
          goal: 2000,
          trend: [
            DailyCalorieTotal(
              date: DateTime(2026, 8, 19),
              totalCalories: 1500,
              goal: 2000,
            ),
            DailyCalorieTotal(
              date: DateTime(2026, 8, 20),
              totalCalories: 2600,
              goal: 2000,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Thursday: 2600 kcal, over target'),
        findsOneWidget);
    expect(find.bySemanticsLabel('Wednesday: 1500 kcal'), findsOneWidget);
  });
}
