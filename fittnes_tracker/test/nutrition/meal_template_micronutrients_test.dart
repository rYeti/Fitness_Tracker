import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/nutrition/extended_nutrients.dart';
import 'package:ForgeForm/feature/food_tracking/data/models/meal_template.dart';
import 'package:ForgeForm/feature/food_tracking/data/repositories/meal_template_repository.dart';
import 'package:ForgeForm/feature/food_tracking/data/repositories/nutrition_repository.dart';

/// A meal template used to drop a food's micronutrients on the floor, and not
/// because anything failed: `MealTemplateItem` simply had no field to put them
/// in, so every screen that built one was correct to omit them and the food
/// arrived in the diary as macros alone.
///
/// The chain pinned here is the whole of it — the item model, its JSON
/// round-trip through `SharedPreferences`, and the two apply paths that write
/// the `FoodItem` row the day's fold actually reads. The last step is the one
/// that matters: a template can carry micronutrients perfectly and still log
/// none, and only the row proves otherwise.
///
/// See `docs/trainer-console-micronutrients.md` §8e.
const _fibreGrams = 4.5;
const _ironGrams = 0.0042;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MealTemplateRepository templates;
  late NutritionRepository nutrition;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.test(NativeDatabase.memory());
    templates = MealTemplateRepository(db);
    nutrition = NutritionRepository(db);
  });
  tearDown(() => db.close());

  MealTemplateItem item({ExtendedNutrients? nutrients, double quantity = 350}) =>
      MealTemplateItem(
        templateId: -1,
        foodId: 0,
        foodName: 'Pizza Die Backfrische Mozzarella',
        quantity: quantity,
        unit: 'g',
        calories: 746,
        protein: 35,
        carbs: 95,
        fat: 25,
        extendedNutrients: nutrients,
      );

  Future<MealTemplate> saveAndReload(MealTemplateItem first) async {
    await templates.createMealTemplate(
      MealTemplate(
        name: 'Friday pizza',
        category: 'Dinner',
        items: [first],
        totalWeightGrams: 350,
      ),
    );
    final reloaded = await templates.getTemplatesByCategory('Dinner');
    expect(reloaded, hasLength(1));
    return reloaded.single;
  }

  test('a template item keeps its micronutrients across the JSON round trip',
      () async {
    final template = await saveAndReload(
      item(
        nutrients: const ExtendedNutrients(
          fiber: _fibreGrams,
          iron: _ironGrams,
        ),
      ),
    );

    final nutrients = template.items.single.extendedNutrients;
    expect(nutrients, isNotNull);
    expect(nutrients!.fiber, closeTo(_fibreGrams, 1e-9));
    expect(nutrients.iron, closeTo(_ironGrams, 1e-9));
    // Nobody reported these, so they stay silent rather than becoming zero.
    expect(nutrients.sugar, isNull);
  });

  test('applying a template logs a row the day fold can see', () async {
    final template = await saveAndReload(
      item(
        nutrients: const ExtendedNutrients(
          fiber: _fibreGrams,
          iron: _ironGrams,
        ),
      ),
    );

    await nutrition.applyTemplateToMeal('Dinner', template.items);

    final rows = await db.foodItemDao.getAllFoodItems();
    expect(rows, hasLength(1));
    // The item's blob is already scaled to its own quantity, so it is written
    // straight through — no rescale on this path.
    final logged = ExtendedNutrients.fromJsonString(
      rows.single.extendedNutrientsJson!,
    );
    expect(logged.fiber, closeTo(_fibreGrams, 1e-9));
    expect(logged.iron, closeTo(_ironGrams, 1e-9));
  });

  test('logging a template as one portion scales its micronutrients', () async {
    final template = await saveAndReload(
      item(
        nutrients: const ExtendedNutrients(
          fiber: _fibreGrams,
          iron: _ironGrams,
        ),
      ),
    );

    // Double the template's own 350 g total, so double its micronutrients —
    // the same `ratio` the macros on that path use.
    await nutrition.applyTemplatePortion('Dinner', template, 700);

    final rows = await db.foodItemDao.getAllFoodItems();
    expect(rows, hasLength(1));
    final logged = ExtendedNutrients.fromJsonString(
      rows.single.extendedNutrientsJson!,
    );
    expect(logged.fiber, closeTo(_fibreGrams * 2, 1e-9));
    expect(logged.iron, closeTo(_ironGrams * 2, 1e-9));
  });

  test('a template of foods with no micronutrients logs a null column, not {}',
      () async {
    final template = await saveAndReload(item());

    await nutrition.applyTemplatePortion('Dinner', template, 700);

    final rows = await db.foodItemDao.getAllFoodItems();
    expect(rows, hasLength(1));
    // "{}" would be a non-null column meaning "no data" — the exact conflation
    // between unmeasured and measured-zero the whole feature avoids.
    expect(rows.single.extendedNutrientsJson, isNull);
  });
}
