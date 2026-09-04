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
import 'database/tables/weight_tables.dart';
import 'database/tables/workout_tables.dart';

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
  /// Counts every table carrying a `syncStatus`, where `1` is `SyncStatus.synced`
  /// and every other value is work that has not reached the server. Built-in
  /// exercises are seeded locally and never pushed, so only the user's own custom
  /// ones count.
  ///
  /// One statement rather than a dozen round trips, because this runs on the
  /// sign-out tap and the user is waiting on it.
  Future<int> countUnsyncedChanges() async {
    const sql = '''
      SELECT
        (SELECT COUNT(*) FROM workout_table                     WHERE sync_status != 1) +
        (SELECT COUNT(*) FROM workout_exercise_table            WHERE sync_status != 1) +
        (SELECT COUNT(*) FROM workout_set_template_table        WHERE sync_status != 1) +
        (SELECT COUNT(*) FROM workout_set_table                 WHERE sync_status != 1) +
        (SELECT COUNT(*) FROM scheduled_workout_table           WHERE sync_status != 1) +
        (SELECT COUNT(*) FROM scheduled_workout_exercise_table  WHERE sync_status != 1) +
        (SELECT COUNT(*) FROM workout_plan_table                WHERE sync_status != 1) +
        (SELECT COUNT(*) FROM workout_plan_workout_table        WHERE sync_status != 1) +
        (SELECT COUNT(*) FROM meal_table                        WHERE sync_status != 1) +
        (SELECT COUNT(*) FROM food_item                         WHERE sync_status != 1) +
        (SELECT COUNT(*) FROM weight_record                     WHERE sync_status != 1) +
        (SELECT COUNT(*) FROM exercise_table                    WHERE sync_status != 1 AND is_custom = 1) +
        -- Chat has its own status column: 1 is sent, 0 pending and 2 failed.
        -- An unsent message is lost by the wipe exactly like an unsynced set.
        (SELECT COUNT(*) FROM chat_out_box_table                WHERE chat_message_status != 1)
      AS total
    ''';
    final row = await customSelect(sql).getSingle();
    return row.read<int>('total');
  }

  /// Deletes all user-generated data from every table.
  /// Call this on logout so the next user starts with a clean local DB.
  Future<void> clearAllUserData() async {
    await transaction(() async {
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
      // Keep built-in exercises; remove only user-created ones
      await (delete(exerciseTable)..where((e) => e.isCustom.equals(true))).go();
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
  @override
  int get schemaVersion => 38;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
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
    },
  );

  // Workout planning DAOs
  late final exerciseDao = ExerciseDao(this);
  late final workoutDao = WorkoutDao(this);
  late final workoutPlanDao = WorkoutPlanDao(this);
}
