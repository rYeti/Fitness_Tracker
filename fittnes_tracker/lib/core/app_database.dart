import 'dart:async';

import 'package:drift/drift.dart';
import 'app_database_connection.dart'
    if (dart.library.io) 'app_database_connection_native.dart'
    if (dart.library.html) 'app_database_connection_web.dart';

import 'database/daos/chatOutbox_dao.dart';
import 'database/daos/exercise_dao.dart';
import 'database/daos/food_item_dao.dart';
import 'database/daos/meal_dao.dart';
import 'database/daos/scheduled_workout_dao.dart';
import 'database/daos/scheduled_workout_exercise_dao.dart';
import 'database/daos/search_cache_dao.dart';
import 'database/daos/user_settings_dao.dart';
import 'database/daos/weight_record_dao.dart';
import 'database/daos/workout_dao.dart';
import 'database/daos/workout_plan_dao.dart';
import 'database/daos/workout_set_template_dao.dart';
import 'database/tables/chatOutbox_table.dart';
import 'database/tables/food_tables.dart';
import 'database/tables/sync_tables.dart';
import 'database/tables/weight_tables.dart';
import 'database/tables/workout_tables.dart';
import 'sync/sync_triggers.dart';

export 'database/daos/chatOutbox_dao.dart';
export 'database/daos/exercise_dao.dart';
export 'database/daos/food_item_dao.dart';
export 'database/daos/meal_dao.dart';
export 'database/daos/scheduled_workout_dao.dart';
export 'database/daos/scheduled_workout_exercise_dao.dart';
export 'database/daos/search_cache_dao.dart';
export 'database/daos/user_settings_dao.dart';
export 'database/daos/weight_record_dao.dart';
export 'database/daos/workout_dao.dart';
export 'database/daos/workout_plan_dao.dart';
export 'database/daos/workout_set_template_dao.dart';
export 'database/tables/chatOutbox_table.dart';
export 'database/tables/food_tables.dart';
export 'database/tables/sync_tables.dart';
export 'database/tables/weight_tables.dart';
export 'database/tables/workout_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    FoodItem,
    VerifiedFoodTable,
    UserSettings,
    MealTable,
    MealFoodTable,
    SearchCacheTable,
    WeightRecord,
    // Workout planning tables
    ExerciseTable,
    WorkoutTable,
    WorkoutPlanTable,
    WorkoutExerciseTable,
    WorkoutSetTable,
    WorkoutPlanWorkoutTable,
    ScheduledWorkoutTable,
    WorkoutSetTemplateTable,
    ScheduledWorkoutExerciseTable,
    ChatOutBoxTable,
    // Sync bookkeeping — see lib/core/sync/sync_triggers.dart
    SyncDeletionTable,
    SyncApplyGuardTable,
    SyncLeaseTable,
  ],
  daos: [
    FoodItemDao,
    UserSettingsDao,
    MealDao,
    SearchCacheDao,
    WeightRecordDao,
    // Workout planning DAOs
    ExerciseDao,
    WorkoutDao,
    WorkoutPlanDao,
    ScheduledWorkoutDao,
    ScheduledWorkoutExerciseDao,
    WorkoutSetTemplateTableDao,
    ChatoutboxDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(connect());

  /// Test constructor that allows providing a custom [QueryExecutor],
  /// useful for in-memory tests.
  AppDatabase.test(QueryExecutor executor) : super(executor);

  /// How many rows are still waiting to reach the server.
  ///
  /// [clearAllUserData] is unrecoverable for anything that has not synced — the
  /// row is the only record that the change happened, and for a pendingDelete
  /// row it is the only record that the *deletion* happened. Signing out has to
  /// be able to say how much would go, so the user can choose.
  ///
  /// Counts rows in a state the push will act on — `pending` (0),
  /// `pendingUpdate` (2) and `pendingDelete` (3) — plus deletions the database
  /// recorded in `sync_deletion_table`. `synced` (1) and `retired` (4) are
  /// not work, and neither is a non-template workout, which the push never
  /// sends: counting either used to keep the sign-out warning up forever on
  /// any device that had one. Built-in exercises are seeded locally and never
  /// pushed, so only the user's own custom ones count.
  ///
  /// One statement rather than a dozen round trips, because this runs on the
  /// sign-out tap and the user is waiting on it.
  ///
  /// [includeChat] is for sign-out, which loses unsent messages too; the push
  /// scheduler asks about sync alone, since chat sends through its own outbox.
  Future<int> countUnsyncedChanges({bool includeChat = true}) async {
    final sql = '''
      SELECT
        (SELECT COUNT(*) FROM workout_table                     WHERE sync_status IN (0, 2, 3) AND is_template = 1) +
        (SELECT COUNT(*) FROM workout_exercise_table            WHERE sync_status IN (0, 2, 3)) +
        (SELECT COUNT(*) FROM workout_set_template_table        WHERE sync_status IN (0, 2, 3)) +
        (SELECT COUNT(*) FROM workout_set_table                 WHERE sync_status IN (0, 2, 3)) +
        (SELECT COUNT(*) FROM scheduled_workout_table           WHERE sync_status IN (0, 2, 3)) +
        (SELECT COUNT(*) FROM scheduled_workout_exercise_table  WHERE sync_status IN (0, 2, 3)) +
        (SELECT COUNT(*) FROM workout_plan_table                WHERE sync_status IN (0, 2, 3)) +
        (SELECT COUNT(*) FROM workout_plan_workout_table        WHERE sync_status IN (0, 2, 3)) +
        (SELECT COUNT(*) FROM meal_table                        WHERE sync_status IN (0, 2, 3)) +
        (SELECT COUNT(*) FROM food_item                         WHERE sync_status IN (0, 2, 3)) +
        (SELECT COUNT(*) FROM weight_record                     WHERE sync_status IN (0, 2, 3)) +
        (SELECT COUNT(*) FROM exercise_table                    WHERE sync_status IN (0, 2, 3) AND is_custom = 1) +
        (SELECT COUNT(*) FROM sync_deletion_table) +
        -- Chat has its own status column: 1 is sent, 0 pending and 2 failed.
        -- An unsent message is lost by the wipe exactly like an unsynced set.
        ${includeChat ? '(SELECT COUNT(*) FROM chat_out_box_table WHERE chat_message_status != 1)' : '0'}
      AS total
    ''';
    final row = await customSelect(sql).getSingle();
    return row.read<int>('total');
  }

  /// Deletes all user-generated data from every table.
  /// Call this on logout so the next user starts with a clean local DB.
  ///
  /// [untracked], and the deletion outbox is emptied with it. Emptying a synced
  /// table is not the user deleting their data — recorded as a deletion, it
  /// would reach the server as a DELETE for every row the account owns the
  /// next time anyone signed in on this device.
  Future<void> clearAllUserData() async {
    await untracked(() async {
      await delete(mealFoodTable).go();
      await delete(mealTable).go();
      await delete(foodItem).go();
      await delete(workoutSetTable).go();
      await delete(workoutSetTemplateTable).go();
      await delete(scheduledWorkoutExerciseTable).go();
      await delete(workoutExerciseTable).go();
      await delete(scheduledWorkoutTable).go();
      await delete(workoutPlanWorkoutTable).go();
      await delete(workoutTable).go();
      await delete(workoutPlanTable).go();
      await delete(weightRecord).go();
      await delete(userSettings).go();
      await delete(searchCacheTable).go();
      await delete(chatOutBoxTable).go();
      await delete(syncDeletionTable).go();
      // Keep built-in exercises; remove only user-created ones
      await (delete(exerciseTable)..where((e) => e.isCustom.equals(true))).go();
    });
  }

  static final _untrackedZone = Object();

  /// Runs [body] as the sync engine: none of its writes counts as a local
  /// change.
  ///
  /// The sync triggers (`lib/core/sync/sync_triggers.dart`) mark a row dirty
  /// whenever a pushed column changes and record every deleted row the server
  /// still has. That is right for a user's edit and wrong for the sync engine
  /// writing what the server just sent, marking a row synced, or removing a
  /// row the server already removed — so this sets the one flag every trigger
  /// checks, for the length of a transaction. Drift runs nothing else on this
  /// connection while a transaction is open, and SQLite lets no other
  /// connection write, so no user edit can land while the flag is up and be
  /// missed. The flag is cleared before the transaction commits, and a
  /// transaction that throws rolls it back, so it is never left set.
  ///
  /// Keep [body] to database work. It holds the write lock, so a network call
  /// inside it would stall every save in the app until the call returned.
  ///
  /// Calls nest: an inner call inside an outer one just runs its body.
  Future<T> untracked<T>(Future<T> Function() body) {
    if (Zone.current[_untrackedZone] == true) return body();
    return transaction(() async {
      await customStatement(
        'UPDATE sync_apply_guard_table SET active = 1 WHERE id = 1',
      );
      final result = await runZoned(
        body,
        zoneValues: {_untrackedZone: true},
      );
      await customStatement(
        'UPDATE sync_apply_guard_table SET active = 0 WHERE id = 1',
      );
      return result;
    });
  }

  /// 37 exists for `chat_out_box_table`, which shipped without a bump and so was
  /// never created on any install that already existed — `onUpgrade` only runs
  /// when the stored `user_version` is behind this number. Adding the table to
  /// the `@DriftDatabase` list creates it on fresh installs (and in every test,
  /// which is why nothing caught this), but upgraded devices kept a database with
  /// no outbox in it, and every send threw before it reached the network.
  ///
  /// No `if (from < 37)` branch: `onUpgrade` opens with `createAll()`, which
  /// emits `CREATE TABLE IF NOT EXISTS`, so the table is created and existing
  /// ones are untouched. **Do not delete this bump as a no-op** — the bump is the
  /// entire fix.
  ///
  /// 38 adds `verified_food_table.extended_nutrients_json` — see
  /// `if (from < 38)` below and `docs/trainer-console-micronutrients.md`.
  ///
  /// 39 adds `attachment_manifest`, `attachment_local_path` and
  /// `upload_status` to `chat_out_box_table`, for media attachments. See the
  /// `if (from < 39)` branch below for why each `ALTER` needs its own
  /// `try/catch`, not just one around the block — the 37 comment above
  /// explains the same `createAll()`-then-`ALTER` interaction that makes it
  /// necessary here too.
  ///
  /// 40 changes no table. It re-queues every synced logged set that carries an
  /// RPE, a set type or a side, because none of the three was ever pushed
  /// before this version — see `if (from < 40)` and `docs/logged-set-sync.md`.
  ///
  /// 41 adds `local_rev` to every synced entity table and the three sync
  /// bookkeeping tables in `sync_tables.dart`. The triggers that use them are
  /// not part of any migration: [installSyncTriggers] reinstalls them from code
  /// on every open. See `docs/sync-architecture.md` §3.
  ///
  /// 42 changes no table's shape. The device now mints every row's
  /// `server_id` on insert (`newSyncId`), so every existing row that has none
  /// is given one, and "not pushed yet" becomes `sync_status = 0` alone. See
  /// `if (from < 42)` and `docs/sync-architecture.md` part two.
  @override
  int get schemaVersion => 42;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    beforeOpen: (details) async {
      // The guard is only ever set inside a transaction that clears it again
      // before committing, so this should never find it set. If it ever did,
      // every sync trigger would stay silent for good — so it is cleared on
      // every open rather than trusted.
      await customStatement(
        'INSERT INTO sync_apply_guard_table (id, active) VALUES (1, 0) '
        'ON CONFLICT(id) DO UPDATE SET active = 0',
      );
      await customStatement(
        'INSERT OR IGNORE INTO sync_lease_table (id, holder, expires_at) '
        'VALUES (1, NULL, 0)',
      );
      await installSyncTriggers(this);
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // try {
      await m.createAll();
      if (from < 17) {
        await customStatement(
          'ALTER TABLE scheduled_workout_table ADD COLUMN is_skipped INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (from < 18) {
        await customStatement(
          'ALTER TABLE food_item ADD COLUMN hidden_from_recent INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (from < 19) {
        try {
          await customStatement(
            'ALTER TABLE user_settings ADD COLUMN starting_weight REAL NOT NULL DEFAULT 80.0',
          );
        } catch (_) {}
        try {
          await customStatement(
            'ALTER TABLE user_settings ADD COLUMN goal_weight REAL NOT NULL DEFAULT 70.0',
          );
        } catch (_) {}
      }
      if (from < 20) {
        try {
          await customStatement(
            "ALTER TABLE user_settings ADD COLUMN name TEXT NOT NULL DEFAULT ''",
          );
        } catch (_) {}
      }
      if (from < 21) {
        try {
          await customStatement(
            'ALTER TABLE scheduled_workout_exercise_table ADD COLUMN override_exercise_id INTEGER',
          );
        } catch (_) {}
      }
      if (from < 22) {
        try {
          await customStatement(
            'ALTER TABLE workout_exercise_table ADD COLUMN superset_group_id INTEGER',
          );
        } catch (_) {}
      }
      if (from < 23) {
        try {
          await customStatement(
            'ALTER TABLE workout_table ADD COLUMN color INTEGER',
          );
        } catch (_) {}
      }
      if (from < 24) {
        try {
          await customStatement(
            'ALTER TABLE workout_plan_table ADD COLUMN is_free_choice INTEGER NOT NULL DEFAULT 0',
          );
        } catch (_) {}
      }
      if (from < 25) {
        try {
          await customStatement(
            'ALTER TABLE exercise_table ADD COLUMN is_custom INTEGER NOT NULL DEFAULT 0',
          );
        } catch (_) {}
      }
      if (from < 26) {
        try {
          await customStatement(
            'ALTER TABLE exercise_table ADD COLUMN name_de TEXT',
          );
        } catch (_) {}
        try {
          await customStatement(
            'ALTER TABLE exercise_table ADD COLUMN description_de TEXT',
          );
        } catch (_) {}
      }

      if (from < 27) {
        try {
          await customStatement(
            'ALTER TABLE weight_record ADD COLUMN sync_status INTEGER NOT NULL DEFAULT 0',
          );
        } catch (_) {}
        try {
          await customStatement(
            'ALTER TABLE weight_record ADD COLUMN server_id TEXT',
          );
        } catch (_) {}
      }

      if (from < 28) {
        try {
          await customStatement(
            'ALTER TABLE food_item ADD COLUMN extended_nutrients_json TEXT',
          );
        } catch (_) {}
      }

      if (from < 29) {
        // Add server_id to all tables that sync with the remote API.
        // Null until the record has been pushed and the server assigns a Guid.
        for (final table in [
          'exercise_table',
          'workout_table',
          'workout_exercise_table',
          'workout_set_template_table',
          'workout_plan_table',
          'workout_plan_workout_table',
          'scheduled_workout_table',
          'scheduled_workout_exercise_table',
          'workout_set_table',
        ]) {
          try {
            await customStatement(
              'ALTER TABLE $table ADD COLUMN server_id TEXT',
            );
          } catch (_) {}
        }
      }

      if (from < 30) {
        // Add user profile fields to match the remote API's User model.
        for (final stmt in [
          "ALTER TABLE user_table ADD COLUMN first_name TEXT NOT NULL DEFAULT ''",
          "ALTER TABLE user_table ADD COLUMN last_name TEXT NOT NULL DEFAULT ''",
          'ALTER TABLE user_table ADD COLUMN date_of_birth INTEGER',
        ]) {
          try {
            await customStatement(stmt);
          } catch (_) {}
        }
      }

      if (from < 31) {
        // Add sync_status to all tables that were missing it.
        for (final table in [
          'food_item',
          'meal_table',
          'meal_food_table',
          'exercise_table',
          'workout_table',
          'workout_exercise_table',
          'workout_set_template_table',
          'workout_plan_table',
          'workout_plan_workout_table',
          'scheduled_workout_table',
          'scheduled_workout_exercise_table',
          'workout_set_table',
        ]) {
          try {
            await customStatement(
              'ALTER TABLE $table ADD COLUMN sync_status INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {}
        }
        // Add server_id to food tracking tables (workout tables already have it from v29).
        for (final table in ['food_item', 'meal_table', 'meal_food_table']) {
          try {
            await customStatement(
              'ALTER TABLE $table ADD COLUMN server_id TEXT',
            );
          } catch (_) {}
        }
      }

      if (from < 32) {
        try {
          await customStatement(
            'ALTER TABLE workout_plan_table ADD COLUMN duration_days INTEGER',
          );
        } catch (_) {}
      }

      if (from < 33) {
        // Re-apply duration_days for devices that were already at v32 before
        // the column was added to the schema (the from<32 guard never ran).
        try {
          await customStatement(
            'ALTER TABLE workout_plan_table ADD COLUMN duration_days INTEGER',
          );
        } catch (_) {}
      }

      if (from < 34) {
        try {
          await customStatement(
            'ALTER TABLE food_item ADD COLUMN open_food_facts_id TEXT',
          );
        } catch (_) {}
      }

      if (from < 35) {
        // RPE + set type + unilateral side on logged sets, in one migration.
        for (final stmt in [
          'ALTER TABLE workout_set_table ADD COLUMN rpe INTEGER',
          'ALTER TABLE workout_set_table ADD COLUMN set_type INTEGER NOT NULL DEFAULT 0',
          'ALTER TABLE workout_set_table ADD COLUMN side INTEGER NOT NULL DEFAULT 0',
        ]) {
          try {
            await customStatement(stmt);
          } catch (_) {}
        }
      }

      if (from < 38) {
        try {
          await customStatement(
            'ALTER TABLE verified_food_table ADD COLUMN extended_nutrients_json TEXT',
          );
        } catch (_) {}
      }

      if (from < 39) {
        // Each statement gets its own try/catch, not one around the whole
        // block: an install upgrading from *before* 37 has no outbox table at
        // all, so the `createAll()` at the top of this method creates it with
        // these three columns already present, and the ALTER below then fails
        // on "duplicate column name" — a failure this branch must survive to
        // reach the next one, not abort on. Only a device already at exactly
        // 37 (an existing table, missing these columns) needs the ALTER to
        // actually run.
        for (final stmt in [
          'ALTER TABLE chat_out_box_table ADD COLUMN attachment_manifest TEXT',
          'ALTER TABLE chat_out_box_table ADD COLUMN attachment_local_path TEXT',
          'ALTER TABLE chat_out_box_table ADD COLUMN upload_status INTEGER NOT NULL DEFAULT 0',
        ]) {
          try {
            await customStatement(stmt);
          } catch (_) {}
        }
      }

      if (from < 40) {
        // RPE, set type and side have been stored on logged sets since 35 but
        // were never sent, so every synced set carrying one holds a value the
        // server has never seen. The sync pull skips a set it already has and
        // can't notice, so the device has to volunteer them: flag the rows as
        // edited and the ordinary pending-update push sends them. No try/catch:
        // the columns exist by now on every path through this method, and a
        // failure here should surface, not leave the values stranded silently.
        await customStatement(
          'UPDATE workout_set_table SET sync_status = 2 '
          'WHERE sync_status = 1 AND server_id IS NOT NULL '
          'AND (rpe IS NOT NULL OR set_type != 0 OR side != 0)',
        );
      }

      if (from < 41) {
        // The bookkeeping tables are new and already made by `createAll()`
        // above; only the column needs adding to tables that existed.
        for (final table in [
          'exercise_table',
          'workout_table',
          'workout_exercise_table',
          'scheduled_workout_exercise_table',
          'scheduled_workout_table',
          'workout_plan_table',
          'food_item',
          'meal_table',
          'weight_record',
        ]) {
          try {
            await customStatement(
              'ALTER TABLE $table ADD COLUMN local_rev INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {}
        }
      }

      if (from < 42) {
        // Until now a null `server_id` was how a row said it had never been
        // pushed. From here every row carries an id from the moment it is
        // inserted, so that fact moves to the status. In order:
        //
        // 1. A meal or plan whose list holds a food or workout the server
        //    never got is dirtied: its push now sends the whole list, so the
        //    missing one goes with it. Left synced, the pull — which now makes
        //    a clean meal or plan match the server's list — would delete it.
        await customStatement(
          'UPDATE meal_table SET sync_status = 2 WHERE sync_status = 1 AND id '
          'IN (SELECT meal_id FROM meal_food_table WHERE server_id IS NULL)',
        );
        await customStatement(
          'UPDATE workout_plan_table SET sync_status = 2 WHERE sync_status = 1 '
          'AND id IN (SELECT plan_id FROM workout_plan_workout_table '
          'WHERE sync_status != 1)',
        );
        // 2. A row with no id that is marked edited was never created on the
        //    server — the push used to catch that by the null id and POST
        //    it — so it is pending, which is what will now POST it.
        //    Built-in exercises are the server's rows and keep no id until
        //    they are linked to one by name.
        for (final (table, onlyWhere) in _tablesWithDeviceIds) {
          await customStatement(
            'UPDATE $table SET sync_status = 0 WHERE server_id IS NULL '
            'AND sync_status IN (1, 2)$onlyWhere',
          );
        }
        // 3. Every row without an id gets one. The same expression runs per
        //    row, so each gets its own.
        for (final (table, onlyWhere) in [
          ..._tablesWithDeviceIds,
          ('meal_food_table', ''),
        ]) {
          await customStatement(
            'UPDATE $table SET server_id = $_sqlNewSyncId '
            'WHERE server_id IS NULL$onlyWhere',
          );
        }
      }
    },
  );

  /// Tables whose rows get their `server_id` from the device, with any
  /// condition on which rows. The meal-food table gets one too, but has no
  /// `sync_status` of its own (its meal's stands for it), so step 3 above
  /// adds it by hand. A plan link has no id at all: the server never names
  /// one.
  static const _tablesWithDeviceIds = [
    ('exercise_table', ' AND is_custom = 1'),
    ('workout_table', ''),
    ('workout_exercise_table', ''),
    ('workout_set_template_table', ''),
    ('workout_set_table', ''),
    ('scheduled_workout_table', ''),
    ('scheduled_workout_exercise_table', ''),
    ('workout_plan_table', ''),
    ('food_item', ''),
    ('meal_table', ''),
    ('weight_record', ''),
  ];

  /// A random version-4 UUID in SQL, the same shape `newSyncId` returns, for
  /// the migration to give existing rows one without a round trip per row.
  static const _sqlNewSyncId =
      "(lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || "
      "'-4' || substr(lower(hex(randomblob(2))), 2) || '-' || "
      "substr('89ab', 1 + (abs(random()) % 4), 1) || "
      "substr(lower(hex(randomblob(2))), 2) || '-' || "
      'lower(hex(randomblob(6))))';

  // Workout planning DAOs
  late final exerciseDao = ExerciseDao(this);
  late final workoutDao = WorkoutDao(this);
  late final workoutPlanDao = WorkoutPlanDao(this);
}
