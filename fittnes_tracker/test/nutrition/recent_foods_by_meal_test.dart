import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/app_database.dart';

/// These pin the ordering behind "Recently Added" on the per-meal food search
/// screen. Nothing here is expressible in the type system: the list was always
/// a `List<String>` and always held the right foods — it just held them in an
/// order that had nothing to do with the meal being logged.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.test(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> addFood(String name, {int kcal = 100}) {
    return db
        .into(db.foodItem)
        .insert(
          FoodItemCompanion.insert(
            name: name,
            calories: kcal,
            protein: 0,
            carbs: 0,
            fat: 0,
          ),
        );
  }

  /// Mirrors NutritionRepository.addFoodToMeal: one meal row per day and
  /// category, foods attached through MealFoodTable.
  Future<int> logMeal(
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
    return mealId;
  }

  Future<List<String>> namesFor(String category) =>
      db.mealDao.watchFoodNamesLoggedInCategory(category).first;

  test('only returns foods logged under the category asked for', () async {
    final oats = await addFood('Oats');
    final chicken = await addFood('Chicken');
    final day = DateTime(2026, 8, 20);

    await logMeal(day, 'Breakfast', [oats]);
    await logMeal(day, 'Lunch', [chicken]);

    expect(await namesFor('Breakfast'), ['oats']);
    expect(await namesFor('Lunch'), ['chicken']);
    expect(await namesFor('Dinner'), isEmpty);
  });

  test('orders most recently logged first, including within one day', () async {
    final oats = await addFood('Oats');
    final eggs = await addFood('Eggs');
    final whey = await addFood('Whey');

    await logMeal(DateTime(2026, 8, 19), 'Breakfast', [oats]);
    final today = await logMeal(DateTime(2026, 8, 20), 'Breakfast', [eggs]);

    // Eggs and whey land on the same calendar day. MealTable.date is the local
    // midnight for that day, identical for both, so it cannot order them —
    // only the MealFoodTable autoincrement can.
    await db.mealDao.addFoodToMeal(whey, today);

    expect(await namesFor('Breakfast'), ['whey', 'eggs', 'oats']);
  });

  test('a food logged repeatedly appears once, at its latest position', () async {
    final oats = await addFood('Oats');
    final eggs = await addFood('Eggs');

    await logMeal(DateTime(2026, 8, 18), 'Breakfast', [oats]);
    await logMeal(DateTime(2026, 8, 19), 'Breakfast', [eggs]);
    await logMeal(DateTime(2026, 8, 20), 'Breakfast', [oats]);

    expect(await namesFor('Breakfast'), ['oats', 'eggs']);
  });

  test('Snack and Snacks are the same category', () async {
    final almonds = await addFood('Almonds');
    await logMeal(DateTime(2026, 8, 20), 'Snack', [almonds]);

    // The app renamed this category mid-life; a query that compared the raw
    // string would show a user none of the snacks they logged before the
    // rename. See docs/trainer-nutrition-duplicate-meals.md.
    expect(await namesFor('Snacks'), ['almonds']);
    expect(await namesFor('Snack'), ['almonds']);
  });

  test('category comparison ignores casing', () async {
    final oats = await addFood('Oats');
    await logMeal(DateTime(2026, 8, 20), 'breakfast', [oats]);

    expect(await namesFor('Breakfast'), ['oats']);
  });

  test('matches the recent-list row by name, not by id', () async {
    // What a quick-add actually writes: the row the recent list shows is never
    // the row that ends up in the meal. `_quickAddFromRecent` inserts a second
    // FoodItem holding the chosen portion's macros and links *that* one.
    final shown = await addFood('Oats', kcal: 370);
    final scaledPortion = await addFood('Oats', kcal: 555);
    expect(scaledPortion, isNot(shown));

    await logMeal(DateTime(2026, 8, 20), 'Breakfast', [scaledPortion]);

    // The screen looks the returned names up by the shown row's normalised
    // name. Joining on id instead would leave this list empty and the feature
    // silently inert.
    expect(await namesFor('Breakfast'), contains('oats'));
  });

  test('names are normalised the way the recent list deduplicates', () async {
    final oats = await addFood('  Oats  ');
    await logMeal(DateTime(2026, 8, 20), 'Breakfast', [oats]);

    expect(await namesFor('Breakfast'), ['oats']);
  });
}
