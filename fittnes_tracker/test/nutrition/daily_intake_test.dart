import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/app_database.dart';

/// These pin the arithmetic behind the nutrition trend and the adaptive TDEE
/// estimate. Both were wrong in ways that only show up as "the number looks
/// off", so they're worth asserting on real rows rather than by inspection.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.test(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> addFood(String name, int kcal, {int protein = 0}) {
    return db
        .into(db.foodItem)
        .insert(
          FoodItemCompanion.insert(
            name: name,
            calories: kcal,
            protein: protein,
            carbs: 0,
            fat: 0,
          ),
        );
  }

  /// Mirrors NutritionRepository: the meal row records only the *first* food
  /// in `foodItemId`; every food (including that one) is joined via
  /// MealFoodTable.
  Future<void> logMeal(
    DateTime date,
    String category,
    List<int> foodIds,
  ) async {
    final mealId = await db.mealDao.insertMeal(
      MealTableCompanion.insert(
        date: date,
        category: category,
        foodItemId: foodIds.first,
      ),
    );
    for (final id in foodIds) {
      await db.mealDao.addFoodToMeal(id, mealId);
    }
  }

  test('totals every food in a meal, not just the first', () async {
    final oats = await addFood('Oats', 400);
    final berries = await addFood('Blueberries', 80);
    final whey = await addFood('Whey', 120);
    final day = DateTime(2026, 8, 20);

    await logMeal(day, 'Breakfast', [oats, berries, whey]);

    final intake = await db.mealDao.getDailyIntake(day, day);

    // Joining MealTable.foodItemId — the old adaptive-TDEE query — would have
    // returned 400 here, the oats alone.
    expect(intake.single.calories, 600);
  });

  test('sums across several meals in a day', () async {
    final eggs = await addFood('Eggs', 200, protein: 18);
    final rice = await addFood('Rice', 350, protein: 7);
    final day = DateTime(2026, 8, 20);

    await logMeal(day, 'Breakfast', [eggs]);
    await logMeal(day, 'Lunch', [rice]);

    final intake = await db.mealDao.getDailyIntake(day, day);

    expect(intake.single.calories, 550);
    expect(intake.single.protein, 25);
  });

  test('omits days with nothing logged rather than reporting them as zero',
      () async {
    final food = await addFood('Toast', 250);
    await logMeal(DateTime(2026, 8, 18), 'Breakfast', [food]);
    await logMeal(DateTime(2026, 8, 20), 'Breakfast', [food]);

    final intake = await db.mealDao.getDailyIntake(
      DateTime(2026, 8, 18),
      DateTime(2026, 8, 20),
    );

    // The 19th is absent, so callers can tell "didn't log" from "ate nothing".
    expect(intake.map((d) => d.date.day), [18, 20]);
  });

  test('is inclusive of both range ends', () async {
    final food = await addFood('Toast', 250);
    await logMeal(DateTime(2026, 8, 18), 'Breakfast', [food]);
    await logMeal(DateTime(2026, 8, 20), 'Breakfast', [food]);

    final intake = await db.mealDao.getDailyIntake(
      DateTime(2026, 8, 18),
      DateTime(2026, 8, 20),
    );

    expect(intake.length, 2);
  });

  test('excludes meals outside the range', () async {
    final food = await addFood('Toast', 250);
    await logMeal(DateTime(2026, 8, 17), 'Breakfast', [food]);
    await logMeal(DateTime(2026, 8, 21), 'Breakfast', [food]);
    await logMeal(DateTime(2026, 8, 19), 'Breakfast', [food]);

    final intake = await db.mealDao.getDailyIntake(
      DateTime(2026, 8, 18),
      DateTime(2026, 8, 20),
    );

    expect(intake.map((d) => d.date.day), [19]);
  });

  test('buckets a late-evening meal into its own day', () async {
    final food = await addFood('Snack', 300);
    await logMeal(DateTime(2026, 8, 20, 23, 45), 'Snacks', [food]);

    final intake = await db.mealDao.getDailyIntake(
      DateTime(2026, 8, 20),
      DateTime(2026, 8, 20),
    );

    expect(intake.single.calories, 300);
  });

  test('a seven-day window spans seven days, not eight', () async {
    final food = await addFood('Toast', 250);
    final today = DateTime(2026, 8, 20);
    // What _rangeStart(TimeRange.week) now produces: today minus six.
    final start = today.subtract(const Duration(days: 6));

    for (var d = 0; d <= 6; d++) {
      await logMeal(start.add(Duration(days: d)), 'Breakfast', [food]);
    }
    // A day before the window opens must not be counted.
    await logMeal(start.subtract(const Duration(days: 1)), 'Breakfast', [food]);

    final intake = await db.mealDao.getDailyIntake(start, today);

    // Subtracting the full 7 days gave 8 here — the "5/8 instead of 5/7".
    expect(intake.length, 7);
  });
}
