import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/app_database.dart';

/// `FoodItemDao.updateFoodItem` used to have no `extendedNutrientsJson`
/// parameter at all, so editing a food's weight rewrote its macros for the
/// new weight and silently left the micronutrients scaled to the old one —
/// the compiler had nothing to say about a parameter that was never there.
/// See docs/trainer-console-micronutrients.md.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.test(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('updateFoodItem leaves extendedNutrientsJson untouched by default', () async {
    final id = await db.foodItemDao.insertFoodItem(
      FoodItemCompanion.insert(
        name: 'Oats',
        calories: 320,
        protein: 12,
        carbs: 54,
        fat: 6,
        gramm: const Value(100),
        extendedNutrientsJson: const Value('{"fiber":9.3}'),
      ),
    );

    // A caller that only changes macros/weight and passes nothing for
    // micronutrients — most callers — must not clobber what's already there.
    await db.foodItemDao.updateFoodItem(
      id,
      calories: 640,
      protein: 24,
      carbs: 108,
      fat: 12,
      gramm: 200,
    );

    final updated = await db.foodItemDao.getFoodItemById(id);
    expect(updated!.extendedNutrientsJson, '{"fiber":9.3}');
    expect(updated.calories, 640);
  });

  test('updateFoodItem writes a rescaled blob when the caller supplies one', () async {
    final id = await db.foodItemDao.insertFoodItem(
      FoodItemCompanion.insert(
        name: 'Oats',
        calories: 320,
        protein: 12,
        carbs: 54,
        fat: 6,
        gramm: const Value(100),
        extendedNutrientsJson: const Value('{"fiber":9.3}'),
      ),
    );

    await db.foodItemDao.updateFoodItem(
      id,
      calories: 640,
      protein: 24,
      carbs: 108,
      fat: 12,
      gramm: 200,
      extendedNutrientsJson: const Value('{"fiber":18.6}'),
    );

    final updated = await db.foodItemDao.getFoodItemById(id);
    expect(updated!.extendedNutrientsJson, '{"fiber":18.6}');
  });

  test('an edit marks the row pendingUpdate, the same as any other edit', () async {
    final id = await db.foodItemDao.insertFoodItem(
      FoodItemCompanion.insert(name: 'Oats', calories: 320, protein: 12, carbs: 54, fat: 6),
    );

    await db.foodItemDao.updateFoodItem(id, calories: 640, protein: 24, carbs: 108, fat: 12, gramm: 200);

    final updated = await db.foodItemDao.getFoodItemById(id);
    expect(updated!.syncStatus, 2); // pendingUpdate
  });
}
