import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/dao/meal_template_dao.dart';
import 'package:ForgeForm/core/network/services/sync_service.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout_exercise.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout_set.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

/// Regression tests for the sync bugs that only became visible after switching
/// accounts: an account switch empties the local tables, so the next pull is the
/// first thing that ever reads the server's copy of a workout back. Everything
/// here is about keeping that copy honest.
///
/// See `docs/sync-account-switch-duplication.md`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeApiClient api;
  late SyncService sync;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.test(NativeDatabase.memory());
    api = FakeApiClient();
    sync = SyncService(
      db: db,
      apiClient: api,
      mealTemplateDao: MealTemplateDao(db),
    );
  });

  tearDown(() => db.close());

  /// A synced local exercise, so pulled workout exercises can resolve to it.
  Future<int> insertSyncedExercise({
    String name = 'Bench Press',
    required String serverId,
  }) => db
      .into(db.exerciseTable)
      .insert(
        ExerciseTableCompanion.insert(
          // name, type and targetMuscleGroups have no column default, so drift
          // makes them required raw values rather than Value<T> wrappers.
          name: name,
          type: 0,
          targetMuscleGroups: 'chest',
          isCustom: const Value(false),
          serverId: Value(serverId),
          syncStatus: const Value(1),
        ),
      );

  group('editing a synced workout', () {
    test('re-enters the push queue', () async {
      final id = await db.workoutDao.saveCompleteWorkout(
        Workout(
          name: 'Push Day',
          difficulty: WorkoutDifficulty.beginner,
          exercises: const [],
        ),
      );
      await db.workoutDao.markWorkoutSynced(id, 'server-w1');

      await db.workoutDao.saveCompleteWorkout(
        Workout(
          id: id,
          name: 'Push Day A',
          difficulty: WorkoutDifficulty.beginner,
          exercises: const [],
        ),
      );

      final row =
          await (db.select(db.workoutTable)
            ..where((w) => w.id.equals(id))).getSingle();
      // 2 == SyncStatus.pendingUpdate. Left at synced, syncWorkoutTemplates
      // skips the workout and every edit below it is stranded.
      expect(row.syncStatus, 2);
      expect(row.serverId, 'server-w1');
    });

    test('does not downgrade a workout that has never synced', () async {
      final id = await db.workoutDao.saveCompleteWorkout(
        Workout(
          name: 'Leg Day',
          difficulty: WorkoutDifficulty.beginner,
          exercises: const [],
        ),
      );

      await db.workoutDao.saveCompleteWorkout(
        Workout(
          id: id,
          name: 'Leg Day A',
          difficulty: WorkoutDifficulty.beginner,
          exercises: const [],
        ),
      );

      final row =
          await (db.select(db.workoutTable)
            ..where((w) => w.id.equals(id))).getSingle();
      expect(row.syncStatus, 0, reason: 'still pending, not pendingUpdate');
    });
  });

  group('removing an exercise from a synced workout', () {
    test('issues the DELETE the server needs to hear about', () async {
      final exerciseId = await insertSyncedExercise(serverId: 'server-e1');
      final workoutId = await db.workoutDao.saveCompleteWorkout(
        Workout(
          name: 'Push Day',
          difficulty: WorkoutDifficulty.beginner,
          exercises: [
            WorkoutExercise(
              workoutId: 0,
              exerciseId: exerciseId,
              orderPosition: 0,
              sets: [WorkoutSet(exerciseInstanceId: 0, setNumber: 1)],
            ),
          ],
        ),
      );
      await db.workoutDao.markWorkoutSynced(workoutId, 'server-w1');
      final we =
          await (db.select(db.workoutExerciseTable)
            ..where((t) => t.workoutId.equals(workoutId))).getSingle();
      await db.workoutDao.markWorkoutExerciseSynced(we.id, 'server-we1');

      // Remove it: saveCompleteWorkout stamps pendingDelete because the row has
      // a serverId, and marks the workout pendingUpdate so sync comes back here.
      await db.workoutDao.saveCompleteWorkout(
        Workout(
          id: workoutId,
          name: 'Push Day',
          difficulty: WorkoutDifficulty.beginner,
          exercises: const [],
        ),
      );

      api.stubEmptyPull();
      // Reconcile must still see the workout, or it clears the serverId first.
      api.getResponses['api/Workout'] = [
        serverWorkout(id: 'server-w1', name: 'Push Day'),
      ];
      api.getResponses['api/Exercise/UserExercise'] = <dynamic>[];

      await sync.syncAll();

      expect(api.deletes, contains('api/Workout/exercises/server-we1'));
      final remaining =
          await (db.select(db.workoutExerciseTable)
            ..where((t) => t.workoutId.equals(workoutId))).get();
      expect(remaining, isEmpty);
    });
  });

  group('pulling a workout the server has duplicates of', () {
    test('inserts one exercise and one set per set number', () async {
      await insertSyncedExercise(serverId: 'server-e1');

      api.stubEmptyPull();
      api.getResponses['api/Workout'] = [
        serverWorkout(
          id: 'server-w1',
          name: 'Push Day',
          exercises: [
            serverWorkoutExercise(
              id: 'server-we1',
              exerciseId: 'server-e1',
              orderPosition: 0,
              setTemplates: [
                serverSetTemplate(id: 'st1', setNumber: 1),
                serverSetTemplate(id: 'st2', setNumber: 2),
                // The prescription pushed a second time, before the API
                // switched from appending to replacing.
                serverSetTemplate(id: 'st3', setNumber: 1),
                serverSetTemplate(id: 'st4', setNumber: 2),
              ],
            ),
            // A retried POST that the API had no idempotency for: same exercise,
            // same slot, second row.
            serverWorkoutExercise(
              id: 'server-we2',
              exerciseId: 'server-e1',
              orderPosition: 0,
              setTemplates: [serverSetTemplate(id: 'st5', setNumber: 1)],
            ),
          ],
        ),
      ];

      await sync.pullAll();

      final exercises = await db.select(db.workoutExerciseTable).get();
      expect(exercises, hasLength(1));
      final templates = await db.select(db.workoutSetTemplateTable).get();
      expect(templates.map((t) => t.setNumber).toList()..sort(), [1, 2]);
    });

    test('keeps a superset that repeats the same exercise', () async {
      await insertSyncedExercise(serverId: 'server-e1');

      api.stubEmptyPull();
      api.getResponses['api/Workout'] = [
        serverWorkout(
          id: 'server-w1',
          name: 'Push Day',
          exercises: [
            serverWorkoutExercise(
              id: 'server-we1',
              exerciseId: 'server-e1',
              orderPosition: 0,
            ),
            // Same movement, different slot — a real pairing, not a duplicate.
            serverWorkoutExercise(
              id: 'server-we2',
              exerciseId: 'server-e1',
              orderPosition: 1,
            ),
          ],
        ),
      ];

      await sync.pullAll();

      expect(await db.select(db.workoutExerciseTable).get(), hasLength(2));
    });

    test(
      'leaves a retired exercise out of the workout, but keeps it '
      'resolvable',
      () async {
        await insertSyncedExercise(serverId: 'server-e1');

        api.stubEmptyPull();
        api.getResponses['api/Workout'] = [
          serverWorkout(
            id: 'server-w1',
            name: 'Push Day',
            exercises: [
              serverWorkoutExercise(
                id: 'server-we1',
                exerciseId: 'server-e1',
                orderPosition: 0,
                removedAt: '2026-01-01T00:00:00Z',
              ),
            ],
          ),
        ];

        await sync.pullAll();

        // Not visible in the workout the user sees...
        final workout = await db.workoutDao.getWorkoutByServerId('server-w1');
        final visible = await db.workoutDao.getWorkoutExercisesWithTemplates(
          workout!.id,
        );
        expect(visible, isEmpty);

        // ...but still on disk (syncStatus 4: retired) so a scheduled
        // exercise pulled afterwards has a row to link its logged sets to.
        final rows = await db.select(db.workoutExerciseTable).get();
        expect(rows, hasLength(1));
        expect(rows.single.serverId, 'server-we1');
        expect(rows.single.syncStatus, 4);
      },
    );
  });

  group('pulling a scheduled workout logged against a retired exercise', () {
    test(
      'still pulls the set, using the retired placeholder to resolve it',
      () async {
        await insertSyncedExercise(serverId: 'server-e1');

        api.stubEmptyPull();
        api.getResponses['api/Workout'] = [
          serverWorkout(
            id: 'server-w1',
            name: 'Push Day',
            exercises: [
              serverWorkoutExercise(
                id: 'server-we1',
                exerciseId: 'server-e1',
                orderPosition: 0,
                removedAt: '2026-01-01T00:00:00Z',
              ),
            ],
          ),
        ];
        api.getResponses['api/ScheduledWorkout'] = [
          serverScheduledWorkout(
            id: 'server-sw1',
            workoutId: 'server-w1',
            exercises: [
              serverScheduledExercise(
                id: 'server-se1',
                workoutExerciseId: 'server-we1',
                sets: [
                  serverSet(
                    id: 'server-set1',
                    setNumber: 1,
                    reps: 8,
                    weight: 60,
                  ),
                ],
              ),
            ],
          ),
        ];

        await sync.pullAll();

        final sets = await db.select(db.workoutSetTable).get();
        expect(sets, hasLength(1));
        expect(sets.single.serverId, 'server-set1');
        expect(sets.single.reps, 8);
      },
    );
  });

  group('pulling meals', () {
    test(
      'keeps the meal and its resolvable entries when the primary food '
      'reference was deleted',
      () async {
        api.stubEmptyPull();
        // 'server-deleted' never appears here — the food it once named is
        // gone from the account entirely, same as a real deletion.
        api.getResponses['api/FoodItem'] = [
          serverFoodItem(id: 'server-oats', name: 'Oats'),
        ];
        api.getResponses['api/Meal/all'] = [
          serverMeal(
            id: 'server-m1',
            // The meal's vestigial "primary" food — deleted since this meal
            // was first logged.
            foodItemId: 'server-deleted',
            foodEntries: [
              serverFoodEntry(id: 'server-fe1', foodItemId: 'server-oats'),
            ],
          ),
        ];

        await sync.pullAll();

        final meals = await db.select(db.mealTable).get();
        expect(meals, hasLength(1));
        expect(meals.single.serverId, 'server-m1');

        final entries = await db.mealDao.getFoodItemsForMeal(meals.single.id);
        expect(entries, hasLength(1));
      },
    );
  });

  group('pushing exercises the server already has', () {
    test('links to the existing row instead of creating a second', () async {
      final exerciseId = await insertSyncedExercise(serverId: 'server-e1');
      final workoutId = await db.workoutDao.saveCompleteWorkout(
        Workout(
          name: 'Push Day',
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
      // The workout synced, but the exercise's serverId never made it back —
      // the response was lost after the server had already committed the row.
      await db.workoutDao.markWorkoutSynced(workoutId, 'server-w1');

      api.stubEmptyPull();
      api.getResponses['api/Workout'] = [
        serverWorkout(id: 'server-w1', name: 'Push Day'),
      ];
      api.getResponses['api/Workout/server-w1'] = serverWorkout(
        id: 'server-w1',
        name: 'Push Day',
        exercises: [
          serverWorkoutExercise(
            id: 'server-we1',
            exerciseId: 'server-e1',
            orderPosition: 0,
          ),
        ],
      );

      await sync.syncAll();

      expect(
        api.posts.where((p) => p.path.contains('/exercises/batch')),
        isEmpty,
        reason: 'the server already has this exercise',
      );
      final we =
          await (db.select(db.workoutExerciseTable)
            ..where((t) => t.workoutId.equals(workoutId))).getSingle();
      expect(we.serverId, 'server-we1');
    });

    test('creates one the server genuinely does not have', () async {
      final exerciseId = await insertSyncedExercise(serverId: 'server-e1');
      final workoutId = await db.workoutDao.saveCompleteWorkout(
        Workout(
          name: 'Push Day',
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
      await db.workoutDao.markWorkoutSynced(workoutId, 'server-w1');

      api.stubEmptyPull();
      api.getResponses['api/Workout'] = [
        serverWorkout(id: 'server-w1', name: 'Push Day'),
      ];
      api.getResponses['api/Workout/server-w1'] = serverWorkout(
        id: 'server-w1',
        name: 'Push Day',
      );
      api.postResponses['api/Workout/server-w1/exercises/batch'] = [
        {'id': 'server-we-new'},
      ];

      await sync.syncAll();

      expect(
        api.posts.map((p) => p.path),
        contains('api/Workout/server-w1/exercises/batch'),
      );
    });
  });

  group('countUnsyncedChanges', () {
    test('counts pending work and ignores synced rows', () async {
      expect(await db.countUnsyncedChanges(), 0);

      final id = await db.workoutDao.saveCompleteWorkout(
        Workout(
          name: 'Push Day',
          difficulty: WorkoutDifficulty.beginner,
          exercises: const [],
        ),
      );
      expect(await db.countUnsyncedChanges(), 1);

      await db.workoutDao.markWorkoutSynced(id, 'server-w1');
      expect(await db.countUnsyncedChanges(), 0);
    });
  });
}
