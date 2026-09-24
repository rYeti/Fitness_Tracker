import 'dart:io';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/dao/meal_template_dao.dart';
import 'package:ForgeForm/core/sync/sync_service.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout_exercise.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

/// Part two of the sync rework — the device mints every row's id. See
/// `docs/sync-architecture.md`, part two.
///
/// Each test was run against the code before the change, or with the one fix
/// it pins reverted, and failed there.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeApiClient api;
  late SyncService sync;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SyncService.resetForTesting();
    db = AppDatabase.test(NativeDatabase.memory());
    api = FakeApiClient()..stubEmptyPull();
    sync = SyncService(
      db: db,
      apiClient: api,
      mealTemplateDao: MealTemplateDao(db),
    );
  });

  tearDown(() => db.close());

  final uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  Future<int> statusOf(TableInfo table, int id) async => (await db
          .customSelect(
            'SELECT sync_status FROM ${table.actualTableName} WHERE id = ?',
            variables: [Variable.withInt(id)],
          )
          .getSingle())
      .read<int>('sync_status');

  Future<String?> serverIdOf(TableInfo table, int id) async => (await db
          .customSelect(
            'SELECT server_id FROM ${table.actualTableName} WHERE id = ?',
            variables: [Variable.withInt(id)],
          )
          .getSingle())
      .read<String?>('server_id');

  /// A food the server has, as the pull would have stored it.
  Future<int> syncedFood(String serverId, {String name = 'Oats'}) =>
      db.untracked(
        () => db
            .into(db.foodItem)
            .insert(
              FoodItemCompanion.insert(
                name: name,
                calories: 100,
                protein: 5,
                carbs: 10,
                fat: 2,
                serverId: Value(serverId),
                syncStatus: const Value(1),
              ),
            ),
      );

  /// A meal the server has, as the pull would have stored it.
  Future<int> syncedMeal(String serverId, int foodId) => db.untracked(
    () => db
        .into(db.mealTable)
        .insert(
          MealTableCompanion.insert(
            date: DateTime(2026, 1, 5),
            category: 'Breakfast',
            foodItemId: foodId,
            serverId: Value(serverId),
            syncStatus: const Value(1),
          ),
        ),
  );

  // ── Identity from the moment a row exists ────────────────────────────────

  group('a row made on this device', () {
    test('has its global id from the moment it is inserted', () async {
      final id = await db.workoutDao.saveCompleteWorkout(
        Workout(name: 'Push Day', difficulty: WorkoutDifficulty.beginner),
      );

      final serverId = await serverIdOf(db.workoutTable, id);
      expect(serverId, matches(uuid));
      // Having an id no longer means the server has it.
      expect(await statusOf(db.workoutTable, id), SyncStatus.pending.index);
    });

    test('is created under that id, and a retry after a lost response sends '
        'the same one', () async {
      final id = await db.foodItemDao.insertFoodItem(
        FoodItemCompanion.insert(
          name: 'Skyr',
          calories: 63,
          protein: 11,
          carbs: 4,
          fat: 0,
        ),
      );
      final minted = await serverIdOf(db.foodItem, id);
      // The server stores the first POST; its answer never arrives.
      api.postsLosingResponse.add('api/FoodItem');

      await sync.syncAll();
      expect(await statusOf(db.foodItem, id), SyncStatus.pending.index);
      await sync.syncAll();

      final sent = api.posts.where((p) => p.path == 'api/FoodItem').toList();
      expect(sent, hasLength(2));
      // Both attempts carry the id minted at insert, so the server can answer
      // the second with the row the first made instead of making another.
      expect(sent.map((p) => (p.data as Map)['id']), [minted, minted]);
      expect(await serverIdOf(db.foodItem, id), minted);
      expect(await statusOf(db.foodItem, id), SyncStatus.synced.index);
    });

    test('whose id the server refuses (409) gets a fresh one and is created '
        'under it next time', () async {
      final id = await db.weightRecordDao.addWeightRecord(
        WeightRecordCompanion.insert(date: DateTime(2026, 1, 5), weight: 81.4),
      );
      final refused = await serverIdOf(db.weightRecord, id);
      api.postStatuses['api/WeightTracking/TrackWeight'] = 409;

      await sync.syncAll();

      final fresh = await serverIdOf(db.weightRecord, id);
      expect(fresh, matches(uuid));
      expect(fresh, isNot(refused));
      expect(await statusOf(db.weightRecord, id), SyncStatus.pending.index);

      api.postStatuses.clear();
      await sync.syncAll();
      final last = api.posts.lastWhere(
        (p) => p.path == 'api/WeightTracking/TrackWeight',
      );
      expect((last.data as Map)['id'], fresh);
      expect(await statusOf(db.weightRecord, id), SyncStatus.synced.index);
    });

    test('is not referred to by id until the server has it', () async {
      // A workout exercise of a custom exercise that hasn't been pushed. Its
      // id exists on this device only; sending it would point the server's
      // entry at nothing.
      final exerciseId = await db.exerciseDao.saveExercise(
        ExerciseTableCompanion.insert(
          name: 'Sissy Squat',
          type: 0,
          targetMuscleGroups: '0',
          isCustom: const Value(true),
        ),
      );
      api.postStatuses['api/Exercise/UserExercise'] = 500;
      final workoutId = await db.workoutDao.saveCompleteWorkout(
        Workout(
          name: 'Legs',
          difficulty: WorkoutDifficulty.beginner,
          exercises: [
            WorkoutExercise(
              workoutId: 0,
              exerciseId: exerciseId,
              orderPosition: 0,
            ),
          ],
        ),
      );

      await sync.syncAll();

      final workoutServerId = await serverIdOf(db.workoutTable, workoutId);
      expect(
        api.posts.map((p) => p.path),
        isNot(contains('api/Workout/$workoutServerId/exercises/batch')),
      );
      final we = await db.workoutDao.getExercisesForWorkoutRaw(workoutId);
      expect(we.single.syncStatus, SyncStatus.pending.index);
    });
  });

  // ── Deleting ──────────────────────────────────────────────────────────────

  group('deleting a row', () {
    test('the server never had records no DELETE for it', () async {
      final unpushed = await db.weightRecordDao.addWeightRecord(
        WeightRecordCompanion.insert(date: DateTime(2026, 1, 5), weight: 80),
      );
      final pushed = await db.untracked(
        () => db.weightRecordDao.addWeightRecord(
          WeightRecordCompanion.insert(
            date: DateTime(2026, 1, 6),
            weight: 81,
            serverId: const Value('server-wt1'),
            syncStatus: const Value(1),
          ),
        ),
      );

      await db.weightRecordDao.deleteWeightRecord(unpushed);
      await db.weightRecordDao.deleteWeightRecord(pushed);

      final recorded = await db.select(db.syncDeletionTable).get();
      expect(recorded.map((d) => d.serverId), ['server-wt1']);
    });
  });

  // ── A meal's foods, sent as the whole list ───────────────────────────────

  group('a meal\'s foods', () {
    test('two portions of one food are told apart by their ids', () async {
      final food = await syncedFood('server-f1');
      final meal = await syncedMeal('server-m1', food);
      await db.untracked(() async {
        await db.mealDao.addFoodToMeal(food, meal, 'server-entry1');
        await db.mealDao.addFoodToMeal(food, meal, 'server-entry2');
      });

      // Take out the second portion only.
      await (db.delete(db.mealFoodTable)
        ..where((t) => t.serverId.equals('server-entry2'))).go();
      await sync.syncAll();

      // A DELETE addressed by meal and food item can't say which portion.
      expect(api.deletes, isEmpty);
      expect(
        api.puts.singleWhere((p) => p.path == 'api/Meal/server-m1/foods').data,
        [
          {'id': 'server-entry1', 'foodItemId': 'server-f1'},
        ],
      );
    });

    test('a new meal the server already had for that day keeps the foods on '
        'both', () async {
      final oats = await syncedFood('server-f1');
      final skyr = await syncedFood('server-f2', name: 'Skyr');
      // This device logs oats for a breakfast another device already logged
      // skyr for.
      final meal = await db.mealDao.insertMeal(
        MealTableCompanion.insert(
          date: DateTime(2026, 1, 5),
          category: 'Breakfast',
          foodItemId: oats,
        ),
      );
      await db.mealDao.addFoodToMeal(oats, meal);
      final oatsEntry =
          (await db.mealDao.getAllFoodEntriesForMeal(meal)).single.serverId;
      api.postResponses['api/Meal'] = serverMeal(
        id: 'server-m9',
        foodItemId: 'server-f2',
        foodEntries: [
          serverFoodEntry(id: 'server-entry9', foodItemId: 'server-f2'),
        ],
      );

      await sync.syncAll();

      expect(await serverIdOf(db.mealTable, meal), 'server-m9');
      final entries = await db.mealDao.getAllFoodEntriesForMeal(meal);
      expect(entries.map((e) => e.foodEntryId).toSet(), {oats, skyr});
      final put = api.puts.singleWhere(
        (p) => p.path == 'api/Meal/server-m9/foods',
      );
      expect((put.data as List).map((e) => (e as Map)['id']).toSet(), {
        oatsEntry,
        'server-entry9',
      }, reason: 'the whole list, so the other device\'s skyr must be in it');
      expect(await statusOf(db.mealTable, meal), SyncStatus.synced.index);
    });

    test('a food not on the server yet leaves the meal to go again', () async {
      final oats = await syncedFood('server-f1');
      final meal = await syncedMeal('server-m1', oats);
      final newFood = await db.foodItemDao.insertFoodItem(
        FoodItemCompanion.insert(
          name: 'Blueberries',
          calories: 57,
          protein: 1,
          carbs: 14,
          fat: 0,
        ),
      );
      api.postStatuses['api/FoodItem'] = 500;
      await db.mealDao.addFoodToMeal(newFood, meal);

      await sync.syncAll();

      expect(
        api.puts.singleWhere((p) => p.path == 'api/Meal/server-m1/foods').data,
        isEmpty,
      );
      expect(
        await statusOf(db.mealTable, meal),
        SyncStatus.pendingUpdate.index,
      );
    });

    test('a clean meal takes the server\'s list on pull, a dirty one keeps '
        'its own', () async {
      final oats = await syncedFood('server-f1');
      final clean = await syncedMeal('server-m1', oats);
      final dirty = await db.untracked(
        () => db
            .into(db.mealTable)
            .insert(
              MealTableCompanion.insert(
                date: DateTime(2026, 1, 6),
                category: 'Lunch',
                foodItemId: oats,
                serverId: const Value('server-m2'),
                syncStatus: const Value(1),
              ),
            ),
      );
      await db.untracked(() async {
        await db.mealDao.addFoodToMeal(oats, clean, 'server-entry1');
        await db.mealDao.addFoodToMeal(oats, dirty, 'server-entry2');
      });
      // A second portion, logged here and not yet sent.
      await db.mealDao.addFoodToMeal(oats, dirty);

      // Another device removed the oats from both meals.
      api.getResponses['api/FoodItem'] = [
        serverFoodItem(id: 'server-f1', name: 'Oats'),
      ];
      api.getResponses['api/Meal/all'] = [
        serverMeal(id: 'server-m1', foodItemId: 'server-f1'),
        serverMeal(
          id: 'server-m2',
          foodItemId: 'server-f1',
          date: '2026-01-06T00:00:00Z',
          category: 'Lunch',
        ),
      ];
      await sync.pullAll();

      // Left here, the next edit to the meal would have sent it back up.
      expect(await db.mealDao.getAllFoodEntriesForMeal(clean), isEmpty);
      expect(await db.mealDao.getAllFoodEntriesForMeal(dirty), hasLength(2));
    });

    test('a meal this device hasn\'t pushed is adopted by the pull, keeping '
        'its foods and gaining the server\'s', () async {
      final oats = await syncedFood('server-f1');
      final skyr = await syncedFood('server-f2', name: 'Skyr');
      final local = await db.mealDao.insertMeal(
        MealTableCompanion.insert(
          date: DateTime(2026, 1, 5),
          category: 'Breakfast',
          foodItemId: oats,
        ),
      );
      await db.mealDao.addFoodToMeal(oats, local);
      api.getResponses['api/FoodItem'] = [
        serverFoodItem(id: 'server-f1', name: 'Oats'),
        serverFoodItem(id: 'server-f2', name: 'Skyr'),
      ];
      api.getResponses['api/Meal/all'] = [
        serverMeal(
          id: 'server-m9',
          foodItemId: 'server-f2',
          date: DateTime(2026, 1, 5).toUtc().toIso8601String(),
          category: 'Breakfast',
          foodEntries: [
            serverFoodEntry(id: 'server-entry9', foodItemId: 'server-f2'),
          ],
        ),
      ];

      await sync.pullAll();

      final meals = await db.select(db.mealTable).get();
      expect(meals, hasLength(1));
      expect(meals.single.serverId, 'server-m9');
      expect(meals.single.syncStatus, SyncStatus.pendingUpdate.index);
      expect(
        (await db.mealDao.getAllFoodEntriesForMeal(
          local,
        )).map((e) => e.foodEntryId).toSet(),
        {oats, skyr},
      );
    });
  });

  // ── A plan's workouts, sent as the whole list ────────────────────────────

  group('a plan\'s workouts', () {
    Future<({int plan, int upper, int lower})> seedPlan() =>
        db.untracked(() async {
          final plan = await db
              .into(db.workoutPlanTable)
              .insert(
                WorkoutPlanTableCompanion.insert(
                  name: 'Block 1',
                  startDate: DateTime(2026, 1, 5),
                  cyclePatternJson: '[]',
                  serverId: const Value('server-p1'),
                  syncStatus: const Value(1),
                ),
              );
          Future<int> workout(String name, String serverId) => db
              .into(db.workoutTable)
              .insert(
                WorkoutTableCompanion.insert(
                  name: name,
                  difficulty: 0,
                  serverId: Value(serverId),
                  syncStatus: const Value(1),
                ),
              );
          final upper = await workout('Upper', 'server-w1');
          final lower = await workout('Lower', 'server-w2');
          for (final w in [upper, lower]) {
            await db
                .into(db.workoutPlanWorkoutTable)
                .insert(
                  WorkoutPlanWorkoutTableCompanion.insert(
                    planId: plan,
                    workoutId: w,
                    syncStatus: const Value(1),
                  ),
                );
          }
          return (plan: plan, upper: upper, lower: lower);
        });

    test(
      'a removed one goes as the list without it, not as a DELETE',
      () async {
        final ids = await seedPlan();

        await (db.delete(db.workoutPlanWorkoutTable)
          ..where((l) => l.workoutId.equals(ids.lower))).go();
        await sync.syncAll();

        expect(api.deletes, isEmpty);
        expect(await db.select(db.syncDeletionTable).get(), isEmpty);
        expect(
          api.puts
              .singleWhere(
                (p) => p.path == 'api/WorkoutPlan/server-p1/workouts',
              )
              .data,
          ['server-w1'],
        );
        expect(await statusOf(db.workoutPlanTable, ids.plan), 1);
      },
    );

    test('a clean plan takes the server\'s list on pull', () async {
      final ids = await seedPlan();
      api.getResponses['api/Workout'] = [
        serverWorkout(id: 'server-w1', name: 'Upper'),
        serverWorkout(id: 'server-w2', name: 'Lower'),
      ];
      api.getResponses['api/WorkoutPlan'] = [
        {
          'id': 'server-p1',
          'name': 'Block 1',
          'description': null,
          'startDate': '2026-01-05T00:00:00Z',
          'createdAt': '2026-01-05T00:00:00Z',
          'isActive': true,
          'cyclePatternJson': '[]',
          'isFreeChoice': false,
          'durationDays': null,
          // Lower was taken out of the plan elsewhere.
          'workoutIds': ['server-w1'],
        },
      ];

      await sync.pullAll();

      final links = await db.workoutPlanDao.getPlanWorkoutsForPlan(ids.plan);
      expect(links.map((l) => l.workoutId), [ids.upper]);
    });
  });

  // ── Meal templates, in SharedPreferences ─────────────────────────────────

  group('a meal template', () {
    test('is created under the id minted when it was made', () async {
      final dao = MealTemplateDao(db);
      final id = await dao.insertTemplate({
        'name': 'Overnight oats',
        'category': 'Breakfast',
        'items': <dynamic>[],
      });
      final minted =
          (await dao.getAllTemplates()).singleWhere(
                (t) => t['id'] == id,
              )['serverId']
              as String;
      expect(minted, matches(uuid));
      // Edited before it ever reached the server: still a create, not a PUT.
      await dao.updateTemplate({
        'name': 'Overnight oats (big)',
        'category': 'Breakfast',
      }, id);

      await sync.syncAll();

      expect(
        api.puts.where((p) => p.path.startsWith('api/MealTemplate')),
        isEmpty,
      );
      final post = api.posts.singleWhere((p) => p.path == 'api/MealTemplate');
      expect((post.data as Map)['id'], minted);
      expect((post.data as Map)['name'], 'Overnight oats (big)');
      expect(await MealTemplateDao.hasPendingSync(), isFalse);
    });

    test('deleted before it was pushed tells the server nothing', () async {
      final dao = MealTemplateDao(db);
      final id = await dao.insertTemplate({
        'name': 'Chili',
        'category': 'Dinner',
        'items': <dynamic>[],
      });

      await dao.deleteTemplate(id);

      expect(await dao.getDeletedServerIds(), isEmpty);
      expect(await MealTemplateDao.hasPendingSync(), isFalse);
    });
  });

  // ── Upgrading an install ──────────────────────────────────────────────────

  group('an install upgraded from schema 41', () {
    late Directory tempDir;
    late File file;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('forgeform_client_ids');
      file = File('${tempDir.path}/app.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    /// A version-41 install: rows made before the device minted ids, with
    /// `server_id` null wherever the server hadn't answered yet.
    Future<void> givenAnInstallAt41() async {
      final old = AppDatabase.test(NativeDatabase(file));
      await old.customStatement('SELECT 1');
      for (final sql in [
        "INSERT INTO exercise_table (id, name, type, target_muscle_groups, is_custom) "
            "VALUES (1, 'Bench Press', 0, '0', 0)",
        "INSERT INTO exercise_table (id, name, type, target_muscle_groups, is_custom, sync_status) "
            "VALUES (2, 'Sissy Squat', 0, '0', 1, 0)",
        // Never pushed, but marked edited by a build that did that by hand.
        "INSERT INTO workout_table (id, name, difficulty, sync_status) VALUES (1, 'Push', 0, 2)",
        "INSERT INTO workout_table (id, name, difficulty, sync_status) VALUES (2, 'Pull', 0, 0)",
        "INSERT INTO workout_table (id, name, difficulty, server_id, sync_status) "
            "VALUES (3, 'Legs', 0, 'server-w3', 1)",
        "INSERT INTO food_item (id, name, calories, protein, carbs, fat, server_id, sync_status) "
            "VALUES (1, 'Oats', 100, 5, 10, 2, 'server-f1', 1)",
        // A synced meal whose second food never reached the server.
        "INSERT INTO meal_table (id, date, category, food_item_id, server_id, sync_status) "
            "VALUES (1, 0, 'Breakfast', 1, 'server-m1', 1)",
        "INSERT INTO meal_food_table (meal_id, food_entry_id, server_id) VALUES (1, 1, 'server-e1')",
        'INSERT INTO meal_food_table (meal_id, food_entry_id) VALUES (1, 1)',
        // A synced plan holding a link that was never sent.
        "INSERT INTO workout_plan_table (id, name, start_date, created_at, cycle_pattern_json, server_id, sync_status) "
            "VALUES (1, 'Block 1', 0, 0, '[]', 'server-p1', 1)",
        'INSERT INTO workout_plan_workout_table (plan_id, workout_id, sync_status) VALUES (1, 3, 0)',
      ]) {
        await old.customStatement(sql);
      }
      await old.customStatement('PRAGMA user_version = 41');
      await old.close();
    }

    test(
      'gives every row an id and moves "never pushed" to the status',
      () async {
        await givenAnInstallAt41();

        final db = AppDatabase.test(NativeDatabase(file));
        addTearDown(db.close);

        final workouts = {
          for (final w in await db.select(db.workoutTable).get()) w.id: w,
        };
        expect(workouts[1]!.serverId, matches(uuid));
        expect(workouts[2]!.serverId, matches(uuid));
        expect(workouts[1]!.serverId, isNot(workouts[2]!.serverId));
        expect(workouts[3]!.serverId, 'server-w3');
        expect(workouts[1]!.syncStatus, SyncStatus.pending.index);
        expect(workouts[3]!.syncStatus, SyncStatus.synced.index);

        final exercises = {
          for (final e in await db.select(db.exerciseTable).get()) e.id: e,
        };
        // The built-in one is the server's row, linked later by name.
        expect(exercises[1]!.serverId, isNull);
        expect(exercises[2]!.serverId, matches(uuid));

        final entries = await db.select(db.mealFoodTable).get();
        expect(entries.every((e) => e.serverId != null), isTrue);
        expect(
          (await db.select(db.mealTable).getSingle()).syncStatus,
          SyncStatus.pendingUpdate.index,
          reason: 'its list goes up whole now, with the food that never went',
        );
        expect(
          (await db.select(db.workoutPlanTable).getSingle()).syncStatus,
          SyncStatus.pendingUpdate.index,
        );

        // Deleting the never-pushed workout is the end of it; the synced one
        // is recorded for the server.
        await db.customStatement(
          'DELETE FROM workout_table WHERE id IN (2, 3)',
        );
        final recorded = await db.select(db.syncDeletionTable).get();
        expect(recorded.map((d) => d.serverId), ['server-w3']);
      },
    );
  });
}
