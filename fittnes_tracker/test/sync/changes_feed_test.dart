import 'dart:io';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/dao/meal_template_dao.dart';
import 'package:ForgeForm/core/sync/sync_service.dart';
import 'package:ForgeForm/feature/weight_tracking/data/repositories/weight_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

/// Part three of the sync rework, the device's half — the pull reads the
/// changes feed from a cursor, and learns of deletions only from the server
/// saying so. See `docs/sync-architecture.md`, part three.
///
/// Each test was run against the code before the change, or with the one rule
/// it pins taken out, and failed there.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeApiClient api;
  late SyncService sync;

  SyncService serviceFor(AppDatabase db) =>
      SyncService(db: db, apiClient: api, mealTemplateDao: MealTemplateDao(db));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SyncService.resetForTesting();
    db = AppDatabase.test(NativeDatabase.memory());
    api = FakeApiClient()..stubEmptyPull();
    sync = serviceFor(db);
  });

  tearDown(() => db.close());

  Future<String?> storedCursor([AppDatabase? on]) async =>
      (await (on ?? db).select((on ?? db).syncMeta).getSingleOrNull())
          ?.changesCursor;

  /// The answer the next pull gets: nothing but what [fill] puts in it.
  void nextAnswer(String cursor, [void Function(Map<String, dynamic>)? fill]) {
    api.changes
      ..clear()
      ..addAll(FakeApiClient.emptyChanges(cursor: cursor));
    fill?.call(api.changes);
  }

  Map<String, dynamic> serverWeight(String id, num weight) => {
    'id': id,
    'date': '2026-01-05T00:00:00Z',
    'weight': weight,
    'note': null,
  };

  Future<int> syncedWeight(String serverId, double weight) => db.untracked(
    () => db
        .into(db.weightRecord)
        .insert(
          WeightRecordCompanion.insert(
            date: DateTime(2026, 1, 5),
            weight: weight,
            serverId: Value(serverId),
            syncStatus: const Value(1),
          ),
        ),
  );

  Future<int> syncedFood(String serverId) => db.untracked(
    () => db
        .into(db.foodItem)
        .insert(
          FoodItemCompanion.insert(
            name: 'Oats',
            calories: 100,
            protein: 5,
            carbs: 10,
            fat: 2,
            serverId: Value(serverId),
            syncStatus: const Value(1),
          ),
        ),
  );

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

  /// A workout the server has, with one exercise entry, and a session of it
  /// holding one logged set this device hasn't sent — the server knows the
  /// session only as a placeholder. Returns the local ids.
  Future<({int workout, int session, int set})> workoutWithUnsentSet() =>
      db.untracked(() async {
        final exercise = await db
            .into(db.exerciseTable)
            .insert(
              ExerciseTableCompanion.insert(
                name: 'Bench Press',
                type: 0,
                targetMuscleGroups: '0',
                serverId: const Value('server-e1'),
                syncStatus: const Value(1),
              ),
            );
        final w = await db
            .into(db.workoutTable)
            .insert(
              WorkoutTableCompanion.insert(
                name: 'Push',
                difficulty: 0,
                serverId: const Value('server-w1'),
                syncStatus: const Value(1),
              ),
            );
        final we = await db
            .into(db.workoutExerciseTable)
            .insert(
              WorkoutExerciseTableCompanion.insert(
                workoutId: w,
                exerciseId: exercise,
                orderPosition: 0,
                serverId: const Value('server-we1'),
                syncStatus: const Value(1),
              ),
            );
        final sw = await db
            .into(db.scheduledWorkoutTable)
            .insert(
              ScheduledWorkoutTableCompanion.insert(
                workoutId: w,
                scheduledDate: DateTime(2026, 1, 5),
                serverId: const Value('server-sw1'),
                syncStatus: const Value(1),
              ),
            );
        final se = await db
            .into(db.scheduledWorkoutExerciseTable)
            .insert(
              ScheduledWorkoutExerciseTableCompanion.insert(
                scheduledWorkoutId: sw,
                workoutExerciseId: we,
                serverId: const Value('server-se1'),
                syncStatus: const Value(2),
              ),
            );
        final set = await db
            .into(db.workoutSetTable)
            .insert(
              WorkoutSetTableCompanion.insert(
                scheduledWorkoutExerciseId: se,
                setNumber: 1,
                reps: const Value(5),
              ),
            );
        return (workout: w, session: sw, set: set);
      });

  // ── The cursor ────────────────────────────────────────────────────────────

  group('the pull', () {
    test('asks for everything the first time, and after that only for what '
        'changed since the last answer', () async {
      final food = await syncedFood('server-f1');
      nextAnswer('2026-02-01T10:00:00.000Z', (c) {
        c['workouts'] = [serverWorkout(id: 'server-w1', name: 'Push')];
      });
      await sync.pullAll();

      // The server changed the food since; the workout is as it was, and so
      // is absent from the answer.
      nextAnswer('2026-02-02T10:00:00.000Z', (c) {
        c['foodItems'] = [
          serverFoodItem(id: 'server-f1', name: 'Rolled oats', calories: 380),
        ];
      });
      await sync.pullAll();

      expect(api.changesSince, [null, '2026-02-01T10:00:00.000Z']);
      final row =
          await (db.select(db.foodItem)
            ..where((t) => t.id.equals(food))).getSingle();
      expect(row.name, 'Rolled oats');
      expect(row.calories, 380);
      expect(row.syncStatus, SyncStatus.synced.index);
      expect((await db.select(db.workoutTable).get()).map((w) => w.serverId), [
        'server-w1',
      ], reason: 'absent from an answer is not deleted');
      expect(await storedCursor(), '2026-02-02T10:00:00.000Z');
    });

    test(
      'asks for everything when the user restores from the server',
      () async {
        nextAnswer('2026-02-01T10:00:00.000Z');
        await sync.pullAll();

        await sync.pullAll(everything: true);

        expect(api.changesSince, [null, null]);
      },
    );

    test('no longer asks for the list endpoints', () async {
      nextAnswer('2026-02-01T10:00:00.000Z', (c) {
        c['workouts'] = [serverWorkout(id: 'server-w1', name: 'Push')];
        c['foodItems'] = [serverFoodItem(id: 'server-f1', name: 'Oats')];
        c['weights'] = [serverWeight('server-wt1', 80)];
      });

      await sync.pullAll();

      expect(api.gets.toSet(), {
        // The built-in catalogue isn't account data, so it isn't in the feed.
        'api/Exercise/AllExercises',
        'api/Sync/changes',
      });
      expect(await db.select(db.weightRecord).get(), hasLength(1));

      // After the first, a pull asks only for what changed — the catalogue
      // too is fetched only when something needs it.
      api.gets.clear();
      nextAnswer('2026-02-02T10:00:00.000Z', (c) {
        c['weights'] = [serverWeight('server-wt2', 79)];
      });
      await sync.pullAll();

      expect(api.gets, ['api/Sync/changes']);
      expect(await db.select(db.weightRecord).get(), hasLength(2));
    });

    test('fetches the built-in catalogue when an answer names an exercise '
        'this device has not linked', () async {
      final squat = await db
          .into(db.exerciseTable)
          .insert(
            ExerciseTableCompanion.insert(
              name: 'Squat',
              type: 0,
              targetMuscleGroups: '0',
              serverId: const Value(null),
            ),
          );
      nextAnswer('2026-02-01T10:00:00.000Z');
      await sync.pullAll();

      // A trainer's workout performing a built-in this device never linked.
      api.gets.clear();
      api.getResponses['api/Exercise/AllExercises'] = [
        {'id': 'server-squat', 'name': 'Squat', 'isCustom': false},
      ];
      nextAnswer('2026-02-02T10:00:00.000Z', (c) {
        c['workouts'] = [
          serverWorkout(
            id: 'server-w1',
            name: 'Legs',
            exercises: [
              serverWorkoutExercise(
                id: 'server-we1',
                exerciseId: 'server-squat',
                orderPosition: 0,
              ),
            ],
          ),
        ];
      });
      await sync.pullAll();

      expect(api.gets, contains('api/Exercise/AllExercises'));
      final entry = await db.workoutDao.getWorkoutExerciseByServerId(
        'server-we1',
      );
      expect(entry!.exerciseId, squat);
    });
  });

  group('the built-in catalogue', () {
    test('is fetched when a workout here waits on a built-in not linked yet, '
        'even when no answer names it', () async {
      nextAnswer('2026-02-01T10:00:00.000Z');
      await sync.pullAll();

      final squat = await db
          .into(db.exerciseTable)
          .insert(
            ExerciseTableCompanion.insert(
              name: 'Squat',
              type: 0,
              targetMuscleGroups: '0',
              serverId: const Value(null),
            ),
          );
      final w = await db
          .into(db.workoutTable)
          .insert(WorkoutTableCompanion.insert(name: 'Legs', difficulty: 0));
      await db
          .into(db.workoutExerciseTable)
          .insert(
            WorkoutExerciseTableCompanion.insert(
              workoutId: w,
              exerciseId: squat,
              orderPosition: 0,
            ),
          );
      api.getResponses['api/Exercise/AllExercises'] = [
        {'id': 'server-squat', 'name': 'Squat', 'isCustom': false},
      ];
      api.gets.clear();
      nextAnswer('2026-02-02T10:00:00.000Z');

      await sync.pullAll();

      expect(api.gets, contains('api/Exercise/AllExercises'));
      expect(await serverIdOf(db.exerciseTable, squat), 'server-squat');
    });
  });

  group('a row this device holds an unsent change to', () {
    test(
      'is left for the push, and the cursor stays until it is clean',
      () async {
        final weight = await syncedWeight('server-wt1', 80);
        nextAnswer('2026-02-01T10:00:00.000Z');
        await sync.pullAll();

        // Edited here, not pushed yet; meanwhile another device's edit is in
        // the next answer.
        await WeightRepository(db).updateWeightRecord(
          id: weight,
          date: DateTime(2026, 1, 5),
          weight: 81,
        );
        nextAnswer('2026-02-02T10:00:00.000Z', (c) {
          c['weights'] = [serverWeight('server-wt1', 79)];
        });
        await sync.pullAll();

        final held =
            await (db.select(db.weightRecord)
              ..where((t) => t.id.equals(weight))).getSingle();
        expect(held.weight, 81);
        expect(held.syncStatus, SyncStatus.pendingUpdate.index);
        expect(
          await storedCursor(),
          '2026-02-01T10:00:00.000Z',
          reason: 'a push that changes nothing on the server leaves no echo',
        );

        // Once the push has sent it, the same changes are asked for again, and
        // this time they apply.
        await sync.syncAll();
        await sync.pullAll();

        expect(api.changesSince.last, '2026-02-01T10:00:00.000Z');
        expect(await storedCursor(), '2026-02-02T10:00:00.000Z');
      },
    );
  });

  // ── Deletions ─────────────────────────────────────────────────────────────

  group('a deletion in the answer', () {
    test('removes a clean row with what hangs only on it, and tells the '
        'server nothing', () async {
      final food = await syncedFood('server-f1');
      final meal = await syncedMeal('server-m1', food);
      await db.untracked(
        () => db.mealDao.addFoodToMeal(food, meal, 'server-e1'),
      );
      nextAnswer('2026-02-01T10:00:00.000Z', (c) {
        c['deleted'] = [serverTombstone('meal', 'server-m1')];
      });

      await sync.pullAll();
      await sync.syncAll();

      expect(await db.select(db.mealTable).get(), isEmpty);
      expect(await db.select(db.mealFoodTable).get(), isEmpty);
      // The food itself is its own row, and nothing deleted it.
      expect(await db.select(db.foodItem).get(), hasLength(1));
      expect(api.deletes, isEmpty);
      expect(await db.select(db.syncDeletionTable).get(), isEmpty);
    });

    test('keeps a workout that a session here logged unsent sets against, and '
        'creates it again under a fresh id', () async {
      final ids = await workoutWithUnsentSet();
      // The server deleted the workout, and the session it only knew as a
      // placeholder with it.
      nextAnswer('2026-02-01T10:00:00.000Z', (c) {
        c['deleted'] = [
          serverTombstone('workout', 'server-w1'),
          serverTombstone('scheduledWorkout', 'server-sw1'),
        ];
      });

      await sync.pullAll();

      final workoutId = await serverIdOf(db.workoutTable, ids.workout);
      final sessionId = await serverIdOf(db.scheduledWorkoutTable, ids.session);
      expect(workoutId, isNot('server-w1'));
      expect(sessionId, isNot('server-sw1'));
      expect(await statusOf(db.workoutTable, ids.workout), 0);
      expect(await statusOf(db.scheduledWorkoutTable, ids.session), 0);
      expect(await db.select(db.workoutSetTable).get(), hasLength(1));

      await sync.syncAll();

      final creates = {
        for (final p in api.posts)
          if (p.path == 'api/Workout' || p.path == 'api/ScheduledWorkout')
            p.path: p.data as Map,
      };
      expect(creates['api/Workout']!['id'], workoutId);
      expect(creates['api/ScheduledWorkout']!['id'], sessionId);
      expect(creates['api/ScheduledWorkout']!['workoutId'], workoutId);
      expect(
        api.posts.where((p) => p.path.endsWith('/sets/batch')),
        hasLength(1),
        reason: 'the set logged here reaches the server',
      );
    });

    test('is applied after the answer\'s aggregates, which can list the same '
        'row as changed', () async {
      nextAnswer('2026-02-01T10:00:00.000Z', (c) {
        c['foodItems'] = [serverFoodItem(id: 'server-f1', name: 'Oats')];
        c['meals'] = [
          serverMeal(
            id: 'server-m1',
            foodItemId: 'server-f1',
            foodEntries: [
              serverFoodEntry(id: 'server-e1', foodItemId: 'server-f1'),
            ],
          ),
        ];
        c['deleted'] = [serverTombstone('meal', 'server-m1')];
      });

      await sync.pullAll();

      expect(await db.select(db.mealTable).get(), isEmpty);
      expect(await db.select(db.mealFoodTable).get(), isEmpty);
    });
  });

  group('a create the server answers 410', () {
    test('deletes the row when nothing hangs on it', () async {
      final weight = await WeightRepository(
        db,
      ).addWeightRecord(date: DateTime(2026, 1, 5), weight: 80);
      api.deletedIds.add((await serverIdOf(db.weightRecord, weight))!);

      await sync.syncAll();
      await sync.syncAll();

      expect(await db.select(db.weightRecord).get(), isEmpty);
      expect(
        api.posts.where((p) => p.path == 'api/WeightTracking/TrackWeight'),
        hasLength(1),
        reason: 'refused once, and not sent again',
      );
      expect(api.deletes, isEmpty);
      expect(await db.select(db.syncDeletionTable).get(), isEmpty);
    });

    test('gives the row a fresh id when history hangs on it, and creates it '
        'under that', () async {
      final ids = await workoutWithUnsentSet();
      // This device never heard its create answered; meanwhile it was
      // deleted elsewhere, before anything was logged in its session there.
      await db.untracked(
        () => (db.update(db.workoutTable)..where(
          (t) => t.id.equals(ids.workout),
        )).write(const WorkoutTableCompanion(syncStatus: Value(0))),
      );
      api.deletedIds.addAll(['server-w1', 'server-sw1']);

      await sync.syncAll();
      await sync.syncAll();

      final workouts =
          api.posts
              .where((p) => p.path == 'api/Workout')
              .map((p) => (p.data as Map)['id'])
              .toList();
      final fresh = await serverIdOf(db.workoutTable, ids.workout);
      expect(workouts, ['server-w1', fresh]);
      expect(await statusOf(db.workoutTable, ids.workout), 1);
      final session =
          api.posts.where((p) => p.path == 'api/ScheduledWorkout').single;
      expect((session.data as Map)['workoutId'], fresh);
      expect((session.data as Map)['id'], isNot('server-sw1'));
      expect(await db.select(db.workoutSetTable).get(), hasLength(1));
    });
  });

  group('a food removed from a meal on one device', () {
    test('is not put back by an edit to the meal on another device that has '
        'not pulled yet', () async {
      final oats = await syncedFood('server-f1');
      final banana = await syncedFood('server-f2');
      final apple = await syncedFood('server-f3');
      final meal = await syncedMeal('server-m1', oats);
      await db.untracked(() async {
        await db.mealDao.addFoodToMeal(oats, meal, 'server-e1');
        await db.mealDao.addFoodToMeal(banana, meal, 'server-e2');
      });
      // Another device took the oats out; the server remembers.
      api.deletedIds.add('server-e1');

      // This one, not having pulled that, adds an apple.
      await db.mealDao.addFoodToMeal(apple, meal, 'server-e3');
      await sync.syncAll();

      final batches = [
        for (final p in api.posts)
          if (p.path == 'api/Meal/server-m1/foods/batch')
            {for (final e in (p.data as List).cast<Map>()) e['id']},
      ];
      expect(batches.last, {'server-e2', 'server-e3'});
      final entries = await db.mealDao.getAllFoodEntriesForMeal(meal);
      expect(entries.map((e) => e.serverId).toSet(), {
        'server-e2',
        'server-e3',
      });
      expect(await statusOf(db.mealTable, meal), SyncStatus.synced.index);
      expect(api.deletes, isEmpty);
      expect(await db.select(db.syncDeletionTable).get(), isEmpty);
    });
    test('drops every deleted food a refused batch names, in one retry',
        () async {
      final oats = await syncedFood('server-f1');
      final banana = await syncedFood('server-f2');
      final apple = await syncedFood('server-f3');
      final meal = await syncedMeal('server-m1', oats);
      await db.untracked(() async {
        await db.mealDao.addFoodToMeal(oats, meal, 'server-e1');
        await db.mealDao.addFoodToMeal(banana, meal, 'server-e2');
      });
      // Another device took both out; the server remembers.
      api.deletedIds.addAll({'server-e1', 'server-e2'});

      await db.mealDao.addFoodToMeal(apple, meal, 'server-e3');
      await sync.syncAll();

      final batches = [
        for (final p in api.posts)
          if (p.path == 'api/Meal/server-m1/foods/batch')
            {for (final e in (p.data as List).cast<Map>()) e['id']},
      ];
      // The refused batch, then one carrying only what is left.
      expect(batches, hasLength(2));
      expect(batches.last, {'server-e3'});
      final entries = await db.mealDao.getAllFoodEntriesForMeal(meal);
      expect(entries.map((e) => e.serverId).toSet(), {'server-e3'});
    });
  });

  group('a DELETE the server refuses', () {
    test('drops the cursor, so the next pull asks for everything and the row '
        'comes back', () async {
      final w = await db.untracked(
        () => db
            .into(db.workoutTable)
            .insert(
              WorkoutTableCompanion.insert(
                name: 'Push',
                difficulty: 0,
                serverId: const Value('server-w1'),
                syncStatus: const Value(1),
              ),
            ),
      );
      nextAnswer('2026-02-01T10:00:00.000Z');
      await sync.pullAll();

      // Deleted here; the server keeps it (a session elsewhere logged sets).
      await (db.delete(db.workoutTable)..where((t) => t.id.equals(w))).go();
      api.deleteStatuses['api/Workout/server-w1'] = 409;
      await sync.syncAll();

      // The workout hasn't changed on the server since the last answer, so
      // only an answer holding everything lists it.
      nextAnswer('2026-02-02T10:00:00.000Z', (c) {
        c['workouts'] = [serverWorkout(id: 'server-w1', name: 'Push')];
      });
      await sync.pullAll();

      expect(api.changesSince.last, isNull);
      expect((await db.select(db.workoutTable).get()).map((w) => w.serverId), [
        'server-w1',
      ]);
    });
  });

  group('signing out', () {
    test('forgets the cursor with the data it describes', () async {
      nextAnswer('2026-02-01T10:00:00.000Z');
      await sync.pullAll();
      expect(await storedCursor(), isNotNull);

      await db.clearAllUserData();
      await sync.pullAll();

      expect(api.changesSince, [null, null]);
    });
  });

  group('an install upgraded from schema 42', () {
    late Directory tempDir;
    late File file;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('forgeform_changes');
      file = File('${tempDir.path}/app.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('gains the cursor table, and its first pull asks for everything and '
        'applies what was deleted meanwhile', () async {
      // A version-42 install: no cursor table, and two weigh-ins a full pull
      // brought down — one of which another device has since deleted.
      final old = AppDatabase.test(NativeDatabase(file));
      await old.customStatement('DROP TABLE sync_meta');
      for (final id in ['server-wt1', 'server-wt2']) {
        await old.customStatement(
          'INSERT INTO weight_record (date, weight, server_id, sync_status) '
          "VALUES (0, 80.4, '$id', 1)",
        );
      }
      await old.customStatement('PRAGMA user_version = 42');
      await old.close();

      final upgraded = AppDatabase.test(NativeDatabase(file));
      addTearDown(upgraded.close);
      expect(await upgraded.select(upgraded.syncMeta).get(), isEmpty);

      nextAnswer('2026-02-01T10:00:00.000Z', (c) {
        c['weights'] = [serverWeight('server-wt1', 80.4)];
        c['deleted'] = [serverTombstone('weight', 'server-wt2')];
      });
      await serviceFor(upgraded).pullAll();

      expect(api.changesSince, [null]);
      expect(
        (await upgraded.select(upgraded.weightRecord).get()).map(
          (w) => w.serverId,
        ),
        ['server-wt1'],
      );
      expect(await storedCursor(upgraded), '2026-02-01T10:00:00.000Z');
    });
  });
}
