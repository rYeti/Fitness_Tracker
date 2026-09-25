import 'dart:io';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/dao/meal_template_dao.dart';
import 'package:ForgeForm/core/sync/sync_service.dart';
import 'package:ForgeForm/feature/weight_tracking/data/repositories/weight_repository.dart';
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
    const weights = 'api/WeightTracking/TrackWeight';

    test('records a DELETE for any row with an id, pushed or not', () async {
      final unpushed = await db.weightRecordDao.addWeightRecord(
        WeightRecordCompanion.insert(date: DateTime(2026, 1, 5), weight: 80),
      );
      final minted = await serverIdOf(db.weightRecord, unpushed);
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
      // A built-in exercise is the server's row, with no id until it is
      // linked by name; it is never the user's to delete there.
      final builtIn = await db
          .into(db.exerciseTable)
          .insert(
            ExerciseTableCompanion.insert(
              name: 'Bench Press',
              type: 0,
              targetMuscleGroups: '0',
              serverId: const Value(null),
            ),
          );

      await db.weightRecordDao.deleteWeightRecord(unpushed);
      await db.weightRecordDao.deleteWeightRecord(pushed);
      await db.exerciseDao.deleteExercise(builtIn);

      // "Pending" says the device never heard back, not that the server never
      // got it — a lost answer looks the same.
      final recorded = await db.select(db.syncDeletionTable).get();
      expect(recorded.map((d) => d.serverId), [minted, 'server-wt1']);
    });

    test('whose create reached the server but whose answer was lost is '
        'deleted there too, and not brought back', () async {
      final weightsRepo = WeightRepository(db);
      final id = await weightsRepo.addWeightRecord(
        date: DateTime(2026, 1, 5),
        weight: 80.4,
      );
      final minted = (await serverIdOf(db.weightRecord, id))!;
      // The server stores the POST; its answer never arrives.
      api.postsLosingResponse.add(weights);
      await sync.syncAll();
      expect(await statusOf(db.weightRecord, id), SyncStatus.pending.index);

      // Deleted before the next push, through the screen's own path: to this
      // device, a record the server never confirmed.
      await weightsRepo.deleteWeightRecord(id);
      await sync.syncAll();

      expect(api.deletes, ['$weights/$minted']);
      expect(
        api.posts.where((p) => p.path == weights),
        hasLength(1),
        reason: 'nothing is left to create',
      );
      expect(await db.select(db.syncDeletionTable).get(), isEmpty);

      // The server lists the record for as long as no DELETE has reached it.
      api.changes['weights'] = [
        if (!api.deletes.contains('$weights/$minted'))
          {
            'id': minted,
            'date': '2026-01-05T00:00:00Z',
            'weight': 80.4,
            'note': null,
          },
      ];
      await sync.pullAll();
      expect(await db.select(db.weightRecord).get(), isEmpty);
    });

    test('that was never sent costs one DELETE, which a 404 settles', () async {
      final weightsRepo = WeightRepository(db);
      final id = await weightsRepo.addWeightRecord(
        date: DateTime(2026, 1, 5),
        weight: 80.4,
      );
      final minted = (await serverIdOf(db.weightRecord, id))!;
      await weightsRepo.deleteWeightRecord(id);
      api.deleteStatuses['$weights/$minted'] = 404;

      await sync.syncAll();
      await sync.syncAll();

      expect(api.deletes, ['$weights/$minted']);
      expect(api.posts.where((p) => p.path == weights), isEmpty);
      expect(await db.select(db.syncDeletionTable).get(), isEmpty);
    });

    // The sync engine's own deletes are not the user's. Before the condition
    // above lost its status test, a row still pending recorded nothing however
    // it was deleted; now only `untracked` stands between these and a DELETE.

    test('a local row folded into another holding the same id records no '
        'DELETE for it', () async {
      final oats = await syncedFood('server-f1');
      final kept = await syncedMeal('server-m1', oats);
      // A second row the device holds for the server's meal, not yet pushed.
      await db.mealDao.insertMeal(
        MealTableCompanion.insert(
          date: DateTime(2026, 1, 5),
          category: 'Breakfast',
          foodItemId: oats,
          serverId: const Value('server-m1'),
        ),
      );

      await sync.syncAll();

      expect((await db.select(db.mealTable).get()).map((m) => m.id), [kept]);
      // It is the server's live meal: a DELETE for it would take that too.
      expect(api.deletes, isEmpty);
      expect(await db.select(db.syncDeletionTable).get(), isEmpty);
    });

    test('a new meal the server answers with one already here records no '
        'DELETE when it moves into it', () async {
      final oats = await syncedFood('server-f1');
      final skyr = await syncedFood('server-f2', name: 'Skyr');
      final held = await syncedMeal('server-m9', skyr);
      await db.untracked(
        () => db.mealDao.addFoodToMeal(skyr, held, 'server-entry9'),
      );
      // A second breakfast for the same day, made here and not yet pushed. The
      // server keeps one per day, so its create is answered with the one this
      // device already holds.
      final fresh = await db.mealDao.insertMeal(
        MealTableCompanion.insert(
          date: DateTime(2026, 1, 5),
          category: 'Breakfast',
          foodItemId: oats,
        ),
      );
      await db.mealDao.addFoodToMeal(oats, fresh);
      api.postResponses['api/Meal'] = serverMeal(
        id: 'server-m9',
        foodItemId: 'server-f2',
        foodEntries: [
          serverFoodEntry(id: 'server-entry9', foodItemId: 'server-f2'),
        ],
      );

      await sync.syncAll();
      await sync.syncAll();

      expect((await db.select(db.mealTable).get()).map((m) => m.id), [held]);
      expect(
        (await db.mealDao.getAllFoodEntriesForMeal(
          held,
        )).map((e) => e.foodEntryId).toSet(),
        {oats, skyr},
      );
      expect(api.deletes, isEmpty);
      expect(await db.select(db.syncDeletionTable).get(), isEmpty);
    });
  });

  // ── A meal's foods, upserted by id ──────────────────────────────────────

  group('a meal\'s foods', () {
    const batch = 'api/Meal/server-m1/foods/batch';

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

      // A DELETE addressed by meal and food item couldn't say which portion;
      // one addressed by the entry's id can.
      expect(api.deletes, ['api/Meal/server-m1/foods/server-entry2']);
      expect(api.puts, isEmpty);
      expect(await statusOf(db.mealTable, meal), SyncStatus.synced.index);
    });

    test('an edit sends only this device\'s foods, and none of them as a '
        'list that could leave another device\'s out', () async {
      final oats = await syncedFood('server-f1');
      final meal = await syncedMeal('server-m1', oats);
      await db.untracked(
        () => db.mealDao.addFoodToMeal(oats, meal, 'server-entry1'),
      );
      // Another device has since added skyr to this meal, made from a food
      // this device has never pulled. And this device added blueberries.
      final blueberries = await syncedFood('server-f3', name: 'Blueberries');
      await db.mealDao.addFoodToMeal(blueberries, meal);
      final added =
          (await db.mealDao.getAllFoodEntriesForMeal(
            meal,
          )).singleWhere((e) => e.foodEntryId == blueberries).serverId;

      await sync.syncAll();

      // Upserted by id: nothing in the request can remove what it doesn't
      // name. The whole-list PUT it replaced deleted the skyr.
      expect(api.puts.where((p) => p.path.endsWith('/foods')), isEmpty);
      expect(api.deletes, isEmpty);
      expect(api.posts.singleWhere((p) => p.path == batch).data, [
        {'id': 'server-entry1', 'foodItemId': 'server-f1'},
        {'id': added, 'foodItemId': 'server-f3'},
      ]);
      expect(await statusOf(db.mealTable, meal), SyncStatus.synced.index);
    });

    test('a new meal the server already had for that day sends only its own '
        'foods to it, and is on the server from then on', () async {
      final oats = await syncedFood('server-f1');
      // This device logs oats for a breakfast another device already logged
      // skyr for — from a food it created just now, which this device can't
      // resolve.
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
        foodItemId: 'server-f-new',
        foodEntries: [
          serverFoodEntry(id: 'server-entry9', foodItemId: 'server-f-new'),
        ],
      );
      // The foods fail to go the first time.
      api.postStatuses['api/Meal/server-m9/foods/batch'] = 500;

      await sync.syncAll();

      expect(await serverIdOf(db.mealTable, meal), 'server-m9');
      // The server has it now: not `pending`, whatever became of its foods.
      expect(
        await statusOf(db.mealTable, meal),
        SyncStatus.pendingUpdate.index,
      );

      api.postStatuses.clear();
      await sync.syncAll();

      expect(
        api.posts.where((p) => p.path == 'api/Meal'),
        hasLength(1),
        reason: 'on the server since the first answer; never created again',
      );
      expect(
        api.posts.lastWhere((p) => p.path == 'api/Meal/server-m9/foods/batch').data,
        [
          {'id': oatsEntry, 'foodItemId': 'server-f1'},
        ],
      );
      expect(api.puts.where((p) => p.path.endsWith('/foods')), isEmpty);
      expect(api.deletes, isEmpty);
      // The server answered with its meal as it was, so this device's fields
      // went up afterwards, as an update.
      expect(api.puts.map((p) => p.path), contains('api/Meal/server-m9'));
      expect(await statusOf(db.mealTable, meal), SyncStatus.synced.index);
    });

    test('a new meal answered with another stays changed, so its own fields '
        'follow as an update', () async {
      final oats = await syncedFood('server-f1');
      final meal = await db.mealDao.insertMeal(
        MealTableCompanion.insert(
          date: DateTime(2026, 1, 5),
          category: 'Breakfast',
          foodItemId: oats,
        ),
      );
      await db.mealDao.addFoodToMeal(oats, meal);
      api.postResponses['api/Meal'] = serverMeal(
        id: 'server-m9',
        foodItemId: 'server-f2',
      );

      await sync.syncAll();

      expect(
        await statusOf(db.mealTable, meal),
        SyncStatus.pendingUpdate.index,
        reason: 'the server answered with its meal as it was',
      );
      await sync.syncAll();
      final put = api.puts.singleWhere((p) => p.path == 'api/Meal/server-m9');
      expect((put.data as Map)['foodItemId'], 'server-f1');
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

      expect(api.posts.where((p) => p.path == batch), isEmpty);
      expect(
        await statusOf(db.mealTable, meal),
        SyncStatus.pendingUpdate.index,
      );
    });

    test('a food whose row is gone from this device is neither sent nor '
        'deleted', () async {
      final oats = await syncedFood('server-f1');
      final meal = await syncedMeal('server-m1', oats);
      await db.untracked(() async {
        await db.mealDao.addFoodToMeal(oats, meal, 'server-entry1');
        // An entry whose food row this device no longer has.
        await db.mealDao.addFoodToMeal(9999, meal, 'server-dangling');
      });
      await db.mealDao.addFoodToMeal(oats, meal);

      await sync.syncAll();

      final sent =
          (api.posts.singleWhere((p) => p.path == batch).data as List)
              .map((e) => (e as Map)['id']);
      expect(sent, isNot(contains('server-dangling')));
      expect(api.deletes, isEmpty);

      // Taken out here, it still says nothing to the server: this device
      // can't say what it was.
      await (db.delete(db.mealFoodTable)
        ..where((t) => t.serverId.equals('server-dangling'))).go();
      expect(await db.select(db.syncDeletionTable).get(), isEmpty);
    });

    test('an id the server refuses (409) is the only one replaced', () async {
      final oats = await syncedFood('server-f1');
      final meal = await syncedMeal('server-m1', oats);
      await db.untracked(
        () => db.mealDao.addFoodToMeal(oats, meal, 'server-entry1'),
      );
      await db.mealDao.addFoodToMeal(oats, meal);
      final refused =
          (await db.mealDao.getAllFoodEntriesForMeal(
            meal,
          )).singleWhere((e) => e.serverId != 'server-entry1').serverId!;
      api.postStatuses[batch] = 409;
      api.postErrorBodies[batch] = {'error': 'id_in_use', 'id': refused};

      await sync.syncAll();

      final ids =
          (await db.mealDao.getAllFoodEntriesForMeal(
            meal,
          )).map((e) => e.serverId).toSet();
      // The entry the server already holds keeps its id: a new one would be
      // stored beside it.
      expect(ids, contains('server-entry1'));
      expect(ids, isNot(contains(refused)));
      expect(ids, hasLength(2));
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
      api.changes['foodItems'] = [
        serverFoodItem(id: 'server-f1', name: 'Oats'),
      ];
      api.changes['meals'] = [
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
      api.changes['foodItems'] = [
        serverFoodItem(id: 'server-f1', name: 'Oats'),
        serverFoodItem(id: 'server-f2', name: 'Skyr'),
      ];
      api.changes['meals'] = [
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
      api.changes['workouts'] = [
        serverWorkout(id: 'server-w1', name: 'Upper'),
        serverWorkout(id: 'server-w2', name: 'Lower'),
      ];
      api.changes['workoutPlans'] = [
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

  // ── A row the server has is never `pending` ──────────────────────────────

  Future<int> syncedWorkout(String serverId, {String name = 'Upper'}) =>
      db.untracked(
        () => db
            .into(db.workoutTable)
            .insert(
              WorkoutTableCompanion.insert(
                name: name,
                difficulty: 0,
                serverId: Value(serverId),
                syncStatus: const Value(1),
              ),
            ),
      );

  Future<int> newPlan() => db
      .into(db.workoutPlanTable)
      .insert(
        WorkoutPlanTableCompanion.insert(
          name: 'Block 1',
          startDate: DateTime(2026, 1, 5),
          cyclePatternJson: '[]',
        ),
      );

  Future<int> newSession(int workoutId, {int? planId, bool done = false}) =>
      db
          .into(db.scheduledWorkoutTable)
          .insert(
            ScheduledWorkoutTableCompanion.insert(
              workoutId: workoutId,
              workoutPlanId: Value(planId),
              scheduledDate: DateTime(2026, 1, 5),
              isCompleted: Value(done),
            ),
          );

  Map<String, dynamic> lastPost(String path) =>
      (api.posts.lastWhere((p) => p.path == path).data as Map)
          .cast<String, dynamic>();

  group('a row the server has', () {
    test('is out of pending as soon as its create is answered: a plan whose '
        'workouts then fail to go still reaches its sessions', () async {
      final upper = await syncedWorkout('server-w1');
      final plan = await newPlan();
      await db
          .into(db.workoutPlanWorkoutTable)
          .insert(
            WorkoutPlanWorkoutTableCompanion.insert(
              planId: plan,
              workoutId: upper,
            ),
          );
      await newSession(upper, planId: plan);
      final planId = (await serverIdOf(db.workoutPlanTable, plan))!;
      api.putStatuses['api/WorkoutPlan/$planId/workouts'] = 500;

      await sync.syncAll();

      expect(
        await statusOf(db.workoutPlanTable, plan),
        SyncStatus.pendingUpdate.index,
        reason: 'the server holds it; only its list is still to go',
      );
      // Pushed in the same run, after the plan: it names the plan. Sent with
      // null, it was stored without one and never sent again.
      expect(lastPost('api/ScheduledWorkout')['workoutPlanId'], planId);
    });

    test('a new meal whose foods fail to go is on the server, and is updated '
        'rather than created again', () async {
      final oats = await syncedFood('server-f1');
      final meal = await db.mealDao.insertMeal(
        MealTableCompanion.insert(
          date: DateTime(2026, 1, 5),
          category: 'Breakfast',
          foodItemId: oats,
        ),
      );
      await db.mealDao.addFoodToMeal(oats, meal);
      final mealId = (await serverIdOf(db.mealTable, meal))!;
      api.postStatuses['api/Meal/$mealId/foods/batch'] = 500;

      await sync.syncAll();

      expect(
        await statusOf(db.mealTable, meal),
        SyncStatus.pendingUpdate.index,
      );
      api.postStatuses.clear();
      await sync.syncAll();
      expect(api.posts.where((p) => p.path == 'api/Meal'), hasLength(1));
      expect(api.puts.map((p) => p.path), contains('api/Meal/$mealId'));
      expect(await statusOf(db.mealTable, meal), SyncStatus.synced.index);
    });

    test('a session whose plan isn\'t on the server yet waits for it, rather '
        'than going without it', () async {
      final upper = await syncedWorkout('server-w1');
      final plan = await newPlan();
      final session = await newSession(upper, planId: plan);
      final planId = (await serverIdOf(db.workoutPlanTable, plan))!;
      api.postStatuses['api/WorkoutPlan'] = 500;

      await sync.syncAll();

      expect(api.posts.where((p) => p.path == 'api/ScheduledWorkout'), isEmpty);
      expect(
        await statusOf(db.scheduledWorkoutTable, session),
        SyncStatus.pending.index,
      );

      api.postStatuses.clear();
      await sync.syncAll();
      expect(lastPost('api/ScheduledWorkout')['workoutPlanId'], planId);
      expect(
        await statusOf(db.scheduledWorkoutTable, session),
        SyncStatus.synced.index,
      );
    });

    test('a plan\'s list waits for a workout the server may not have, rather '
        'than unlinking it', () async {
      final upper = await syncedWorkout('server-w1');
      // Pending: its create failed — or reached the server with its answer
      // lost, which from here looks the same.
      final lower = await db.workoutDao.saveCompleteWorkout(
        Workout(name: 'Lower', difficulty: WorkoutDifficulty.beginner),
      );
      api.postStatuses['api/Workout'] = 500;
      final plan = await db.untracked(
        () => db
            .into(db.workoutPlanTable)
            .insert(
              WorkoutPlanTableCompanion.insert(
                name: 'Block 1',
                startDate: DateTime(2026, 1, 5),
                cyclePatternJson: '[]',
                serverId: const Value('server-p1'),
                syncStatus: const Value(1),
              ),
            ),
      );
      for (final w in [upper, lower]) {
        await db
            .into(db.workoutPlanWorkoutTable)
            .insert(
              WorkoutPlanWorkoutTableCompanion.insert(planId: plan, workoutId: w),
            );
      }

      await sync.syncAll();

      expect(
        api.puts.where((p) => p.path == 'api/WorkoutPlan/server-p1/workouts'),
        isEmpty,
        reason: 'the list without Lower would unlink it on a server that has it',
      );
      expect(
        await statusOf(db.workoutPlanTable, plan),
        SyncStatus.pendingUpdate.index,
      );

      api.postStatuses.clear();
      await sync.syncAll();
      expect(
        api.puts
            .singleWhere((p) => p.path == 'api/WorkoutPlan/server-p1/workouts')
            .data,
        ['server-w1', await serverIdOf(db.workoutTable, lower)],
      );
    });
  });

  // ── A create answered with a row that isn't the one sent ─────────────────

  group('a create the server answers with another row', () {
    test('stays changed, so this device\'s fields follow as an update', () async {
      final upper = await syncedWorkout('server-w1');
      // Finished here; another device's copy of the same session isn't.
      final session = await newSession(upper, done: true);
      api.postResponses['api/ScheduledWorkout'] = {
        ...serverScheduledWorkout(
          id: 'server-sw9',
          workoutId: 'server-w1',
          isCompleted: false,
        ),
      };

      await sync.syncAll();

      expect(
        await serverIdOf(db.scheduledWorkoutTable, session),
        'server-sw9',
      );
      expect(
        await statusOf(db.scheduledWorkoutTable, session),
        SyncStatus.pendingUpdate.index,
        reason: 'clean, the next pull would mark it not done',
      );

      await sync.syncAll();
      final put = api.puts.singleWhere(
        (p) => p.path == 'api/ScheduledWorkout/server-sw9',
      );
      expect((put.data as Map)['isCompleted'], isTrue);
      expect(
        await statusOf(db.scheduledWorkoutTable, session),
        SyncStatus.synced.index,
      );
    });
  });

  // ── A workout's exercises ────────────────────────────────────────────────

  group('a workout\'s exercises', () {
    Future<int> exercise(String name, {String? serverId, bool custom = false}) =>
        db.untracked(
          () => db
              .into(db.exerciseTable)
              .insert(
                ExerciseTableCompanion.insert(
                  name: name,
                  type: 0,
                  targetMuscleGroups: '0',
                  isCustom: Value(custom),
                  serverId: Value(serverId),
                  syncStatus: Value(serverId == null ? 0 : 1),
                ),
              ),
        );

    Future<int> entry(
      int workoutId,
      int exerciseId, {
      int position = 0,
      String? serverId,
      int status = 0,
    }) => db.untracked(
      () => db
          .into(db.workoutExerciseTable)
          .insert(
            WorkoutExerciseTableCompanion.insert(
              workoutId: workoutId,
              exerciseId: exerciseId,
              orderPosition: position,
              serverId: serverId == null ? const Value.absent() : Value(serverId),
              syncStatus: Value(status),
            ),
          ),
    );

    test('one taken out and put back in the same place is deleted before the '
        'new one is created', () async {
      final squat = await exercise('Squat', serverId: 'server-e1');
      final w = await syncedWorkout('server-w1', name: 'Legs');
      // Taken out (pendingDelete, still in its slot on the server), and put
      // back where it was.
      final removed = await entry(w, squat, serverId: 'server-we1', status: 3);
      final readded = await entry(w, squat);
      final readdedId = (await serverIdOf(db.workoutExerciseTable, readded))!;

      await sync.syncAll();

      final delete = api.requests.indexOf(
        'DELETE api/Workout/exercises/server-we1',
      );
      final create = api.requests.indexOf(
        'POST api/Workout/server-w1/exercises/batch',
      );
      expect(delete, isNot(-1));
      expect(create, greaterThan(delete),
          reason: 'created first, the server answers with the entry the '
              'DELETE then removes');
      expect(
        await (db.select(db.workoutExerciseTable)
              ..where((t) => t.id.equals(removed)))
            .getSingleOrNull(),
        isNull,
      );
      expect(await serverIdOf(db.workoutExerciseTable, readded), readdedId);
      expect(
        await statusOf(db.workoutExerciseTable, readded),
        SyncStatus.synced.index,
      );
    });

    test('an answer is paired with the item it names, not by slot', () async {
      final squat = await exercise('Squat', serverId: 'server-e1');
      final w = await syncedWorkout('server-w1', name: 'Legs');
      // Two entries for one slot — overlapping saves made both.
      final first = await entry(w, squat);
      final twin = await entry(w, squat);
      final firstId = (await serverIdOf(db.workoutExerciseTable, first))!;
      final twinId = (await serverIdOf(db.workoutExerciseTable, twin))!;
      // The server stores the first, and answers the second with it: the
      // slot is taken.
      api.postResponses['api/Workout/server-w1/exercises/batch'] = [
        for (final requested in [firstId, twinId])
          {
            ...serverWorkoutExercise(
              id: firstId,
              exerciseId: 'server-e1',
              orderPosition: 0,
            ),
            'requestedId': requested,
          },
      ];

      await sync.syncAll();

      expect(await serverIdOf(db.workoutExerciseTable, twin), firstId);
      // Answered with a row that isn't the one it sent, so its own fields
      // hadn't reached the server: they follow as an update of that row.
      expect(api.puts.map((p) => p.path), contains('api/Workout/exercises/$firstId'));
      expect(
        await statusOf(db.workoutExerciseTable, twin),
        SyncStatus.synced.index,
      );
    });

    test('one whose built-in exercise isn\'t linked yet waits, and never goes '
        'up as another lift with a similar name', () async {
      // The server's "Front Squat" is linked here; "Squat" is not yet.
      await exercise('Front Squat', serverId: 'server-front-squat');
      final squat = await exercise('Squat');
      final w = await syncedWorkout('server-w1', name: 'Legs');
      final fresh = await entry(w, squat);
      // One the server already has, edited here since.
      await entry(w, squat, position: 1, serverId: 'server-we2', status: 2);

      await sync.syncAll();

      expect(
        api.posts.where(
          (p) => p.path == 'api/Workout/server-w1/exercises/batch',
        ),
        isEmpty,
      );
      expect(
        api.puts.where((p) => p.path == 'api/Workout/exercises/server-we2'),
        isEmpty,
      );
      expect(
        await statusOf(db.workoutExerciseTable, fresh),
        SyncStatus.pending.index,
      );
    });

    test('built-ins are linked to the server\'s by their exact name only',
        () async {
      final frontSquat = await exercise('Front Squat');
      final bench = await exercise('bench press');
      api.getResponses['api/Exercise/AllExercises'] = [
        {'id': 'server-squat', 'name': 'Squat', 'isCustom': false},
        {'id': 'server-bench', 'name': 'Bench Press', 'isCustom': false},
      ];

      await sync.pullAll();

      expect(await serverIdOf(db.exerciseTable, bench), 'server-bench');
      expect(
        await serverIdOf(db.exerciseTable, frontSquat),
        isNull,
        reason: 'a name containing another is a different exercise',
      );
      final squat =
          await (db.select(db.exerciseTable)
            ..where((e) => e.serverId.equals('server-squat'))).getSingle();
      expect(squat.name, 'Squat');
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

    test('deleted before the server confirmed it is still deleted there, in '
        'case its create landed', () async {
      final dao = MealTemplateDao(db);
      final id = await dao.insertTemplate({
        'name': 'Chili',
        'category': 'Dinner',
        'items': <dynamic>[],
      });
      final minted =
          (await dao.getAllTemplates()).singleWhere(
                (t) => t['id'] == id,
              )['serverId']
              as String;
      // The server stores the POST; its answer never arrives.
      api.postsLosingResponse.add('api/MealTemplate');
      await sync.syncAll();

      await dao.deleteTemplate(id);
      expect(await dao.getDeletedServerIds(), [minted]);
      expect(await MealTemplateDao.hasPendingSync(), isTrue);

      await sync.syncAll();
      expect(api.deletes, ['api/MealTemplate/$minted']);
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
        // Only the entry that was given an id here may be on the server under
        // another: it is flagged for the push to look first.
        expect(
          {for (final e in entries) e.serverId == 'server-e1': e.idBackfilled},
          {true: false, false: true},
        );
        expect(
          (await db.select(db.mealTable).getSingle()).syncStatus,
          SyncStatus.pendingUpdate.index,
          reason: 'its list goes up whole now, with the food that never went',
        );
        expect(
          (await db.select(db.workoutPlanTable).getSingle()).syncStatus,
          SyncStatus.pendingUpdate.index,
        );

        // Both deletions are recorded for the server, the never-pushed one
        // under the id it was just given: the trigger can't tell a row the
        // server never got from one whose create answer was lost, and a 404
        // settles the first.
        await db.customStatement(
          'DELETE FROM workout_table WHERE id IN (2, 3)',
        );
        final recorded = await db.select(db.syncDeletionTable).get();
        expect(recorded.map((d) => d.serverId).toSet(), {
          workouts[2]!.serverId,
          'server-w3',
        });
      },
    );
  });

  // ── What an older build left half-sent ───────────────────────────────────

  group('a food an older build sent but never heard back about', () {
    late Directory tempDir;
    late File file;
    final day = DateTime(2026, 1, 5);

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('forgeform_heal');
      file = File('${tempDir.path}/app.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    /// A version-41 install holding oats and a breakfast of them, opened by
    /// this build — so the entries without an id get one from the migration.
    Future<({AppDatabase db, SyncService sync})> upgraded({
      required String meal,
      required int entriesWithoutId,
    }) async {
      final old = AppDatabase.test(NativeDatabase(file));
      await old.customStatement('SELECT 1');
      await old.customStatement(
        "INSERT INTO food_item (id, name, calories, protein, carbs, fat, server_id, sync_status) "
        "VALUES (1, 'Oats', 100, 5, 10, 2, 'server-f1', 1)",
      );
      await old.customStatement(meal);
      for (var i = 0; i < entriesWithoutId; i++) {
        await old.customStatement(
          'INSERT INTO meal_food_table (meal_id, food_entry_id) VALUES (1, 1)',
        );
      }
      await old.customStatement('PRAGMA user_version = 41');
      await old.close();
      final db = AppDatabase.test(NativeDatabase(file));
      addTearDown(db.close);
      return (
        db: db,
        sync: SyncService(
          db: db,
          apiClient: api,
          mealTemplateDao: MealTemplateDao(db),
        ),
      );
    }

    final seconds = day.millisecondsSinceEpoch ~/ 1000;

    test('in a meal the server has is matched to the server\'s entry, not '
        'sent again', () async {
      final u = await upgraded(
        meal:
            "INSERT INTO meal_table (id, date, category, food_item_id, server_id, sync_status) "
            "VALUES (1, $seconds, 'Breakfast', 1, 'server-m1', 1)",
        // Two portions whose answers never came; the server got one of them.
        entriesWithoutId: 2,
      );
      await u.db.customStatement(
        "INSERT INTO meal_food_table (meal_id, food_entry_id, server_id) "
        "VALUES (1, 1, 'server-e1')",
      );
      api.getResponses['api/Meal/server-m1'] = serverMeal(
        id: 'server-m1',
        foodItemId: 'server-f1',
        foodEntries: [
          serverFoodEntry(id: 'server-e1', foodItemId: 'server-f1'),
          serverFoodEntry(id: 'server-lost', foodItemId: 'server-f1'),
        ],
      );

      await u.sync.syncAll();

      final sent =
          (api.posts
                      .singleWhere(
                        (p) => p.path == 'api/Meal/server-m1/foods/batch',
                      )
                      .data
                  as List)
              .map((e) => (e as Map)['id'] as String)
              .toList();
      expect(sent, containsAll(['server-e1', 'server-lost']));
      expect(sent, hasLength(3), reason: 'the portion never sent goes as new');
      final entries = await u.db.select(u.db.mealFoodTable).get();
      expect(entries.map((e) => e.serverId).toSet(), sent.toSet());
      expect(entries.any((e) => e.idBackfilled), isFalse);

      // Asked once: the flags are gone.
      await u.db.mealDao.addFoodToMeal(1, 1);
      await u.sync.syncAll();
      expect(api.gets.where((g) => g == 'api/Meal/server-m1'), hasLength(1));
    });

    test('in a meal the create is answered with, takes the server\'s entry',
        () async {
      final u = await upgraded(
        meal:
            "INSERT INTO meal_table (id, date, category, food_item_id, sync_status) "
            "VALUES (1, $seconds, 'Breakfast', 1, 0)",
        entriesWithoutId: 1,
      );
      api.postResponses['api/Meal'] = serverMeal(
        id: 'server-m9',
        foodItemId: 'server-f1',
        foodEntries: [
          serverFoodEntry(id: 'server-lost', foodItemId: 'server-f1'),
        ],
      );

      await u.sync.syncAll();

      expect(
        api.posts
            .singleWhere((p) => p.path == 'api/Meal/server-m9/foods/batch')
            .data,
        [
          {'id': 'server-lost', 'foodItemId': 'server-f1'},
        ],
        reason: 'under its new id it would be stored beside itself',
      );
      final entries = await u.db.select(u.db.mealFoodTable).get();
      expect(entries.map((e) => e.serverId), ['server-lost']);
    });

    test('in a meal the pull adopts, is not added a second time', () async {
      final u = await upgraded(
        meal:
            "INSERT INTO meal_table (id, date, category, food_item_id, sync_status) "
            "VALUES (1, $seconds, 'Breakfast', 1, 0)",
        entriesWithoutId: 1,
      );
      api.changes['foodItems'] = [
        serverFoodItem(id: 'server-f1', name: 'Oats'),
      ];
      api.changes['meals'] = [
        serverMeal(
          id: 'server-m9',
          foodItemId: 'server-f1',
          date: day.toUtc().toIso8601String(),
          category: 'Breakfast',
          foodEntries: [
            serverFoodEntry(id: 'server-lost', foodItemId: 'server-f1'),
          ],
        ),
      ];

      await u.sync.pullAll();

      final entries = await u.db.select(u.db.mealFoodTable).get();
      expect(entries.map((e) => e.serverId), ['server-lost']);
      expect(entries.single.idBackfilled, isFalse);
    });
  });
}
