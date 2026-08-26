import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/active_client_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/nutrition_screen.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/meal_detail_sheet.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

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
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NutritionScreen(repository: repository),
      ),
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
        rosterWithStats: [fakeRosterEntry()],
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
        rosterWithStats: [fakeRosterEntry()],
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
        rosterWithStats: [fakeRosterEntry()],
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
        rosterWithStats: [fakeRosterEntry()],
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

  testWidgets('the app\'s own "Snacks" spelling is labelled and ordered', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        rosterWithStats: [fakeRosterEntry()],
        nutrition: fakeNutrition(
          meals: const [
            LoggedMeal(
              mealId: 'm2',
              category: 'dinner',
              foodNames: ['Salmon'],
              calories: 720,
              macros: MacroTotals(protein: 50, carbs: 60, fat: 25),
            ),
            // What the tracker actually writes — not the "snack" the API's
            // own DTOs document, which is all this screen used to match.
            LoggedMeal(
              mealId: 'm3',
              category: 'Snacks',
              foodNames: ['Almonds'],
              calories: 180,
              macros: MacroTotals(protein: 6, carbs: 6, fat: 15),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Snacks'), findsOneWidget);
    expect(find.byIcon(Icons.cookie_outlined), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Snacks')).dy,
      lessThan(tester.getTopLeft(find.text('Dinner')).dy),
    );
  });

  testWidgets('a day with no meals shows the nothing-logged state', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        rosterWithStats: [fakeRosterEntry()],
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
        rosterWithStats: [fakeRosterEntry()],
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
        rosterWithStats: [fakeRosterEntry()],
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

  testWidgets('tapping a meal opens its foods with per-food nutrition', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        rosterWithStats: [fakeRosterEntry()],
        nutrition: fakeNutrition(
          meals: const [
            LoggedMeal(
              mealId: 'm1',
              category: 'breakfast',
              foodNames: ['Porridge oats', 'Greek yoghurt', 'Blueberries'],
              calories: 410,
              macros: MacroTotals(protein: 24, carbs: 58, fat: 9),
              foods: [
                LoggedFood(
                  foodItemId: 'f1',
                  name: 'Porridge oats',
                  grams: 80,
                  calories: 300,
                  macros: MacroTotals(protein: 10, carbs: 50, fat: 6),
                ),
                LoggedFood(
                  foodItemId: 'f2',
                  name: 'Greek yoghurt',
                  grams: 150,
                  calories: 85,
                  macros: MacroTotals(protein: 13, carbs: 6, fat: 3),
                ),
                LoggedFood(
                  foodItemId: 'f3',
                  name: 'Blueberries',
                  grams: 40,
                  calories: 25,
                  macros: MacroTotals(protein: 1, carbs: 2, fat: 0),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Breakfast'));
    await tester.pumpAndSettle();

    expect(find.text('3 foods'), findsOneWidget);
    // The collapsed row joins all three names into one Text, so each name on
    // its own only matches the sheet's per-food row.
    expect(find.text('Porridge oats'), findsOneWidget);
    expect(find.text('Greek yoghurt'), findsOneWidget);
    expect(find.text('300 kcal'), findsOneWidget);
    expect(find.text('80 g'), findsOneWidget);
    expect(find.text('P 10g'), findsOneWidget);
    expect(find.text('C 50g'), findsOneWidget);
    expect(find.text('F 6g'), findsOneWidget);
  });

  testWidgets('a food row is announced as one label, not six fragments', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        rosterWithStats: [fakeRosterEntry()],
        nutrition: fakeNutrition(
          meals: const [
            LoggedMeal(
              mealId: 'm1',
              category: 'breakfast',
              foodNames: ['Porridge oats'],
              calories: 300,
              macros: MacroTotals(protein: 10, carbs: 50, fat: 6),
              foods: [
                LoggedFood(
                  foodItemId: 'f1',
                  name: 'Porridge oats',
                  grams: 80,
                  calories: 300,
                  macros: MacroTotals(protein: 10, carbs: 50, fat: 6),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel(
        'Breakfast, 300 kcal. Open to see every food logged.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Breakfast'));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel(
        'Porridge oats, 80 grams, 300 kcal, protein 10g, carbs 50g, fat 6g',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a meal with no per-food detail is not tappable', (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        rosterWithStats: [fakeRosterEntry()],
        nutrition: fakeNutrition(
          meals: const [
            // No `foods` — an API build older than the detail view.
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

    expect(
      find.ancestor(of: find.text('Breakfast'), matching: find.byType(InkWell)),
      findsNothing,
    );

    await tester.tap(find.text('Breakfast'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(MealDetailSheet), findsNothing);
  });

  testWidgets('a food with no recorded serving size shows no weight', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        rosterWithStats: [fakeRosterEntry()],
        nutrition: fakeNutrition(
          meals: const [
            LoggedMeal(
              mealId: 'm1',
              category: 'lunch',
              foodNames: ['Leftover curry'],
              calories: 520,
              macros: MacroTotals(protein: 30, carbs: 55, fat: 18),
              foods: [
                LoggedFood(
                  foodItemId: 'f1',
                  name: 'Leftover curry',
                  calories: 520,
                  macros: MacroTotals(protein: 30, carbs: 55, fat: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lunch'));
    await tester.pumpAndSettle();

    expect(find.text('0 g'), findsNothing);
    expect(
      find.bySemanticsLabel(
        'Leftover curry, 520 kcal, protein 30g, carbs 55g, fat 18g',
      ),
      findsOneWidget,
    );
  });
}
