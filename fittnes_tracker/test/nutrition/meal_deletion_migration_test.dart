import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/app_database.dart';

/// The upgrade path for `meal_food_deletion_table`.
///
/// A fresh `NativeDatabase.memory()` always takes drift's `onCreate` branch, and
/// `onCreate` calls `createAll()` — so a missing `schemaVersion` bump is
/// structurally invisible: every other test passes, every fresh install works,
/// and every device that already had the app is broken. `chat_out_box_table`
/// shipped exactly that way (see `test/chat/chat_outbox_migration_test.dart`).
///
/// Here the cost of repeating that mistake is a crash on a path that used to
/// work: removing a food from a meal now writes a tombstone first, so an
/// upgraded install with no such table would throw where it previously just
/// deleted the row.
///
/// So this uses a **file**: `user_version` is a property of a database that
/// persists across opens, and standing in for "a device that has had this app
/// for months" needs one that survives being closed.
void main() {
  late Directory tempDir;
  late File file;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('forgeform_meal_migration');
    file = File('${tempDir.path}/app.sqlite');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  /// Leaves [file] as an install from before the tombstone table: everything
  /// else present, no `meal_food_deletion_table`, and a `user_version` from
  /// before it was added.
  Future<void> givenAnInstallFromBeforeTheTombstones({
    Future<void> Function(AppDatabase db)? seed,
  }) async {
    final old = AppDatabase.test(NativeDatabase(file));
    // Nothing is opened or built until a statement actually runs.
    await old.customStatement('SELECT 1');
    if (seed != null) await seed(old);

    await old.customStatement('DROP TABLE IF EXISTS meal_food_deletion_table');
    await old.customStatement('PRAGMA user_version = 37');
    await old.close();
  }

  test('an install from before the tombstones can queue a deletion', () async {
    await givenAnInstallFromBeforeTheTombstones();

    final db = AppDatabase.test(NativeDatabase(file));
    addTearDown(db.close);

    // The exact call `removeFoodFromMeal` makes; without the bump it throws
    // "no such table: meal_food_deletion_table" and takes food removal with it.
    await db.mealDao.queueFoodEntryDeletion(
      mealServerId: 'srv-meal',
      foodItemServerId: 'srv-oats',
    );

    final queued = await db.mealDao.getPendingFoodEntryDeletions();
    expect(queued.single.foodItemServerId, 'srv-oats');
  });

  test('the upgrade leaves the meals already logged alone', () async {
    await givenAnInstallFromBeforeTheTombstones(
      seed:
          (old) => old.mealDao.insertMeal(
            MealTableCompanion(
              date: Value(DateTime(2026, 8, 21)),
              category: const Value('Breakfast'),
              foodItemId: const Value(1),
            ),
          ),
    );

    final db = AppDatabase.test(NativeDatabase(file));
    addTearDown(db.close);

    // createAll() in onUpgrade emits CREATE TABLE IF NOT EXISTS: it adds what is
    // missing without touching what is there, which is what makes the version
    // bump a complete migration rather than data loss.
    final meals = await db.mealDao.getMealsForDate(DateTime(2026, 8, 21));
    expect(meals.single.category, 'Breakfast');
  });

  test('schemaVersion stays ahead of the version without the tombstones', () async {
    // A guard on the fix itself: dropping back to 37 or below silently
    // reintroduces the crash for every existing install while leaving fresh
    // installs and this whole suite green.
    final db = AppDatabase.test(NativeDatabase.memory());
    addTearDown(db.close);

    expect(db.schemaVersion, greaterThan(37));
  });
}
