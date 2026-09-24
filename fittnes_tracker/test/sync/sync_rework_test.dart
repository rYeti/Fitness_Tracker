import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/dao/meal_template_dao.dart';
import 'package:ForgeForm/core/sync/sync_service.dart';
import 'package:ForgeForm/core/sync/sync_lease.dart';
import 'package:ForgeForm/core/sync/sync_scheduler.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout_exercise.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout_set.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

/// Regression tests for the sync rework — `docs/sync-architecture.md`. Each
/// one was written against the code as it stood and seen to fail there before
/// the change it pins.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeApiClient api;
  late SyncService sync;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SyncService.resetForTesting();
    db = AppDatabase.test(NativeDatabase.memory());
    api = FakeApiClient();
    sync = SyncService(
      db: db,
      apiClient: api,
      mealTemplateDao: MealTemplateDao(db),
    );
  });

  tearDown(() => db.close());

  Future<int> insertSyncedExercise({
    String name = 'Bench Press',
    required String serverId,
  }) => db
      .into(db.exerciseTable)
      .insert(
        ExerciseTableCompanion.insert(
          name: name,
          type: 0,
          targetMuscleGroups: '0',
          isCustom: const Value(false),
          serverId: Value(serverId),
          syncStatus: const Value(1),
        ),
      );

  /// A synced workout named [name], as the sync engine would have stored it.
  Future<int> insertSyncedWorkout(String name, String serverId) => db.untracked(
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

  Future<int> statusOf(TableInfo table, int id) async {
    final row =
        await db
            .customSelect(
              'SELECT sync_status FROM ${table.actualTableName} WHERE id = ?',
              variables: [Variable.withInt(id)],
            )
            .getSingle();
    return row.read<int>('sync_status');
  }

  // ── The pull ──────────────────────────────────────────────────────────────

  group('a workout holding a retired exercise', () {
    test(
      'can be pulled a second time, and the rest of the pull still runs',
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

        // Something pulled after workouts, to prove the second pull reaches it.
        api.getResponses['api/FoodItem'] = [
          serverFoodItem(id: 'server-f1', name: 'Oats'),
        ];
        await sync.pullAll();

        final foods = await db.select(db.foodItem).get();
        expect(foods.map((f) => f.serverId), ['server-f1']);
      },
    );
  });

  group('a pull step that fails', () {
    test('does not stop the steps after it, and the pull says so', () async {
      api.stubEmptyPull();
      api.getResponses.remove('api/Workout'); // the GET throws
      api.getResponses['api/FoodItem'] = [
        serverFoodItem(id: 'server-f1', name: 'Oats'),
      ];

      await expectLater(
        sync.pullAll(),
        throwsA(
          isA<SyncIncompleteException>().having(
            (e) => e.failedSteps,
            'failedSteps',
            ['workouts'],
          ),
        ),
      );

      final foods = await db.select(db.foodItem).get();
      expect(foods.map((f) => f.serverId), ['server-f1']);
    });
  });

  group('two workouts with the same name', () {
    test('both survive a sync — a name is not an identity', () async {
      await insertSyncedWorkout('Upper A', 'server-mine');
      await insertSyncedWorkout('Upper A', 'server-trainers');
      api.stubEmptyPull();
      api.getResponses['api/Workout'] = [
        serverWorkout(id: 'server-mine', name: 'Upper A'),
        serverWorkout(id: 'server-trainers', name: 'Upper A'),
      ];

      await sync.syncAll();
      await sync.pullAll();

      final rows = await db.select(db.workoutTable).get();
      expect(rows.map((w) => w.serverId).toSet(), {
        'server-mine',
        'server-trainers',
      });
      expect(api.deletes, isEmpty);
    });

    test('a new one is not linked to an unsynced local one by name', () async {
      await db
          .into(db.workoutTable)
          .insert(WorkoutTableCompanion.insert(name: 'Upper A', difficulty: 0));
      api.stubEmptyPull();
      api.getResponses['api/Workout'] = [
        serverWorkout(id: 'server-trainers', name: 'Upper A'),
      ];

      await sync.pullAll();

      final rows = await db.select(db.workoutTable).get();
      expect(rows, hasLength(2));
      // The local one keeps its own id, and is still the push's to create.
      final local = rows.singleWhere((w) => w.serverId != 'server-trainers');
      expect(local.syncStatus, SyncStatus.pending.index);
    });
  });

  // ── Deletion ──────────────────────────────────────────────────────────────

  group('deleting a workout', () {
    test('leaves the logged sets of every other session alone', () async {
      final exerciseId = await insertSyncedExercise(serverId: 'server-e1');
      // Workout A, whose first exercise entry gets local id 1…
      final a = await db.workoutDao.saveCompleteWorkout(
        Workout(
          name: 'A',
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
      final b = await db.workoutDao.saveCompleteWorkout(
        Workout(
          name: 'B',
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
      final aExercise =
          await (db.select(db.workoutExerciseTable)
            ..where((t) => t.workoutId.equals(a))).getSingle();
      final bExercise =
          await (db.select(db.workoutExerciseTable)
            ..where((t) => t.workoutId.equals(b))).getSingle();
      // …and a session of B whose first exercise also gets local id 1, with a
      // set logged in it.
      final session = await db
          .into(db.scheduledWorkoutTable)
          .insert(
            ScheduledWorkoutTableCompanion.insert(
              workoutId: b,
              scheduledDate: DateTime(2026, 1, 5),
            ),
          );
      final sessionExercise = await db
          .into(db.scheduledWorkoutExerciseTable)
          .insert(
            ScheduledWorkoutExerciseTableCompanion.insert(
              scheduledWorkoutId: session,
              workoutExerciseId: bExercise.id,
            ),
          );
      expect(sessionExercise, aExercise.id, reason: 'the collision under test');
      await db
          .into(db.workoutSetTable)
          .insert(
            WorkoutSetTableCompanion.insert(
              scheduledWorkoutExerciseId: sessionExercise,
              setNumber: 1,
              reps: const Value(5),
            ),
          );

      expect(await db.workoutDao.deleteWorkout(a), isTrue);

      expect(await db.select(db.workoutSetTable).get(), hasLength(1));
      final templates = await db.select(db.workoutSetTemplateTable).get();
      expect(templates.map((t) => t.workoutExerciseId), [
        bExercise.id,
      ], reason: "A's prescription goes with it");
    });

    test('is refused while a session of it holds logged sets', () async {
      final w = await insertSyncedWorkout('Push', 'server-w1');
      final we = await db
          .into(db.workoutExerciseTable)
          .insert(
            WorkoutExerciseTableCompanion.insert(
              workoutId: w,
              exerciseId: await insertSyncedExercise(serverId: 'server-e1'),
              orderPosition: 0,
            ),
          );
      final session = await db
          .into(db.scheduledWorkoutTable)
          .insert(
            ScheduledWorkoutTableCompanion.insert(
              workoutId: w,
              scheduledDate: DateTime(2026, 1, 5),
            ),
          );
      final se = await db
          .into(db.scheduledWorkoutExerciseTable)
          .insert(
            ScheduledWorkoutExerciseTableCompanion.insert(
              scheduledWorkoutId: session,
              workoutExerciseId: we,
            ),
          );
      await db
          .into(db.workoutSetTable)
          .insert(
            WorkoutSetTableCompanion.insert(
              scheduledWorkoutExerciseId: se,
              setNumber: 1,
            ),
          );

      expect(await db.workoutDao.deleteWorkout(w), isFalse);
      expect(await db.select(db.workoutTable).get(), hasLength(1));
      expect(await db.select(db.workoutSetTable).get(), hasLength(1));
    });
  });

  group('deleting a plan', () {
    test(
      'keeps every session that was trained, and removes the rest',
      () async {
        final w = await insertSyncedWorkout('Push', 'server-w1');
        final ids = await db.untracked(() async {
          final plan = await db
              .into(db.workoutPlanTable)
              .insert(
                WorkoutPlanTableCompanion.insert(
                  name: 'Block 1',
                  startDate: DateTime(2026, 1, 1),
                  cyclePatternJson: '[]',
                  serverId: const Value('server-p1'),
                  syncStatus: const Value(1),
                ),
              );
          Future<(int, int)> session(
            String serverId,
            int day, {
            bool completed = false,
          }) async {
            final sw = await db
                .into(db.scheduledWorkoutTable)
                .insert(
                  ScheduledWorkoutTableCompanion.insert(
                    workoutId: w,
                    workoutPlanId: Value(plan),
                    scheduledDate: DateTime(2026, 1, day),
                    isCompleted: Value(completed),
                    serverId: Value(serverId),
                    syncStatus: const Value(1),
                  ),
                );
            final se = await db
                .into(db.scheduledWorkoutExerciseTable)
                .insert(
                  ScheduledWorkoutExerciseTableCompanion.insert(
                    scheduledWorkoutId: sw,
                    workoutExerciseId: 1,
                    serverId: Value('$serverId-se'),
                    syncStatus: const Value(1),
                  ),
                );
            return (sw, se);
          }

          final completed = await session('server-done', 5, completed: true);
          final logged = await session('server-logged', 6);
          await db
              .into(db.workoutSetTable)
              .insert(
                WorkoutSetTableCompanion.insert(
                  scheduledWorkoutExerciseId: logged.$2,
                  setNumber: 1,
                  reps: const Value(5),
                  serverId: const Value('server-set1'),
                  syncStatus: const Value(1),
                ),
              );
          final future = await session('server-future', 20);
          return (
            plan: plan,
            completed: completed.$1,
            logged: logged.$1,
            future: future.$1,
          );
        });

        await db.workoutPlanDao.deletePlanKeepingHistory(ids.plan);

        final remaining = await db.select(db.scheduledWorkoutTable).get();
        expect(remaining.map((s) => s.id).toSet(), {ids.completed, ids.logged});
        expect(await db.select(db.workoutSetTable).get(), hasLength(1));
        expect(
          await statusOf(db.workoutPlanTable, ids.plan),
          SyncStatus.pendingDelete.index,
        );

        await sync.syncAll();

        expect(api.deletes.toSet(), {
          'api/ScheduledWorkout/server-future',
          'api/WorkoutPlan/server-p1',
        }, reason: 'nothing that was trained is deleted on the server');
        final kept = await db.select(db.scheduledWorkoutTable).get();
        expect(kept.map((s) => s.workoutPlanId), [
          null,
          null,
        ], reason: 'detached from the deleted plan, as the server does');
        expect(await db.select(db.workoutPlanTable).get(), isEmpty);
      },
    );
  });

  group('removing an exercise that has logged history', () {
    test('retires it instead of deleting it, so the history stays', () async {
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
      final we =
          await (db.select(db.workoutExerciseTable)
            ..where((t) => t.workoutId.equals(workoutId))).getSingle();
      final session = await db.untracked(() async {
        await db.workoutDao.markWorkoutSynced(workoutId, 'server-w1');
        await db.workoutDao.markWorkoutExerciseSynced(we.id, 'server-we1');
        await (db.update(db.workoutSetTemplateTable)).write(
          const WorkoutSetTemplateTableCompanion(
            serverId: Value('server-st1'),
            syncStatus: Value(1),
          ),
        );
        final sw = await db
            .into(db.scheduledWorkoutTable)
            .insert(
              ScheduledWorkoutTableCompanion.insert(
                workoutId: workoutId,
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
                workoutExerciseId: we.id,
                serverId: const Value('server-se1'),
                syncStatus: const Value(1),
              ),
            );
        await db
            .into(db.workoutSetTable)
            .insert(
              WorkoutSetTableCompanion.insert(
                scheduledWorkoutExerciseId: se,
                setNumber: 1,
                reps: const Value(5),
                serverId: const Value('server-set1'),
                syncStatus: const Value(1),
              ),
            );
        return sw;
      });

      // The user takes the exercise out of the workout.
      await db.workoutDao.saveCompleteWorkout(
        Workout(
          id: workoutId,
          name: 'Push Day',
          difficulty: WorkoutDifficulty.beginner,
          exercises: const [],
        ),
      );
      await sync.syncAll();

      expect(api.deletes, contains('api/Workout/exercises/server-we1'));
      final kept =
          await (db.select(db.workoutExerciseTable)
            ..where((t) => t.id.equals(we.id))).getSingle();
      expect(kept.syncStatus, SyncStatus.retired.index);
      // The session still shows the exercise it logged.
      final logged =
          await db.scheduledWorkoutExerciseDao
              .watchForScheduledWorkout(session)
              .first;
      expect(logged, hasLength(1));

      // And the server's retired copy, pulled twice, neither duplicates it
      // nor breaks the pull.
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
              sets: [serverSet(id: 'server-set1', setNumber: 1, reps: 5)],
            ),
          ],
        ),
      ];
      await sync.pullAll();
      await sync.pullAll();
      expect(await db.select(db.workoutExerciseTable).get(), hasLength(1));
    });

    test(
      'a session whose exercise was deleted by an older build is reattached',
      () async {
        await insertSyncedExercise(serverId: 'server-e1');
        final w = await insertSyncedWorkout('Push Day', 'server-w1');
        // The session entry still points at local id 99, which is gone.
        await db.untracked(() async {
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
          await db
              .into(db.scheduledWorkoutExerciseTable)
              .insert(
                ScheduledWorkoutExerciseTableCompanion.insert(
                  scheduledWorkoutId: sw,
                  workoutExerciseId: 99,
                  serverId: const Value('server-se1'),
                  syncStatus: const Value(1),
                ),
              );
        });
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
              ),
            ],
          ),
        ];

        await sync.pullAll();

        final retired = await db.workoutDao.getWorkoutExerciseByServerId(
          'server-we1',
        );
        final se = await db.scheduledWorkoutExerciseDao.getByServerId(
          'server-se1',
        );
        expect(se!.workoutExerciseId, retired!.id);
      },
    );
  });

  group('a row deleted elsewhere', () {
    Future<int> insertWeight(String serverId, {int status = 1}) => db.untracked(
      () => db
          .into(db.weightRecord)
          .insert(
            WeightRecordCompanion.insert(
              date: DateTime(2026, 1, 5),
              weight: 80,
              serverId: Value(serverId),
              syncStatus: Value(status),
            ),
          ),
    );

    test('is deleted here, not pushed back to the server', () async {
      await insertWeight('server-gone');
      api.stubEmptyPull();
      api.getResponses['api/WeightTracking/TrackWeight'] = [
        {'id': 'server-kept', 'date': '2026-01-06T00:00:00Z', 'weight': 79},
      ];

      await sync.pullAll();
      await sync.syncAll();

      final rows = await db.select(db.weightRecord).get();
      expect(rows.map((r) => r.serverId), ['server-kept']);
      expect(api.posts.where((p) => p.path.contains('TrackWeight')), isEmpty);
    });

    test('is kept while it holds an edit this device has not sent', () async {
      await insertWeight('server-gone', status: SyncStatus.pendingUpdate.index);
      api.stubEmptyPull();
      api.getResponses['api/WeightTracking/TrackWeight'] = [
        {'id': 'server-kept', 'date': '2026-01-06T00:00:00Z', 'weight': 79},
      ];

      await sync.pullAll();

      expect(await db.select(db.weightRecord).get(), hasLength(2));
    });

    test('is not assumed from an empty list', () async {
      await insertWeight('server-1');
      api.stubEmptyPull();

      await sync.pullAll();

      expect(await db.select(db.weightRecord).get(), hasLength(1));
    });

    test('a session: goes with its exercises and sets', () async {
      final w = await insertSyncedWorkout('Push', 'server-w1');
      await db.untracked(() async {
        for (final id in ['server-gone', 'server-kept']) {
          final sw = await db
              .into(db.scheduledWorkoutTable)
              .insert(
                ScheduledWorkoutTableCompanion.insert(
                  workoutId: w,
                  scheduledDate: DateTime(2026, 1, id == 'server-gone' ? 5 : 6),
                  serverId: Value(id),
                  syncStatus: const Value(1),
                ),
              );
          final se = await db
              .into(db.scheduledWorkoutExerciseTable)
              .insert(
                ScheduledWorkoutExerciseTableCompanion.insert(
                  scheduledWorkoutId: sw,
                  workoutExerciseId: 1,
                  serverId: Value('$id-se'),
                  syncStatus: const Value(1),
                ),
              );
          await db
              .into(db.workoutSetTable)
              .insert(
                WorkoutSetTableCompanion.insert(
                  scheduledWorkoutExerciseId: se,
                  setNumber: 1,
                  serverId: Value('$id-set'),
                  syncStatus: const Value(1),
                ),
              );
        }
      });
      api.stubEmptyPull();
      api.getResponses['api/Workout'] = [
        serverWorkout(id: 'server-w1', name: 'Push'),
      ];
      api.getResponses['api/ScheduledWorkout'] = [
        serverScheduledWorkout(
          id: 'server-kept',
          workoutId: 'server-w1',
          scheduledDate: '2026-01-06T00:00:00Z',
        ),
      ];

      await sync.pullAll();

      final sessions = await db.select(db.scheduledWorkoutTable).get();
      expect(sessions.map((s) => s.serverId), ['server-kept']);
      expect(
        await db.select(db.scheduledWorkoutExerciseTable).get(),
        hasLength(1),
      );
      expect(await db.select(db.workoutSetTable).get(), hasLength(1));
    });
  });

  group('a synced row deleted on this device', () {
    Future<int> insertSyncedSession() async {
      final w = await insertSyncedWorkout('Push', 'server-w1');
      return db.untracked(
        () => db
            .into(db.scheduledWorkoutTable)
            .insert(
              ScheduledWorkoutTableCompanion.insert(
                workoutId: w,
                scheduledDate: DateTime(2026, 1, 5),
                serverId: const Value('server-sw1'),
                syncStatus: const Value(1),
              ),
            ),
      );
    }

    test('reaches the server as exactly one DELETE', () async {
      final sw = await insertSyncedSession();

      // The calendar's "remove" — a plain delete, with no marker of its own.
      await db.scheduledWorkoutDao.removeScheduled(sw);
      await sync.syncAll();
      await sync.syncAll();

      expect(api.deletes, ['api/ScheduledWorkout/server-sw1']);
      expect(await db.select(db.syncDeletionTable).get(), isEmpty);
    });

    test('is not brought back by a pull before the DELETE is sent', () async {
      final sw = await insertSyncedSession();
      await db.scheduledWorkoutDao.removeScheduled(sw);
      api.stubEmptyPull();
      api.getResponses['api/Workout'] = [
        serverWorkout(id: 'server-w1', name: 'Push'),
      ];
      api.getResponses['api/ScheduledWorkout'] = [
        serverScheduledWorkout(id: 'server-sw1', workoutId: 'server-w1'),
      ];

      await sync.pullAll();

      expect(await db.select(db.scheduledWorkoutTable).get(), isEmpty);
    });

    test('a DELETE the server already answered 404 is not retried', () async {
      final sw = await insertSyncedSession();
      await db.scheduledWorkoutDao.removeScheduled(sw);
      api.deleteStatuses['api/ScheduledWorkout/server-sw1'] = 404;

      await sync.syncAll();

      expect(await db.select(db.syncDeletionTable).get(), isEmpty);
    });

    test('a DELETE that failed for any other reason is kept', () async {
      final sw = await insertSyncedSession();
      await db.scheduledWorkoutDao.removeScheduled(sw);
      api.deleteStatuses['api/ScheduledWorkout/server-sw1'] = 500;

      await sync.syncAll();

      expect(await db.select(db.syncDeletionTable).get(), hasLength(1));
    });

    test('a food taken out of a synced meal is removed from it', () async {
      final meal = await db.untracked(() async {
        final food = await db
            .into(db.foodItem)
            .insert(
              FoodItemCompanion.insert(
                name: 'Oats',
                calories: 100,
                protein: 5,
                carbs: 10,
                fat: 2,
                serverId: const Value('server-f1'),
                syncStatus: const Value(1),
              ),
            );
        final meal = await db
            .into(db.mealTable)
            .insert(
              MealTableCompanion.insert(
                date: DateTime(2026, 1, 5),
                category: 'Breakfast',
                foodItemId: food,
                serverId: const Value('server-m1'),
                syncStatus: const Value(1),
              ),
            );
        await db.mealDao.addFoodToMeal(food, meal, 'server-entry1');
        return (meal: meal, food: food);
      });

      await db.mealDao.deleteFoodFromMeal(meal.food, meal.meal);
      await sync.syncAll();

      // By sending the meal's whole list, now without it — not a DELETE, and
      // nothing recorded for one.
      expect(api.deletes, isEmpty);
      expect(await db.select(db.syncDeletionTable).get(), isEmpty);
      expect(
        api.puts.singleWhere((p) => p.path == 'api/Meal/server-m1/foods').data,
        isEmpty,
      );
      expect(await statusOf(db.mealTable, meal.meal), SyncStatus.synced.index);
    });

    test('signing out is not a deletion', () async {
      await insertSyncedSession();

      await db.clearAllUserData();
      await sync.syncAll();

      expect(await db.select(db.syncDeletionTable).get(), isEmpty);
      expect(api.deletes, isEmpty);
    });
  });

  group('a meal template the server has', () {
    test(
      'is updated there when edited, and deleted there when deleted',
      () async {
        final dao = MealTemplateDao(db);
        final id = await dao.insertTemplate({
          'name': 'Oats',
          'category': 'Breakfast',
          'items': <Map<String, dynamic>>[],
        });
        await dao.markTemplateSynced(id, 'server-t1');

        await dao.updateTemplate({'name': 'Overnight oats'}, id);
        await sync.syncMealTemplates();
        expect(
          api.posts.where((p) => p.path == 'api/MealTemplate'),
          isEmpty,
          reason: 'an edit is not a new template',
        );
        final put = api.puts.singleWhere(
          (p) => p.path == 'api/MealTemplate/server-t1',
        );
        expect((put.data as Map)['name'], 'Overnight oats');
        expect(await dao.getEditedTemplates(), isEmpty);

        await dao.deleteTemplate(id);
        api.stubEmptyPull();
        api.getResponses['api/MealTemplate'] = [
          {'id': 'server-t1', 'name': 'Overnight oats', 'items': <dynamic>[]},
        ];
        await sync.pullAll(); // before the DELETE has gone out
        expect(await dao.getAllTemplates(), isEmpty);

        await sync.syncMealTemplates();
        expect(api.deletes, ['api/MealTemplate/server-t1']);
        expect(await dao.getDeletedServerIds(), isEmpty);
      },
    );
  });

  // ── Changes the database notices by itself ────────────────────────────────

  group('the database marks a synced row changed', () {
    test('when a column the push sends changes', () async {
      final w = await insertSyncedWorkout('Push', 'server-w1');

      // A plain update, the way the workouts list renames a workout — no
      // status set anywhere.
      await (db.update(db.workoutTable)..where(
        (t) => t.id.equals(w),
      )).write(const WorkoutTableCompanion(name: Value('Push A')));

      expect(
        await statusOf(db.workoutTable, w),
        SyncStatus.pendingUpdate.index,
      );
    });

    test('not when the value written is the one already there', () async {
      final w = await insertSyncedWorkout('Push', 'server-w1');

      await (db.update(db.workoutTable)..where(
        (t) => t.id.equals(w),
      )).write(const WorkoutTableCompanion(name: Value('Push')));

      expect(await statusOf(db.workoutTable, w), SyncStatus.synced.index);
    });

    test('not when the sync engine writes it', () async {
      final w = await insertSyncedWorkout('Push', 'server-w1');

      await db.untracked(
        () => (db.update(db.workoutTable)..where(
          (t) => t.id.equals(w),
        )).write(const WorkoutTableCompanion(name: Value('Push A'))),
      );

      expect(await statusOf(db.workoutTable, w), SyncStatus.synced.index);
    });

    test('and never overwrites a pending delete with it', () async {
      final w = await insertSyncedWorkout('Push', 'server-w1');
      await db.workoutDao.markWorkoutPendingDelete(w);

      await (db.update(db.workoutTable)..where(
        (t) => t.id.equals(w),
      )).write(const WorkoutTableCompanion(name: Value('Push A')));

      expect(
        await statusOf(db.workoutTable, w),
        SyncStatus.pendingDelete.index,
      );
    });

    test('for a plan renamed from the workouts list', () async {
      final plan = await db.untracked(
        () => db
            .into(db.workoutPlanTable)
            .insert(
              WorkoutPlanTableCompanion.insert(
                name: 'Block 1',
                startDate: DateTime(2026, 1, 1),
                cyclePatternJson: '[]',
                serverId: const Value('server-p1'),
                syncStatus: const Value(1),
              ),
            ),
      );

      await (db.update(db.workoutPlanTable)..where(
        (t) => t.id.equals(plan),
      )).write(const WorkoutPlanTableCompanion(name: Value('Block 2')));

      expect(
        await statusOf(db.workoutPlanTable, plan),
        SyncStatus.pendingUpdate.index,
      );
    });

    test('for a food hidden from the recent list', () async {
      final food = await db.untracked(
        () => db
            .into(db.foodItem)
            .insert(
              FoodItemCompanion.insert(
                name: 'Oats',
                calories: 100,
                protein: 5,
                carbs: 10,
                fat: 2,
                serverId: const Value('server-f1'),
                syncStatus: const Value(1),
              ),
            ),
      );

      await db.foodItemDao.hideFromRecent('Oats');

      expect(await statusOf(db.foodItem, food), SyncStatus.pendingUpdate.index);
    });

    test('for a custom exercise, and not for a built-in one', () async {
      final builtIn = await insertSyncedExercise(serverId: 'server-e1');
      final custom = await db.untracked(
        () => db
            .into(db.exerciseTable)
            .insert(
              ExerciseTableCompanion.insert(
                name: 'My Curl',
                type: 0,
                targetMuscleGroups: '0',
                isCustom: const Value(true),
                serverId: const Value('server-e2'),
                syncStatus: const Value(1),
              ),
            ),
      );

      for (final id in [builtIn, custom]) {
        await (db.update(db.exerciseTable)..where(
          (t) => t.id.equals(id),
        )).write(const ExerciseTableCompanion(description: Value('edited')));
      }

      expect(
        await statusOf(db.exerciseTable, builtIn),
        SyncStatus.synced.index,
      );
      expect(
        await statusOf(db.exerciseTable, custom),
        SyncStatus.pendingUpdate.index,
      );
    });

    test('when a food is added to a meal that has already synced', () async {
      final ids = await db.untracked(() async {
        final food = await db
            .into(db.foodItem)
            .insert(
              FoodItemCompanion.insert(
                name: 'Oats',
                calories: 100,
                protein: 5,
                carbs: 10,
                fat: 2,
                serverId: const Value('server-f1'),
                syncStatus: const Value(1),
              ),
            );
        final meal = await db
            .into(db.mealTable)
            .insert(
              MealTableCompanion.insert(
                date: DateTime(2026, 1, 5),
                category: 'Breakfast',
                foodItemId: food,
                serverId: const Value('server-m1'),
                syncStatus: const Value(1),
              ),
            );
        return (meal: meal, food: food);
      });
      await db.mealDao.addFoodToMeal(ids.food, ids.meal, null);
      expect(
        await statusOf(db.mealTable, ids.meal),
        SyncStatus.pendingUpdate.index,
      );

      await sync.syncAll();
      final entry = (await db.mealDao.getAllFoodEntriesForMeal(ids.meal)).single;
      expect(
        api.puts.singleWhere((p) => p.path == 'api/Meal/server-m1/foods').data,
        [
          {'id': entry.serverId, 'foodItemId': 'server-f1'},
        ],
      );
      expect(await statusOf(db.mealTable, ids.meal), SyncStatus.synced.index);
    });

    test('when a workout is added to a plan that has already synced', () async {
      final plan = await db.untracked(
        () => db
            .into(db.workoutPlanTable)
            .insert(
              WorkoutPlanTableCompanion.insert(
                name: 'Block 1',
                startDate: DateTime(2026, 1, 1),
                cyclePatternJson: '[]',
                serverId: const Value('server-p1'),
                syncStatus: const Value(1),
              ),
            ),
      );
      final w = await insertSyncedWorkout('Push', 'server-w1');

      await db
          .into(db.workoutPlanWorkoutTable)
          .insert(
            WorkoutPlanWorkoutTableCompanion.insert(planId: plan, workoutId: w),
          );

      expect(
        await statusOf(db.workoutPlanTable, plan),
        SyncStatus.pendingUpdate.index,
      );
    });
  });

  group('an edit made while its push is in flight', () {
    test('stays pending, and the next push sends it', () async {
      final record = await db.untracked(
        () => db
            .into(db.weightRecord)
            .insert(
              WeightRecordCompanion.insert(
                date: DateTime(2026, 1, 5),
                weight: 80,
                serverId: const Value('server-wt1'),
                syncStatus: const Value(1),
              ),
            ),
      );
      Future<void> setWeight(double kg) => (db.update(db.weightRecord)..where(
        (t) => t.id.equals(record),
      )).write(WeightRecordCompanion(weight: Value(kg)));

      await setWeight(81);
      api.duringPut = (_) => setWeight(82);
      await sync.syncAll();

      expect(
        await statusOf(db.weightRecord, record),
        SyncStatus.pendingUpdate.index,
        reason: 'the server has 81; this device has 82',
      );

      api.duringPut = null;
      await sync.syncAll();
      expect((api.puts.last.data as Map)['weight'], 82);
      expect(await statusOf(db.weightRecord, record), SyncStatus.synced.index);
    });
  });

  // ── Links ─────────────────────────────────────────────────────────────────

  group("a session's exercises created on the server", () {
    test('are linked by the exercise they perform, not by position', () async {
      final exerciseId = await insertSyncedExercise(serverId: 'server-e1');
      final w = await insertSyncedWorkout('Push', 'server-w1');
      final ids = await db.untracked(() async {
        final we1 = await db
            .into(db.workoutExerciseTable)
            .insert(
              WorkoutExerciseTableCompanion.insert(
                workoutId: w,
                exerciseId: exerciseId,
                orderPosition: 0,
                serverId: const Value('server-we1'),
                syncStatus: const Value(1),
              ),
            );
        final we2 = await db
            .into(db.workoutExerciseTable)
            .insert(
              WorkoutExerciseTableCompanion.insert(
                workoutId: w,
                exerciseId: exerciseId,
                orderPosition: 1,
                serverId: const Value('server-we2'),
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
        final se1 = await db
            .into(db.scheduledWorkoutExerciseTable)
            .insert(
              ScheduledWorkoutExerciseTableCompanion.insert(
                scheduledWorkoutId: sw,
                workoutExerciseId: we1,
              ),
            );
        final se2 = await db
            .into(db.scheduledWorkoutExerciseTable)
            .insert(
              ScheduledWorkoutExerciseTableCompanion.insert(
                scheduledWorkoutId: sw,
                workoutExerciseId: we2,
              ),
            );
        return (se1: se1, se2: se2);
      });
      // Every entry the session now has, in no particular order.
      api.postResponses['api/ScheduledWorkout/server-sw1/exercises/batch'] = [
        {'id': 'server-se2', 'workoutExerciseId': 'server-we2', 'notes': null},
        {'id': 'server-se1', 'workoutExerciseId': 'server-we1', 'notes': null},
      ];

      await sync.syncAll();

      final se1 =
          await (db.select(db.scheduledWorkoutExerciseTable)
            ..where((t) => t.id.equals(ids.se1))).getSingle();
      final se2 =
          await (db.select(db.scheduledWorkoutExerciseTable)
            ..where((t) => t.id.equals(ids.se2))).getSingle();
      expect(se1.serverId, 'server-se1');
      expect(se2.serverId, 'server-se2');
      // Sent under their own ids, and without first asking the server what
      // the session holds: the batch's answer says that.
      expect(api.gets, isNot(contains('api/ScheduledWorkout/server-sw1')));
      final batch = api.posts.singleWhere(
        (p) => p.path == 'api/ScheduledWorkout/server-sw1/exercises/batch',
      );
      expect(
        (batch.data as List).map((e) => (e as Map)['id']),
        everyElement(isA<String>()),
      );
    });
  });

  // ── Runs and scheduling ───────────────────────────────────────────────────

  group('a deleted workout that sessions logged sets against', () {
    Future<int> seed({String? serverId}) async {
      final exerciseId = await insertSyncedExercise(serverId: 'server-e1');
      return db.untracked(() async {
        final w = await db
            .into(db.workoutTable)
            .insert(
              WorkoutTableCompanion.insert(
                name: 'Push',
                difficulty: 0,
                serverId: Value(serverId),
                syncStatus: Value(serverId == null ? 0 : 1),
              ),
            );
        final we = await db
            .into(db.workoutExerciseTable)
            .insert(
              WorkoutExerciseTableCompanion.insert(
                workoutId: w,
                exerciseId: exerciseId,
                orderPosition: 0,
              ),
            );
        final sw = await db
            .into(db.scheduledWorkoutTable)
            .insert(
              ScheduledWorkoutTableCompanion.insert(
                workoutId: w,
                scheduledDate: DateTime(2026, 1, 5),
              ),
            );
        final se = await db
            .into(db.scheduledWorkoutExerciseTable)
            .insert(
              ScheduledWorkoutExerciseTableCompanion.insert(
                scheduledWorkoutId: sw,
                workoutExerciseId: we,
              ),
            );
        // Logged, but not pushed yet: the server doesn't know about it.
        await db
            .into(db.workoutSetTable)
            .insert(
              WorkoutSetTableCompanion.insert(
                scheduledWorkoutExerciseId: se,
                setNumber: 1,
                reps: const Value(5),
              ),
            );
        return w;
      });
    }

    test('is kept and shown again, never left pending forever', () async {
      final w = await seed(serverId: 'server-w1');
      await db.workoutDao.markWorkoutPendingDelete(w);

      await sync.syncAll();

      expect(api.deletes, isNot(contains('api/Workout/server-w1')));
      // Pending, whether or not the server has it: its create goes out under
      // the id it already has, and the server answers a repeat with its row.
      expect(await statusOf(db.workoutTable, w), SyncStatus.pending.index);

      await sync.syncAll();
      expect(await statusOf(db.workoutTable, w), SyncStatus.synced.index);
      expect(
        api.posts
            .where((p) => p.path == 'api/Workout')
            .map((p) => (p.data as Map)['id']),
        ['server-w1'],
      );
      expect(api.deletes, isEmpty);
    });

    test(
      'one that never reached the server is created there instead',
      () async {
        final w = await seed();
        await db.workoutDao.markWorkoutPendingDelete(w);
        api.postResponses['api/Workout'] = {'id': 'server-w1'};

        await sync.syncAll();
        expect(await statusOf(db.workoutTable, w), SyncStatus.pending.index);

        await sync.syncAll();
        expect(api.posts.map((p) => p.path), contains('api/Workout'));
        expect(await statusOf(db.workoutTable, w), SyncStatus.synced.index);
      },
    );
  });

  group('the sync lease', () {
    test('keeps a second run out while the first holds it', () async {
      int? second;
      await SyncLease.run(db, (_) async {
        second = await SyncLease.run(
          db,
          (_) async => 1,
          wait: const Duration(milliseconds: 300),
        );
        return 0;
      });
      expect(second, isNull);

      expect(await SyncLease.run(db, (_) async => 2), 2);
    });

    test(
      'a run that another has taken it from stops at its next check',
      () async {
        Object? thrown;
        await SyncLease.run(db, (lease) async {
          // Expired while this run was suspended, and taken by another.
          await db.customStatement(
            "UPDATE sync_lease_table SET holder = 'other', "
            'expires_at = ${DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch} '
            'WHERE id = 1',
          );
          try {
            await lease.renew();
          } catch (e) {
            thrown = e;
          }
          return 0;
        });
        expect(thrown, isA<SyncLeaseLostException>());
      },
    );

    test('a push or pull that could not get it says so, instead of returning '
        'as if it had run', () async {
      await db.customStatement(
        "UPDATE sync_lease_table SET holder = 'background', "
        'expires_at = ${DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch} '
        'WHERE id = 1',
      );
      final busy = SyncService(
        db: db,
        apiClient: api,
        mealTemplateDao: MealTemplateDao(db),
        leaseWait: const Duration(milliseconds: 200),
      );

      await expectLater(busy.syncAll(), throwsA(isA<SyncBusyException>()));
      await expectLater(busy.pullAll(), throwsA(isA<SyncBusyException>()));
      expect(api.gets, isEmpty);
    });

    test('is taken over once a crashed holder lets it expire', () async {
      await db.customStatement(
        "UPDATE sync_lease_table SET holder = 'dead', expires_at = 1 WHERE id = 1",
      );
      expect(await SyncLease.run(db, (_) async => 3), 3);
    });
  });

  group('the push scheduler', () {
    test('pushes an edit once the tables go quiet', () async {
      final scheduler = SyncScheduler(
        db: db,
        service: () async => sync,
        debounce: const Duration(milliseconds: 50),
      )..start();
      addTearDown(scheduler.stop);
      api.postResponses['api/WeightTracking/TrackWeight'] = {
        'id': 'server-wt1',
      };

      await db
          .into(db.weightRecord)
          .insert(
            WeightRecordCompanion.insert(
              date: DateTime(2026, 1, 5),
              weight: 80,
            ),
          );
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(
        api.posts.map((p) => p.path),
        contains('api/WeightTracking/TrackWeight'),
      );
      final row = await db.select(db.weightRecord).getSingle();
      expect(row.serverId, 'server-wt1');
      expect(row.syncStatus, SyncStatus.synced.index);
    });

    test('does nothing when nothing is pending', () async {
      final scheduler = SyncScheduler(db: db, service: () async => sync);

      await scheduler.pushNow();

      expect(api.gets, isEmpty);
      expect(api.posts, isEmpty);
      expect(api.puts, isEmpty);
    });
  });
}
