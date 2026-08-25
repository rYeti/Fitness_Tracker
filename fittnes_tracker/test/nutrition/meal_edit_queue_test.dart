import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/feature/food_tracking/data/repositories/nutrition_repository.dart';

/// Whether editing a meal that has already been pushed leaves anything for the
/// sync to do.
///
/// It did not. `syncMeals()` iterates *unsynced* meals, and nothing in the app
/// ever called `markMealPendingUpdate` — so a food added after the meal synced
/// sat on the device forever: invisible to the trainer, and gone on reinstall.
/// Removals were worse than invisible, since deleting the local row destroys the
/// only record that the entry existed at all.
///
/// These run against a real database rather than a mock: the bug was never in
/// the arithmetic, it was in which rows a later query can still find.
void main() {
  late AppDatabase db;
  late NutritionRepository repository;

  setUp(() {
    db = AppDatabase.test(NativeDatabase.memory());
    repository = NutritionRepository(db);
  });
  tearDown(() => db.close());

  final day = DateTime(2026, 8, 21);

  Future<FoodItemData> addFood(String name, {String? serverId}) async {
    final id = await db
        .into(db.foodItem)
        .insert(
          FoodItemCompanion.insert(
            name: name,
            calories: 100,
            protein: 10,
            carbs: 20,
            fat: 5,
            serverId: Value(serverId),
          ),
        );
    return (await db.foodItemDao.getFoodItemById(id))!;
  }

  Future<MealTableData> theMeal() async =>
      (await db.mealDao.getMealsForDate(day)).single;

  /// Puts the day's meal in the state it is in after a successful sync: it has a
  /// server id, its entries have theirs, and nothing is pending.
  Future<void> pretendItSynced() async {
    final meal = await theMeal();
    await db.mealDao.markMealSynced(localId: meal.id, serverId: 'srv-meal');
    var i = 0;
    for (final entry in await db.mealDao.getFoodItemsForMeal(meal.id)) {
      await db.mealDao.setFoodEntryServerId(entry.id, 'srv-entry-${i++}');
    }
  }

  test('a food added to a synced meal puts it back in the sync queue', () async {
    final oats = await addFood('Oats', serverId: 'srv-oats');
    await repository.addFoodToMeal('Breakfast', oats, date: day);
    await pretendItSynced();

    final coffee = await addFood('Coffee', serverId: 'srv-coffee');
    await repository.addFoodToMeal('Breakfast', coffee, date: day);

    // Before this, the meal stayed `synced`, getUnsyncedMeals() skipped it, and
    // the coffee never left the phone.
    expect((await theMeal()).syncStatus, MealSyncStatus.pendingUpdate.index);
    expect(await db.mealDao.getUnsyncedMeals(), isNotEmpty);
  });

  test('a food added to a meal that has never synced leaves it pending', () async {
    final oats = await addFood('Oats', serverId: 'srv-oats');
    await repository.addFoodToMeal('Breakfast', oats, date: day);

    // `pending` means "create this meal"; promoting it to `pendingUpdate` would
    // send a PUT to a meal the server doesn't have yet.
    expect((await theMeal()).syncStatus, MealSyncStatus.pending.index);
  });

  test('removing a pushed food queues the deletion and re-queues the meal', () async {
    final oats = await addFood('Oats', serverId: 'srv-oats');
    await repository.addFoodToMeal('Breakfast', oats, date: day);
    await pretendItSynced();

    await repository.removeFoodFromMeal('Breakfast', oats, date: day);

    final queued = await db.mealDao.getPendingFoodEntryDeletions();
    expect(queued.single.mealServerId, 'srv-meal');
    expect(queued.single.foodItemServerId, 'srv-oats');
    expect((await theMeal()).syncStatus, MealSyncStatus.pendingUpdate.index);
    expect(await db.mealDao.getFoodItemsForMeal((await theMeal()).id), isEmpty);
  });

  test('two portions of one food take two deletions', () async {
    // The API's delete route removes a single matching entry per call, so one
    // tombstone would leave the second portion on the server.
    final oats = await addFood('Oats', serverId: 'srv-oats');
    await repository.addFoodToMeal('Breakfast', oats, date: day);
    await repository.addFoodToMeal('Breakfast', oats, date: day);
    await pretendItSynced();

    await repository.removeFoodFromMeal('Breakfast', oats, date: day);

    expect(await db.mealDao.getPendingFoodEntryDeletions(), hasLength(2));
  });

  test('removing a food the server never saw queues nothing', () async {
    final oats = await addFood('Oats', serverId: 'srv-oats');
    await repository.addFoodToMeal('Breakfast', oats, date: day);

    await repository.removeFoodFromMeal('Breakfast', oats, date: day);

    // The meal has no server id, so there is nothing to delete there — and a
    // tombstone naming a meal that doesn't exist would 404 forever.
    expect(await db.mealDao.getPendingFoodEntryDeletions(), isEmpty);
  });

  test('logging out clears queued deletions', () async {
    final oats = await addFood('Oats', serverId: 'srv-oats');
    await repository.addFoodToMeal('Breakfast', oats, date: day);
    await pretendItSynced();
    await repository.removeFoodFromMeal('Breakfast', oats, date: day);

    await db.clearAllUserData();

    // They name one account's meals; the next user must not push them.
    expect(await db.mealDao.getPendingFoodEntryDeletions(), isEmpty);
  });
}
