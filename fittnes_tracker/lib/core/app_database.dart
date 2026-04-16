import 'dart:async';
import 'package:ForgeForm/core/utils/app_logger.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout_template_models.dart';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'app_database_connection.dart'
    if (dart.library.io) 'app_database_connection_native.dart'
    if (dart.library.html) 'app_database_connection_web.dart';

// Import workout planning models
import '../feature/workout_planning/data/models/exercise.dart';
import '../feature/workout_planning/data/models/workout.dart';
import '../feature/workout_planning/data/models/workout_exercise.dart';
import '../feature/workout_planning/data/models/workout_plan.dart';
import '../feature/workout_planning/data/models/workout_set.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    FoodItem,
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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(connect());

  /// Test constructor that allows providing a custom [QueryExecutor],
  /// useful for in-memory tests.
  AppDatabase.test(QueryExecutor executor) : super(executor);

  // Workout planning DAOs will be added here after code generation

  @override
  int get schemaVersion => 28;

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

      // Migration from version 1 to 2
      //     if (from < 2) {
      //       await m.addColumn(scheduledWorkoutTable, scheduledWorkoutTable.notes);
      //       await m.addColumn(
      //         scheduledWorkoutExerciseTable,
      //         scheduledWorkoutExerciseTable.notes,
      //       );
      //     }

      //     // Migration from version 2 to 3
      //     if (from < 3) {
      //       await m.addColumn(
      //         scheduledWorkoutTable,
      //         scheduledWorkoutTable.isCompleted,
      //       );
      //       await m.addColumn(
      //         scheduledWorkoutExerciseTable,
      //         scheduledWorkoutExerciseTable.isCompleted,
      //       );
      //     }

      //     // Migration from version 3 to 4
      //     if (from < 4) {
      //       await m.createTable(workoutSetTable);
      //     }

      //     // Migration from version 4 to 5
      //     if (from < 5) {
      //       // Check if column already exists (safety check)
      //       try {
      //         await customSelect(
      //           'SELECT templateWorkoutId FROM scheduled_workout_table LIMIT 1',
      //         ).get();
      //         AppLogger.i('Column templateWorkoutId already exists, skipping');
      //       } catch (e) {
      //         // Column doesn't exist, add it
      //         await m.addColumn(
      //           scheduledWorkoutTable,
      //           scheduledWorkoutTable.templateWorkoutId,
      //         );
      //       }
      //     }

      //     // Migration from version 5 to 6
      //     if (from < 6) {
      //       try {
      //         await customSelect(
      //           'SELECT scheduledDate FROM scheduled_workout_table LIMIT 1',
      //         ).get();
      //         AppLogger.i('Column scheduledDate already exists, skipping');
      //       } catch (e) {
      //         // Column doesn't exist, add it with default value
      //         await customStatement(
      //           'ALTER TABLE scheduled_workout_table ADD COLUMN scheduled_date INTEGER NOT NULL DEFAULT 0',
      //         );
      //       }
      //     }

      //     // Migration from version 6 to 7
      //     if (from < 7) {
      //       // Check if the table has the old structure
      //       try {
      //         await customSelect(
      //           'SELECT scheduledWorkoutExerciseId FROM workout_set_table LIMIT 1',
      //         ).get();
      //         AppLogger.i('workout_set_table already has new structure, skipping');
      //       } catch (e) {
      //         // Need to recreate the table with new structure
      //         AppLogger.i('Recreating workout_set_table with new structure');

      //         // Create temporary table with new structure
      //         await customStatement('''
      //     CREATE TABLE workout_set_table_new (
      //       id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      //       scheduled_workout_exercise_id INTEGER NOT NULL,
      //       set_number INTEGER NOT NULL,
      //       weight REAL,
      //       reps INTEGER,
      //       is_completed INTEGER NOT NULL DEFAULT 0,
      //       FOREIGN KEY (scheduled_workout_exercise_id)
      //         REFERENCES scheduled_workout_exercise_table(id) ON DELETE CASCADE
      //     )
      //   ''');

      //         // Copy data from old table if it exists and has data
      //         try {
      //           await customStatement('''
      //       INSERT INTO workout_set_table_new
      //         (id, scheduled_workout_exercise_id, set_number, weight, reps, is_completed)
      //       SELECT id, scheduled_workout_exercise_id, set_number, weight, reps,
      //              COALESCE(is_completed, 0)
      //       FROM workout_set_table
      //     ''');
      //         } catch (e) {
      //           AppLogger.i('No data to migrate from old workout_set_table: $e');
      //         }

      //         // Drop old table and rename new one
      //         await customStatement('DROP TABLE IF EXISTS workout_set_table');
      //         await customStatement(
      //           'ALTER TABLE workout_set_table_new RENAME TO workout_set_table',
      //         );
      //       }
      //     }

      //     // Migration from version 7 to 8
      //     if (from < 8) {
      //       try {
      //         await customSelect(
      //           'SELECT scheduledWorkoutId, workoutExerciseId FROM scheduled_workout_exercise_table LIMIT 1',
      //         ).get();
      //         AppLogger.i(
      //           'scheduled_workout_exercise_table already has correct structure',
      //         );
      //       } catch (e) {
      //         AppLogger.i(
      //           'Recreating scheduled_workout_exercise_table with correct structure',
      //         );

      //         await customStatement('''
      //     CREATE TABLE scheduled_workout_exercise_table_new (
      //       id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      //       scheduled_workout_id INTEGER NOT NULL,
      //       workout_exercise_id INTEGER NOT NULL,
      //       notes TEXT,
      //       is_completed INTEGER NOT NULL DEFAULT 0,
      //       FOREIGN KEY (scheduled_workout_id)
      //         REFERENCES scheduled_workout_table(id) ON DELETE CASCADE,
      //       FOREIGN KEY (workout_exercise_id)
      //         REFERENCES workout_exercise_table(id) ON DELETE CASCADE
      //     )
      //   ''');

      //         try {
      //           await customStatement('''
      //       INSERT INTO scheduled_workout_exercise_table_new
      //         (id, scheduled_workout_id, workout_exercise_id, notes, is_completed)
      //       SELECT id, scheduled_workout_id, workout_exercise_id, notes,
      //              COALESCE(is_completed, 0)
      //       FROM scheduled_workout_exercise_table
      //     ''');
      //         } catch (e) {
      //           AppLogger.i('No data to migrate: $e');
      //         }

      //         await customStatement(
      //           'DROP TABLE IF EXISTS scheduled_workout_exercise_table',
      //         );
      //         await customStatement(
      //           'ALTER TABLE scheduled_workout_exercise_table_new RENAME TO scheduled_workout_exercise_table',
      //         );
      //       }
      //     }

      //     // Migration from version 8 to 9+
      //     if (from < 9) {
      //       try {
      //         await customSelect(
      //           'SELECT description FROM workout_table LIMIT 1',
      //         ).get();
      //         AppLogger.i('Column description already exists');
      //       } catch (e) {
      //         await m.addColumn(workoutTable, workoutTable.description);
      //       }
      //     }

      //     // Migration from version 9 to 10+
      //     if (from < 10) {
      //       try {
      //         await customSelect(
      //           'SELECT description FROM exercise_table LIMIT 1',
      //         ).get();
      //         AppLogger.i('Column description already exists');
      //       } catch (e) {
      //         await m.addColumn(exerciseTable, exerciseTable.description);
      //       }
      //     }

      //     // Migration from version 10 to 11+
      //     if (from < 11) {
      //       AppLogger.i('Migrating to v11: Ensuring all foreign key constraints');
      //       // This is mostly a consistency check, structure should be correct from v8
      //       AppLogger.i('Foreign key constraints should be in place from v8');
      //     }

      //     // Migration from version 11 to 12+
      //     if (from < 12) {
      //       try {
      //         await customSelect(
      //           'SELECT id FROM user_preferences_table LIMIT 1',
      //         ).get();
      //         AppLogger.i('user_preferences_table already exists');
      //       } catch (e) {}
      //     }

      //     // Migration from version 12 to 13+
      //     if (from < 13) {
      //       // Add indexes for better query performance
      //       try {
      //         await customStatement('''
      //     CREATE INDEX IF NOT EXISTS idx_scheduled_workout_date
      //     ON scheduled_workout_table(scheduled_date)
      //   ''');

      //         await customStatement('''
      //     CREATE INDEX IF NOT EXISTS idx_scheduled_workout_template
      //     ON scheduled_workout_table(template_workout_id)
      //   ''');

      //         await customStatement('''
      //     CREATE INDEX IF NOT EXISTS idx_workout_exercise_workout
      //     ON workout_exercise_table(workout_id)
      //   ''');

      //         await customStatement('''
      //     CREATE INDEX IF NOT EXISTS idx_set_scheduled_exercise
      //     ON workout_set_table(scheduled_workout_exercise_id)
      //   ''');

      //         AppLogger.i('Indexes created successfully');
      //       } catch (e) {
      //         AppLogger.e('Error creating indexes (may already exist): $e');
      //       }
      //     }

      //     // Migration from version 13 to 14+
      //     if (from < 14) {
      //       // Clean up orphaned records
      //       try {
      //         // Delete sets that reference non-existent scheduled exercises
      //         await customStatement('''
      //     DELETE FROM workout_set_table
      //     WHERE scheduled_workout_exercise_id NOT IN (
      //       SELECT id FROM scheduled_workout_exercise_table
      //     )
      //   ''');

      //         // Delete scheduled exercises that reference non-existent scheduled workouts
      //         await customStatement('''
      //     DELETE FROM scheduled_workout_exercise_table
      //     WHERE scheduled_workout_id NOT IN (
      //       SELECT id FROM scheduled_workout_table
      //     )
      //   ''');

      //         AppLogger.i('Data integrity cleanup completed');
      //       } catch (e) {
      //         AppLogger.e('Error during data cleanup: $e');
      //       }
      //     }

      //     // Migration from version 14 to 15+
      //     if (from < 15) {
      //       // Ensure all tables have correct structure
      //       // This is a final validation step
      //       try {
      //         // Validate scheduled_workout_table
      //         await customSelect('''
      //     SELECT id, workout_id, template_workout_id, scheduled_date, notes, is_completed
      //     FROM scheduled_workout_table LIMIT 1
      //   ''').get();

      //         // Validate scheduled_workout_exercise_table
      //         await customSelect('''
      //     SELECT id, scheduled_workout_id, workout_exercise_id, notes, is_completed
      //     FROM scheduled_workout_exercise_table LIMIT 1
      //   ''').get();

      //         // Validate workout_set_table
      //         await customSelect('''
      //     SELECT id, scheduled_workout_exercise_id, set_number, weight, reps, is_completed
      //     FROM workout_set_table LIMIT 1
      //   ''').get();

      //         AppLogger.i('All tables validated successfully');
      //       } catch (e) {
      //         AppLogger.e('Schema validation issue (tables may be empty): $e');
      //       }
      //     }

      //     if (from < 16) {
      //       // Migration from version 15 to 16: Add CASCADE deletes
      //       // Note: SQLite doesn't support ALTER TABLE to modify foreign keys
      //       // So we recreate tables with CASCADE

      //       // For existing users, Drift will handle the schema migration
      //       // New foreign keys with CASCADE will be applied
      //       await m.recreateAllViews();
      //     }
      //   } catch (e, stackTrace) {
      //     AppLogger.e('=== MIGRATION ERROR ===');
      //     AppLogger.e('Error: $e');
      //     AppLogger.e('Stack trace: $stackTrace');

      //     // Log the error but don't crash - try to continue
      //     // In production, you might want to handle this differently
      //     AppLogger.i('Attempting to continue despite error...');
      //     rethrow; // Rethrow to let Drift handle it, but we have logged the details here
      //   }
      // },
      // beforeOpen: (details) async {
      //   // Enable foreign key constraints
      //   await customStatement('PRAGMA foreign_keys = ON');

      //   if (details.hadUpgrade) {
      //     AppLogger.i(
      //       'Database was upgraded from v${details.versionBefore} to v${details.versionNow}',
      //     );
      //   }
      // },
    },
  );

  // Workout planning DAOs
  late final exerciseDao = ExerciseDao(this);
  late final workoutDao = WorkoutDao(this);
  late final workoutPlanDao = WorkoutPlanDao(this);
}

@DriftAccessor(tables: [ScheduledWorkoutTable])
class ScheduledWorkoutDao extends DatabaseAccessor<AppDatabase>
    with _$ScheduledWorkoutDaoMixin {
  ScheduledWorkoutDao(AppDatabase db) : super(db);

  Future<List<ScheduledWorkoutTableData>> getForDate(DateTime date) {
    return (select(scheduledWorkoutTable)
      ..where((t) => t.scheduledDate.equals(date))).get();
  }

  Stream<List<ScheduledWorkoutTableData>> watchForDate(DateTime date) {
    return (select(scheduledWorkoutTable)
      ..where((t) => t.scheduledDate.equals(date))).watch();
  }

  Future<int> scheduleWorkout(Insertable<ScheduledWorkoutTableData> item) {
    return into(scheduledWorkoutTable).insert(item);
  }

  Future<int> removeScheduled(int id) {
    return (delete(scheduledWorkoutTable)..where((t) => t.id.equals(id))).go();
  }

  Future<void> skipWorkout(int id) {
    return (update(scheduledWorkoutTable)..where(
      (t) => t.id.equals(id),
    )).write(const ScheduledWorkoutTableCompanion(isSkipped: Value(true)));
  }

  Future<void> unskipWorkout(int id) {
    return (update(scheduledWorkoutTable)..where(
      (t) => t.id.equals(id),
    )).write(const ScheduledWorkoutTableCompanion(isSkipped: Value(false)));
  }

  Future<void> postponeWorkout(int id, DateTime newDate) {
    return (update(scheduledWorkoutTable)..where(
      (t) => t.id.equals(id),
    )).write(ScheduledWorkoutTableCompanion(scheduledDate: Value(newDate)));
  }

  /// Returns a map of date → (color, isCompleted, isSkipped) for all scheduled
  /// workouts in the given month. Used to render the calendar color dots.
  Future<Map<DateTime, ({int? color, bool isCompleted, bool isSkipped})>>
  getWorkoutColorSummariesForMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final results = await customSelect(
      '''
      SELECT
        sw.scheduled_date,
        sw.is_completed,
        sw.is_skipped,
        sw.workout_plan_id,
        COALESCE(w.color, tw.color) as color
      FROM scheduled_workout_table sw
      LEFT JOIN workout_table w ON w.id = sw.workout_id
      LEFT JOIN workout_table tw ON tw.id = sw.template_workout_id
      WHERE sw.scheduled_date >= ? AND sw.scheduled_date < ?
      ''',
      variables: [
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
    ).get();

    // Fetch active plan to filter
    final db2 = attachedDatabase;
    final activePlans = await db2.workoutPlanDao.getActivePlans();
    final activePlanId = activePlans.isNotEmpty ? activePlans.first.id : null;

    final map = <DateTime, ({int? color, bool isCompleted, bool isSkipped})>{};
    for (final row in results) {
      final planId = row.readNullable<int>('workout_plan_id');
      if (activePlanId != null && planId != activePlanId) continue;
      final rawDate = row.read<DateTime>('scheduled_date');
      final date = DateTime(rawDate.year, rawDate.month, rawDate.day);
      final color = row.readNullable<int>('color');
      final isCompleted = row.read<bool>('is_completed');
      final isSkipped = row.read<bool>('is_skipped');
      // Prefer completed entry if multiple exist for a day
      if (!map.containsKey(date) || isCompleted) {
        map[date] = (color: color, isCompleted: isCompleted, isSkipped: isSkipped);
      }
    }
    return map;
  }

  Future<List<ScheduledWorkoutTableData>> getAll() =>
      select(scheduledWorkoutTable).get();

  Future<List<ScheduledWorkoutWithDetails>> getScheduledWithDetailsForDate(
    DateTime date,
  ) async {
    // Use a half-open date range (start <= scheduled_date < end) so entries
    // are matched regardless of their time-of-day component.
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final query = select(scheduledWorkoutTable).join([
      leftOuterJoin(
        workoutTable,
        workoutTable.id.equalsExp(scheduledWorkoutTable.workoutId),
      ),
    ])..where(
      scheduledWorkoutTable.scheduledDate.isBiggerOrEqualValue(start) &
          scheduledWorkoutTable.scheduledDate.isSmallerThanValue(end),
    );

    final results = await query.get();

    return results.map((row) {
      return ScheduledWorkoutWithDetails(
        scheduled: row.readTable(scheduledWorkoutTable),
        workout: row.readTableOrNull(workoutTable),
      );
    }).toList();
  }

  Stream<List<ScheduledWorkoutWithDetails>> watchScheduledWithDetailsForDate(
    DateTime date,
  ) {
    // Create a function to fetch the current data
    Future<List<ScheduledWorkoutWithDetails>> fetchData() async {
      // Use a half-open date range (start <= scheduled_date < end) so
      // scheduled entries are matched regardless of their time-of-day.
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));

      final results =
          await customSelect(
            '''
        SELECT
          sw.id as sw_id,
          sw.workout_id,
          sw.scheduled_date,
          sw.is_completed,
          sw.is_skipped,
          sw.workout_plan_id,
          sw.created_at,
          sw.template_workout_id,

          -- primary workout (may be NULL if deleted)
          w.id as w_id,
          w.name as w_name,
          w.description as w_description,
          w.difficulty as w_difficulty,
          w.estimated_duration_minutes as w_estimated_duration_minutes,
          w.is_template as w_is_template,
          w.color as w_color,

          -- fallback template workout (use when primary is NULL)
          tw.id as tw_id,
          tw.name as tw_name,
          tw.description as tw_description,
          tw.difficulty as tw_difficulty,
          tw.estimated_duration_minutes as tw_estimated_duration_minutes,
          tw.is_template as tw_is_template,
          tw.color as tw_color,

          wp.is_active
        FROM scheduled_workout_table sw
        LEFT JOIN workout_table w ON w.id = sw.workout_id
        LEFT JOIN workout_table tw ON tw.id = sw.template_workout_id
        LEFT JOIN workout_plan_table wp ON wp.id = sw.workout_plan_id
        WHERE sw.scheduled_date >= ? AND sw.scheduled_date < ?
        ORDER BY sw.created_at DESC
        ''',
            variables: [
              Variable.withDateTime(start),
              Variable.withDateTime(end),
            ],
          ).get();

      return results.map((row) {
        final scheduled = ScheduledWorkoutTableData(
          id: row.read<int>('sw_id'),
          workoutId: row.read<int>('workout_id'),
          scheduledDate: row.read<DateTime>('scheduled_date'),
          isCompleted: row.read<bool>('is_completed'),
          isSkipped: row.read<bool>('is_skipped'),
          workoutPlanId: row.readNullable<int>('workout_plan_id'),
          createdAt: row.read<DateTime>('created_at'),
          templateWorkoutId: row.readNullable<int>('template_workout_id'),
        );

        // Prefer the actual workout row (w_*). If missing, fall back to the
        // template workout (tw_*). This prevents the UI showing "Unknown Workout"
        // when a scheduled entry references a (deleted) workout but still has a
        // template available.
        WorkoutTableData? workout;
        if (row.readNullable<int>('w_id') != null) {
          workout = WorkoutTableData(
            id: row.read<int>('w_id'),
            name: row.read<String>('w_name'),
            description: row.readNullable<String>('w_description'),
            isTemplate: row.read<bool>('w_is_template'),
            difficulty: row.read<int>('w_difficulty'),
            estimatedDurationMinutes: row.read<int>(
              'w_estimated_duration_minutes',
            ),
            scheduledDate: null,
            completedDate: null,
            color: row.readNullable<int>('w_color'),
          );
        } else if (row.readNullable<int>('tw_id') != null) {
          workout = WorkoutTableData(
            id: row.read<int>('tw_id'),
            name: row.read<String>('tw_name'),
            description: row.readNullable<String>('tw_description'),
            isTemplate: row.read<bool>('tw_is_template'),
            difficulty: row.read<int>('tw_difficulty'),
            estimatedDurationMinutes: row.read<int>(
              'tw_estimated_duration_minutes',
            ),
            scheduledDate: null,
            completedDate: null,
            color: row.readNullable<int>('tw_color'),
          );
        } else {
          workout = null;
        }

        return ScheduledWorkoutWithDetails(
          scheduled: scheduled,
          workout: workout,
        );
      }).toList();
    }

    // Watch both tables and merge their streams
    final scheduledStream = select(scheduledWorkoutTable).watch();
    final planStream = select(workoutPlanTable).watch();
    // Also watch the workout table so edits to workouts trigger a refresh
    final workoutStream = select(workoutTable).watch();

    // Use async* generator to create a stream that responds to either table
    return Stream.multi((controller) {
      StreamSubscription? scheduledSub;
      StreamSubscription? planSub;
      StreamSubscription? workoutSub;
      Timer? debounceTimer;

      void emitData() async {
        // Cancel any pending emission
        debounceTimer?.cancel();

        // Debounce to avoid rapid multiple emissions
        debounceTimer = Timer(Duration(milliseconds: 100), () async {
          try {
            final data = await fetchData();
            controller.add(data);
          } catch (e) {
            controller.addError(e);
          }
        });
      }

      scheduledSub = scheduledStream.listen((_) {
        emitData();
      });
      planSub = planStream.listen((_) {
        emitData();
      });
      workoutSub = workoutStream.listen((_) {
        emitData();
      });

      controller.onCancel = () {
        debounceTimer?.cancel();
        scheduledSub?.cancel();
        planSub?.cancel();
        workoutSub?.cancel();
      };

      // Emit initial data
      emitData();
    });
  }
}

class ScheduledWorkoutWithDetails {
  final ScheduledWorkoutTableData scheduled;
  final WorkoutTableData? workout;

  ScheduledWorkoutWithDetails({required this.scheduled, this.workout});
}

class FoodItem extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get calories => integer()();
  IntColumn get protein => integer()();
  IntColumn get carbs => integer()();
  IntColumn get fat => integer()();
  IntColumn get gramm => integer().withDefault(const Constant(100))();
  BoolColumn get hiddenFromRecent =>
      boolean().withDefault(const Constant(false))();
  /// JSON-encoded [ExtendedNutrients]. Null for custom foods and any entry
  /// added before this column was introduced.
  TextColumn get extendedNutrientsJson => text().nullable()();
}

class UserSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get dailyCalorieGoal =>
      integer().withDefault(const Constant(2000))();
  TextColumn get themeMode => text().withDefault(const Constant('light'))();
  // Profile fields
  TextColumn get name => text().withDefault(const Constant(''))();
  IntColumn get age => integer().withDefault(const Constant(30))();
  IntColumn get heightCm => integer().withDefault(const Constant(170))();
  TextColumn get sex => text().withDefault(const Constant('male'))();
  IntColumn get activityLevel => integer().withDefault(const Constant(1))();
  IntColumn get goalType => integer().withDefault(const Constant(1))();
  // Weight tracking fields
  RealColumn get startingWeight => real().withDefault(const Constant(80.0))();
  RealColumn get goalWeight => real().withDefault(const Constant(70.0))();
}

class MealTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get category => text()();
  IntColumn get foodItemId => integer()();
}

class MealFoodTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get mealId => integer().references(MealTable, #id)();
  IntColumn get foodEntryId => integer().references(FoodItem, #id)();
}

// Persistent search cache table
class SearchCacheTable extends Table {
  TextColumn get query => text()();
  TextColumn get json => text()(); // raw json array of products
  IntColumn get ts => integer()(); // epoch millis
  @override
  Set<Column> get primaryKey => {query};
}

class UserTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get username => text().unique()();
  TextColumn get email => text().unique()();
  TextColumn get passwordHash => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get profileImageUrl => text().nullable()();
  // Add other user fields as needed
}

@DriftAccessor(tables: [FoodItem])
class FoodItemDao extends DatabaseAccessor<AppDatabase>
    with _$FoodItemDaoMixin {
  FoodItemDao(AppDatabase db) : super(db);

  /// Stream the most recent food items, ordered by id descending, limited by [limit].
  Stream<List<FoodItemData>> watchRecentFoodItems(int limit) {
    return (select(foodItem)
          ..orderBy([
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .watch();
  }

  Future<List<FoodItemData>> getAllFoodItems() => select(foodItem).get();

  Stream<List<FoodItemData>> watchAllFoodItems() => select(foodItem).watch();

  /// Stream only items not hidden from the recently-added list.
  Stream<List<FoodItemData>> watchVisibleFoodItems() =>
      (select(foodItem)
        ..where((t) => t.hiddenFromRecent.equals(false))).watch();

  /// Mark all food items with [name] as hidden from the recently-added list.
  Future<void> hideFromRecent(String name) async {
    await (update(foodItem)..where(
      (t) => t.name.lower().equals(name.toLowerCase().trim()),
    )).write(const FoodItemCompanion(hiddenFromRecent: Value(true)));
  }

  Future<int> insertFoodItem(Insertable<FoodItemData> item) =>
      into(foodItem).insert(item);

  Future<int> deleteFoodItem(Insertable<FoodItemData> item) =>
      delete(foodItem).delete(item);

  Future<FoodItemData?> getFoodItemById(int id) async {
    return (select(foodItem)
      ..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<void> updateFoodItem(
    int id, {
    required int calories,
    required int protein,
    required int carbs,
    required int fat,
    required int gramm,
  }) async {
    await (update(foodItem)..where((t) => t.id.equals(id))).write(
      FoodItemCompanion(
        calories: Value(calories),
        protein: Value(protein),
        carbs: Value(carbs),
        fat: Value(fat),
        gramm: Value(gramm),
      ),
    );
  }
}

@DriftAccessor(tables: [UserSettings])
class UserSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$UserSettingsDaoMixin {
  UserSettingsDao(AppDatabase db) : super(db);

  Future<UserSetting?> getSettings() async {
    final rows = await (select(userSettings)..limit(1)).get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> setCalorieGoal(int goal) async {
    final settings = await getSettings();
    if (settings == null) {
      return into(
        userSettings,
      ).insert(UserSettingsCompanion.insert(dailyCalorieGoal: Value(goal)));
    } else {
      final success = await update(
        userSettings,
      ).replace(settings.copyWith(dailyCalorieGoal: goal));
      return success ? 1 : 0;
    }
  }

  // Update profile fields (name, age, heightCm, sex, activityLevel, goalType)
  Future<int> updateProfile({
    String? name,
    int? age,
    int? heightCm,
    String? sex,
    int? activityLevel,
    int? goalType,
    double? startingWeight,
    double? goalWeight,
  }) async {
    final settings = await getSettings();
    if (settings == null) {
      return into(userSettings).insert(
        UserSettingsCompanion.insert(
          dailyCalorieGoal: const Value(2000),
          name: Value(name ?? ''),
          age: Value(age ?? 30),
          heightCm: Value(heightCm ?? 170),
          sex: Value(sex ?? 'male'),
          activityLevel: Value(activityLevel ?? 1),
          goalType: Value(goalType ?? 1),
          startingWeight: Value(startingWeight ?? 80.0),
          goalWeight: Value(goalWeight ?? 70.0),
        ),
      );
    } else {
      final updated = settings.copyWith(
        name: name ?? settings.name,
        age: age ?? settings.age,
        heightCm: heightCm ?? settings.heightCm,
        sex: sex ?? settings.sex,
        activityLevel: activityLevel ?? settings.activityLevel,
        goalType: goalType ?? settings.goalType,
        startingWeight: startingWeight ?? settings.startingWeight,
        goalWeight: goalWeight ?? settings.goalWeight,
      );
      final success = await update(userSettings).replace(updated);
      return success ? 1 : 0;
    }
  }

  // Update weight goals specifically
  Future<int> updateWeightGoals({
    required double startingWeight,
    required double goalWeight,
  }) async {
    final settings = await getSettings();
    if (settings == null) {
      return into(userSettings).insert(
        UserSettingsCompanion.insert(
          dailyCalorieGoal: const Value(2000),
          startingWeight: Value(startingWeight),
          goalWeight: Value(goalWeight),
        ),
      );
    } else {
      await (update(userSettings)
        ..where((t) => t.id.equals(settings.id))).write(
        UserSettingsCompanion(
          startingWeight: Value(startingWeight),
          goalWeight: Value(goalWeight),
        ),
      );
      return 1;
    }
  }

  Future<void> updateThemeMode(String mode) async {
    final settings = await getSettings();
    if (settings == null) {
      await into(
        userSettings,
      ).insert(UserSettingsCompanion.insert(themeMode: Value(mode)));
    } else {
      await (update(userSettings)..where(
        (tbl) => tbl.id.equals(settings.id),
      )).write(settings.copyWith(themeMode: mode));
    }
  }
}

@DriftAccessor(tables: [MealTable, MealFoodTable, FoodItem])
class MealDao extends DatabaseAccessor<AppDatabase> with _$MealDaoMixin {
  MealDao(AppDatabase db) : super(db);

  Future<List<MealTableData>> getMealsForDate(DateTime date) {
    return (select(mealTable)..where((tbl) => tbl.date.equals(date))).get();
  }

  Future<MealTableData?> getMealById(int id) {
    return (select(mealTable)
      ..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertMeal(Insertable<MealTableData> meal) {
    return into(mealTable).insert(meal);
  }

  Future<int> deleteMeal(Insertable<MealTableData> meal) {
    return delete(mealTable).delete(meal);
  }

  Future<int> addFoodToMeal(int foodId, int mealId) {
    return into(mealFoodTable).insert(
      MealFoodTableCompanion.insert(mealId: mealId, foodEntryId: foodId),
    );
  }

  Future<List<MealFoodTableData>> getFoodItemsForMeal(int mealId) {
    return (select(mealFoodTable)
      ..where((tbl) => tbl.mealId.equals(mealId))).get();
  }

  Future<int> deleteFoodFromMeal(int foodId, int mealId) {
    return (delete(mealFoodTable)..where(
      (tbl) => tbl.mealId.equals(mealId) & tbl.foodEntryId.equals(foodId),
    )).go();
  }
}

@DriftAccessor(tables: [SearchCacheTable])
class SearchCacheDao extends DatabaseAccessor<AppDatabase>
    with _$SearchCacheDaoMixin {
  SearchCacheDao(AppDatabase db) : super(db);

  Future<void> upsert(String q, String jsonData, int ts) async {
    await into(searchCacheTable).insertOnConflictUpdate(
      SearchCacheTableCompanion(
        query: Value(q),
        json: Value(jsonData),
        ts: Value(ts),
      ),
    );
  }

  Future<List<SearchCacheTableData>> getAll() => select(searchCacheTable).get();

  Future<void> deleteByQuery(String q) async {
    await (delete(searchCacheTable)..where((tbl) => tbl.query.equals(q))).go();
  }

  Future<void> deleteOlderThan(int cutoffTs) async {
    await (delete(searchCacheTable)
      ..where((tbl) => tbl.ts.isSmallerThanValue(cutoffTs))).go();
  }
}

// Weight tracking table definition
/// Sync state for a locally-stored weight record.
///
/// - [pending]       New record, never pushed to the API.
/// - [synced]        Successfully pushed; [serverId] is set.
/// - [pendingUpdate] Edited locally after a successful sync.
/// - [pendingDelete] Deleted locally; must be removed on the API before the
///                   local row is dropped.
enum WeightSyncStatus { pending, synced, pendingUpdate, pendingDelete }

class WeightRecord extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  RealColumn get weight => real()();
  TextColumn get note => text().nullable()();
  /// Maps to [WeightSyncStatus] by index. Defaults to [WeightSyncStatus.pending].
  IntColumn get syncStatus =>
      integer().withDefault(const Constant(0))();
  /// The UUID assigned by the remote API after the first successful sync.
  /// Null until the record has been synced at least once.
  TextColumn get serverId => text().nullable()();
}

// Workout planning tables

/// Table for storing exercise definitions
class ExerciseTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get nameDe => text().nullable()();
  TextColumn get descriptionDe => text().nullable()();
  IntColumn get type => integer()(); // Maps to ExerciseType enum index
  TextColumn get targetMuscleGroups => text()();
  TextColumn get imageUrl => text().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
}

/// Table for storing complete workouts
class WorkoutTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  IntColumn get difficulty =>
      integer()(); // Maps to WorkoutDifficulty enum index
  IntColumn get estimatedDurationMinutes =>
      integer().withDefault(const Constant(30))();
  BoolColumn get isTemplate => boolean().withDefault(const Constant(true))();
  DateTimeColumn get scheduledDate => dateTime().nullable()();
  DateTimeColumn get completedDate => dateTime().nullable()();
  IntColumn get color => integer().nullable()();
}

/// Table for linking exercises to workouts (workout_exercise)
class WorkoutExerciseTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId =>
      integer().references(
        WorkoutTable,
        #id,
        onDelete: KeyAction.cascade, // ← ADD THIS
      )();
  IntColumn get exerciseId =>
      integer().references(
        ExerciseTable,
        #id,
        onDelete: KeyAction.cascade, // ← ADD THIS
      )();
  IntColumn get orderPosition => integer()();
  TextColumn get notes => text().nullable()();
  IntColumn get supersetGroupId => integer().nullable()();
}

class ScheduledWorkoutExerciseTable extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The scheduled workout (this is the date!)
  IntColumn get scheduledWorkoutId =>
      integer().references(
        ScheduledWorkoutTable,
        #id,
        onDelete: KeyAction.cascade,
      )();
  IntColumn get workoutExerciseId =>
      integer().references(
        WorkoutExerciseTable,
        #id,
        onDelete: KeyAction.cascade,
      )();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();

  TextColumn get notes => text().nullable()();

  /// Exercise override for this specific day only. Null = use the template exercise.
  IntColumn get overrideExerciseId => integer().nullable()();
}

/// Table for storing individual sets within a workout exercise
class WorkoutSetTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get scheduledWorkoutExerciseId =>
      integer().references(
        ScheduledWorkoutExerciseTable,
        #id,
        onDelete: KeyAction.cascade, // ← ADD THIS
      )();
  IntColumn get setNumber => integer()();
  IntColumn get reps => integer().nullable()();
  RealColumn get weight => real().nullable()();
  TextColumn get weightUnit => text().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
}

/// Table for workout plans/schedules
class WorkoutPlanTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  TextColumn get cyclePatternJson => text()();
  BoolColumn get isFreeChoice => boolean().withDefault(const Constant(false))();
}

/// Table for linking workouts to plans (many-to-many)
class WorkoutPlanWorkoutTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId => integer().references(WorkoutPlanTable, #id)();
  IntColumn get workoutId => integer().references(WorkoutTable, #id)();
}

/// Table for storing scheduled workouts (instances of a workout scheduled on a date)
class ScheduledWorkoutTable extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Links to the workout template or workout entry
  IntColumn get workoutId => integer().references(WorkoutTable, #id)();
  IntColumn get workoutPlanId =>
      integer().nullable().references(WorkoutPlanTable, #id)();
  IntColumn get templateWorkoutId =>
      integer().nullable().references(
        WorkoutTable,
        #id,
        onDelete: KeyAction.cascade, // ← ADD THIS
      )();

  /// The date/time this workout is scheduled for
  DateTimeColumn get scheduledDate => dateTime()();

  /// When the scheduled entry was created. Use a clientDefault so
  /// sqlite3 native doesn't receive a non-constant SQL default.
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  TextColumn get notes => text().nullable()();

  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isSkipped => boolean().withDefault(const Constant(false))();
}

@DataClassName('WorkoutSetTemplateData')
class WorkoutSetTemplateTable extends Table {
  IntColumn get id => integer().autoIncrement()();

  // Links to the workout-exercise relationship
  IntColumn get workoutExerciseId =>
      integer().references(
        WorkoutExerciseTable,
        #id,
        onDelete: KeyAction.cascade, // ← ADD THIS
      )();

  // Which set number (1, 2, 3, etc.)
  IntColumn get setNumber => integer()();

  // Target reps as string (e.g., "8-12", "10", "15-20")
  TextColumn get targetReps => text()();

  // Order position for sorting
  IntColumn get orderPosition => integer()();
}

// Weight tracking DAO
@DriftAccessor(tables: [WeightRecord])
class WeightRecordDao extends DatabaseAccessor<AppDatabase>
    with _$WeightRecordDaoMixin {
  WeightRecordDao(AppDatabase db) : super(db);

  // Get all weight records ordered by date
  Future<List<WeightRecordData>> getAllWeightRecords() =>
      (select(weightRecord)..orderBy([
        (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
      ])).get();

  // Watch all weight records (reactive stream)
  Stream<List<WeightRecordData>> watchAllWeightRecords() =>
      (select(weightRecord)..orderBy([
        (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
      ])).watch();

  // Get the most recent weight record
  Future<WeightRecordData?> getLatestWeightRecord() =>
      (select(weightRecord)
            ..orderBy([
              (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<WeightRecordData?> getWeightRecordById(int id) =>
      (select(weightRecord)..where((t) => t.id.equals(id))).getSingleOrNull();

  // Add a new weight record
  Future<int> addWeightRecord(Insertable<WeightRecordData> record) =>
      into(weightRecord).insert(record);

  // Update an existing weight record
  Future<bool> updateWeightRecord(Insertable<WeightRecordData> record) =>
      update(weightRecord).replace(record);

  // Delete a weight record
  Future<int> deleteWeightRecord(int id) =>
      (delete(weightRecord)..where((tbl) => tbl.id.equals(id))).go();

  // Get weight records within a date range, ordered by date ascending
  Future<List<WeightRecordData>> getRecordsInRange(
    DateTime start,
    DateTime end,
  ) =>
      (select(weightRecord)
            ..where((t) => t.date.isBiggerOrEqualValue(start))
            ..where((t) => t.date.isSmallerOrEqualValue(end))
            ..orderBy([(t) => OrderingTerm.asc(t.date)]))
          .get();

  // --- Sync helpers ---

  /// Returns every record that needs to be pushed to the API
  /// (pending, pendingUpdate, or pendingDelete).
  Future<List<WeightRecordData>> getUnsyncedRecords() =>
      (select(weightRecord)
            ..where(
              (t) => t.syncStatus.isNotIn([
                WeightSyncStatus.synced.index,
              ]),
            ))
          .get();

  /// Marks a record as [WeightSyncStatus.synced] and stores the [serverId]
  /// returned by the API.
  Future<void> markSynced({required int localId, required String serverId}) =>
      (update(weightRecord)..where((t) => t.id.equals(localId))).write(
        WeightRecordCompanion(
          syncStatus: Value(WeightSyncStatus.synced.index),
          serverId: Value(serverId),
        ),
      );

  /// Marks an already-synced record as [WeightSyncStatus.pendingUpdate] so
  /// the next sync pass will push the change via PUT.
  Future<void> markPendingUpdate(int localId) =>
      (update(weightRecord)..where((t) => t.id.equals(localId))).write(
        WeightRecordCompanion(
          syncStatus: Value(WeightSyncStatus.pendingUpdate.index),
        ),
      );

  /// Marks a record as [WeightSyncStatus.pendingDelete].
  /// Call this instead of [deleteWeightRecord] when the record has a [serverId]
  /// so the sync pass can delete it on the API first.
  Future<void> markPendingDelete(int localId) =>
      (update(weightRecord)..where((t) => t.id.equals(localId))).write(
        WeightRecordCompanion(
          syncStatus: Value(WeightSyncStatus.pendingDelete.index),
        ),
      );
}

// Workout planning DAOs

@DriftAccessor(tables: [ExerciseTable])
class ExerciseDao extends DatabaseAccessor<AppDatabase>
    with _$ExerciseDaoMixin {
  ExerciseDao(AppDatabase db) : super(db);

  // Get all exercises
  Future<List<ExerciseTableData>> getAllExercises() =>
      select(exerciseTable).get();

  // Get a specific exercise by ID
  Future<ExerciseTableData?> getExerciseById(int id) =>
      (select(exerciseTable)..where((e) => e.id.equals(id))).getSingleOrNull();

  // Get exercises by type
  Future<List<ExerciseTableData>> getExercisesByType(ExerciseType type) =>
      (select(exerciseTable)..where((e) => e.type.equals(type.index))).get();

  // Get exercises by muscle group
  Future<List<ExerciseTableData>> getExercisesByMuscleGroup(
    MuscleGroup muscleGroup,
  ) async {
    final allExercises = await getAllExercises();
    return allExercises.where((exercise) {
      final muscleGroups =
          exercise.targetMuscleGroups
              .split(',')
              .map((e) => int.tryParse(e.trim()))
              .where((e) => e != null)
              .cast<int>()
              .toList();
      return muscleGroups.contains(muscleGroup.index);
    }).toList();
  }

  // Search exercises by name
  Future<List<ExerciseTableData>> searchExercises(String query) async {
    final lowerQuery = query.toLowerCase();
    final allExercises = await getAllExercises();
    return allExercises
        .where((e) => e.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  // Get exercises by muscle group with search
  Future<List<ExerciseTableData>> searchExercisesByMuscleGroup(
    MuscleGroup muscleGroup,
    String query,
  ) async {
    final exercises = await getExercisesByMuscleGroup(muscleGroup);
    if (query.isEmpty) return exercises;

    final lowerQuery = query.toLowerCase();
    return exercises
        .where((e) => e.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  // Insert or update an exercise
  Future<int> saveExercise(ExerciseTableCompanion exercise) =>
      into(exerciseTable).insert(exercise, mode: InsertMode.insertOrReplace);

  // Delete an exercise
  Future<int> deleteExercise(int id) =>
      (delete(exerciseTable)..where((e) => e.id.equals(id))).go();

  // Convert database entity to model
  Exercise entityToModel(ExerciseTableData data) {
    List<MuscleGroup> muscleGroups =
        data.targetMuscleGroups
            .split(',')
            .map((e) => int.parse(e.trim()))
            .map((index) => MuscleGroup.values[index])
            .toList();

    return Exercise(
      id: data.id,
      name: data.name,
      description: data.description,
      nameDe: data.nameDe,
      descriptionDe: data.descriptionDe,
      type: ExerciseType.values[data.type],
      targetMuscleGroups: muscleGroups,
      imageUrl: data.imageUrl,
      isCustom: data.isCustom,
    );
  }

  // Convert model to database entity companion
  ExerciseTableCompanion modelToEntity(Exercise model) {
    String muscleGroupString = model.targetMuscleGroups
        .map((mg) => mg.index.toString())
        .join(',');

    return ExerciseTableCompanion(
      id: model.id == null ? const Value.absent() : Value(model.id!),
      name: Value(model.name),
      description: Value(model.description),
      nameDe: Value(model.nameDe),
      descriptionDe: Value(model.descriptionDe),
      type: Value(model.type.index),
      targetMuscleGroups: Value(muscleGroupString),
      imageUrl: Value(model.imageUrl),
      isCustom: Value(model.isCustom),
    );
  }
}

/// Returns the exercise name/description in the given locale language,
/// falling back to English when no translation is available.
extension ExerciseTableDataLocalization on ExerciseTableData {
  String localizedName(String languageCode) =>
      languageCode == 'de' && nameDe != null ? nameDe! : name;

  String? localizedDescription(String languageCode) =>
      languageCode == 'de' && descriptionDe != null ? descriptionDe : description;
}

class FitNotesImportResult {
  final int sessions;
  final int setsImported;
  final List<String> newExercises;
  final int workoutsCreated;

  FitNotesImportResult({
    required this.sessions,
    required this.setsImported,
    required this.newExercises,
    required this.workoutsCreated,
  });
}

@DriftAccessor(
  tables: [
    WorkoutTable,
    WorkoutExerciseTable,
    WorkoutSetTable,
    WorkoutSetTemplateTable,
    ScheduledWorkoutTable,
    WorkoutPlanTable,
    WorkoutPlanWorkoutTable,
  ],
)
class WorkoutDao extends DatabaseAccessor<AppDatabase> with _$WorkoutDaoMixin {
  WorkoutDao(AppDatabase db) : super(db);

  // ✅ New method to get workout by ID
  Future<Workout?> getWorkoutById(int id) async {
    final query =
        await (select(workoutTable)
          ..where((t) => t.id.equals(id))).getSingleOrNull();

    if (query == null) return null;

    // If you need exercises as well, you can fetch them here or return the bare workout
    final exercises = await getExercisesForWorkout(id);

    return Workout(
      id: query.id,
      name: query.name,
      isTemplate: query.isTemplate,
      difficulty: WorkoutDifficulty.values[query.difficulty],
      estimatedDurationMinutes: query.estimatedDurationMinutes,
      exercises: exercises,
    );
  }

  // Optional helper to fetch exercises for a workout
  Future<List<WorkoutExercise>> getExercisesForWorkout(int workoutId) async {
    final rows =
        await (select(workoutExerciseTable)
          ..where((t) => t.workoutId.equals(workoutId))).get();

    List<WorkoutExercise> exercises = [];

    for (var row in rows) {
      final exerciseRow =
          await (select(exerciseTable)
            ..where((e) => e.id.equals(row.exerciseId))).getSingleOrNull();

      if (exerciseRow != null) {
        exercises.add(
          WorkoutExercise(
            id: row.id,
            workoutId: workoutId,
            exerciseId: row.exerciseId,
            orderPosition: row.orderPosition,
            notes: row.notes,
          ),
        );
      }
    }

    return exercises;
  }

  Future<List<WorkoutSetTemplateData>> getSetTemplatesForWorkoutExercise(
    int workoutExerciseId,
  ) {
    return (select(workoutSetTemplateTable)
          ..where((t) => t.workoutExerciseId.equals(workoutExerciseId))
          ..orderBy([(t) => OrderingTerm.asc(t.setNumber)]))
        .get();
  }

  // Get all workouts (templates and scheduled)
  Future<List<WorkoutTableData>> getAllWorkouts() => select(workoutTable).get();

  // Get workout templates only
  Future<List<WorkoutTableData>> getWorkoutTemplates() =>
      (select(workoutTable)..where((w) => w.isTemplate.equals(true))).get();

  // Get scheduled workouts
  Future<List<WorkoutTableData>> getScheduledWorkouts() =>
      (select(workoutTable)..where((w) => w.isTemplate.equals(false))).get();

  Future<String> getScheduledWorkoutName(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(Duration(days: 1));
    final scheduledList =
        await (select(scheduledWorkoutTable)..where(
          (sw) => sw.scheduledDate.isBetweenValues(
            start,
            end.subtract(Duration(milliseconds: 1)),
          ),
        )).get();

    if (scheduledList.isEmpty) {
      return "";
    }

    // Pick the latest or the first, depending on your logic
    final scheduled = scheduledList.first;

    final workout =
        await (select(workoutTable)
          ..where((w) => w.id.equals(scheduled.workoutId))).getSingleOrNull();

    return workout?.name ?? 'Workout';
  }

  // Get scheduled workouts for a date range
  Future<List<WorkoutTableData>> getWorkoutsInDateRange(
    DateTime startDate,
    DateTime endDate,
  ) =>
      (select(workoutTable)
            ..where((w) => w.scheduledDate.isBetweenValues(startDate, endDate))
            ..where((w) => w.isTemplate.equals(false)))
          .get();

  // Get a specific workout with all related data
  Future<Workout?> getCompleteWorkoutById(int id) async {
    // 1️⃣ Load workout row
    final workoutData =
        await (select(workoutTable)
          ..where((w) => w.id.equals(id))).getSingleOrNull();

    if (workoutData == null) return null;

    // 2️⃣ Load exercise instances for this workout
    final exerciseInstances =
        await (select(workoutExerciseTable)
              ..where((we) => we.workoutId.equals(id))
              ..orderBy([(we) => OrderingTerm(expression: we.orderPosition)]))
            .get();

    final workoutExercises = <WorkoutExercise>[];

    // 3️⃣ For each exercise instance
    for (final exerciseInstance in exerciseInstances) {
      final exerciseRow =
          await (select(exerciseTable)..where(
            (e) => e.id.equals(exerciseInstance.exerciseId),
          )).getSingleOrNull();

      if (exerciseRow == null) continue;

      final exerciseModel = db.exerciseDao.entityToModel(exerciseRow);

      // 🔹 Load sets for this exercise instance
      final setRows =
          await (select(workoutSetTemplateTable)
                ..where((s) => s.workoutExerciseId.equals(exerciseInstance.id))
                ..orderBy([(s) => OrderingTerm(expression: s.setNumber)]))
              .get();

      final workoutSets =
          setRows.map((set) {
            return WorkoutSet(
              id: set.id,
              exerciseInstanceId: set.workoutExerciseId,
              setNumber: set.setNumber,
              targetReps: set.targetReps,
            );
          }).toList();

      // 🔹 Build workout exercise object
      workoutExercises.add(
        WorkoutExercise(
          id: exerciseInstance.id,
          workoutId: exerciseInstance.workoutId,
          exerciseId: exerciseInstance.exerciseId,
          orderPosition: exerciseInstance.orderPosition,
          exercise: exerciseModel,
          sets: workoutSets,
          notes: exerciseInstance.notes,
        ),
      );
    }

    // 4️⃣ Return fully built workout
    return Workout(
      id: workoutData.id,
      name: workoutData.name,
      description: workoutData.description,
      estimatedDurationMinutes: workoutData.estimatedDurationMinutes,
      isTemplate: workoutData.isTemplate,
      scheduledDate: workoutData.scheduledDate,
      completedDate: workoutData.completedDate,
      exercises: workoutExercises,
    );
  }

  Future<
    List<
      (
        ExerciseTableData,
        List<WorkoutSetTemplateData>,
        WorkoutExerciseTableData,
      )
    >
  >
  getWorkoutExercisesWithTemplates(int workoutId) async {
    final workoutExercises =
        await (select(workoutExerciseTable)
              ..where((we) => we.workoutId.equals(workoutId))
              ..orderBy([(we) => OrderingTerm.asc(we.orderPosition)]))
            .get();
    final results =
        <
          (
            ExerciseTableData,
            List<WorkoutSetTemplateData>,
            WorkoutExerciseTableData,
          )
        >[];

    for (final workoutExercise in workoutExercises) {
      final exercise =
          await (select(exerciseTable)..where(
            (e) => e.id.equals(workoutExercise.exerciseId),
          )).getSingleOrNull();

      final templates =
          await (select(workoutSetTemplateTable)..where(
            (t) => t.workoutExerciseId.equals(workoutExercise.id),
          )).get();

      if (exercise != null) {
        results.add((exercise, templates, workoutExercise));
      }
    }

    return results;
  }

  // Save a complete workout with exercises and sets
  Future<int> saveCompleteWorkout(Workout workout) async {
    return transaction(() async {
      int workoutId;

      final workoutCompanion = WorkoutTableCompanion(
        id: workout.id == null ? const Value.absent() : Value(workout.id!),
        name: Value(workout.name),
        description: Value(workout.description),
        difficulty: Value(workout.difficulty!.index),
        estimatedDurationMinutes: Value(workout.estimatedDurationMinutes ?? 30),
        isTemplate: Value(workout.isTemplate),
        scheduledDate: Value(workout.scheduledDate),
        completedDate: Value(workout.completedDate),
      );

      // 🔹 1️⃣ Insert or Update workout SAFELY
      if (workout.id == null) {
        // New workout → insert
        workoutId = await into(workoutTable).insert(workoutCompanion);
      } else {
        // Existing workout → update (NOT replace)
        await (update(workoutTable)
          ..where((w) => w.id.equals(workout.id!))).write(workoutCompanion);

        workoutId = workout.id!;
      }

      // 🔹 2️⃣ If updating, remove old exercises & sets
      if (workout.id != null) {
        final existingExercises =
            await (select(workoutExerciseTable)
              ..where((we) => we.workoutId.equals(workoutId))).get();

        for (final exercise in existingExercises) {
          await (delete(workoutSetTable)..where(
            (s) => s.scheduledWorkoutExerciseId.equals(exercise.id),
          )).go();
        }

        await (delete(workoutExerciseTable)
          ..where((we) => we.workoutId.equals(workoutId))).go();
      }

      // 🔹 3️⃣ Save exercises + sets
      for (final exercise in workout.exercises) {
        final exerciseCompanion = WorkoutExerciseTableCompanion(
          workoutId: Value(workoutId),
          exerciseId: Value(exercise.exerciseId),
          orderPosition: Value(exercise.orderPosition),
          notes: Value(exercise.notes),
        );

        final exerciseInstanceId = await into(
          workoutExerciseTable,
        ).insert(exerciseCompanion);

        // ✅ ONLY insert into workoutSetTable if NOT template
        if (!workout.isTemplate) {
          for (final set in exercise.sets) {
            final setCompanion = WorkoutSetTableCompanion(
              scheduledWorkoutExerciseId: Value(exerciseInstanceId),
              setNumber: Value(set.setNumber),
              reps: Value(set.reps),
              weight: Value(set.weight),
              weightUnit: Value(set.weightUnit),
              durationSeconds: Value(set.durationSeconds),
              isCompleted: Value(set.isCompleted),
              notes: Value(set.notes),
            );

            await into(workoutSetTable).insert(setCompanion);
          }
        }

        // ✅ ALWAYS rebuild template sets
        await (delete(workoutSetTemplateTable)
          ..where((t) => t.workoutExerciseId.equals(exerciseInstanceId))).go();

        for (final set in exercise.sets) {
          final templateCompanion = WorkoutSetTemplateTableCompanion(
            workoutExerciseId: Value(exerciseInstanceId),
            setNumber: Value(set.setNumber),
            targetReps: Value(set.targetReps ?? "8 - 12"),
            orderPosition: Value(set.setNumber - 1),
          );

          await into(workoutSetTemplateTable).insert(templateCompanion);
        }
      }

      return workoutId;
    });
  }

  // Delete a workout and all related data
  Future<bool> deleteWorkout(int id) {
    return transaction(() async {
      // Get all exercise instances for this workout
      final exerciseInstances =
          await (select(workoutExerciseTable)
            ..where((we) => we.workoutId.equals(id))).get();

      // Delete sets for each exercise instance
      for (final exercise in exerciseInstances) {
        await (delete(
          workoutSetTable,
        )..where((s) => s.scheduledWorkoutExerciseId.equals(exercise.id))).go();
      }

      // Delete exercise instances
      await (delete(workoutExerciseTable)
        ..where((we) => we.workoutId.equals(id))).go();

      // Delete workout
      final rowsDeleted =
          await (delete(workoutTable)..where((w) => w.id.equals(id))).go();

      return rowsDeleted > 0;
    });
  }

  Future<WorkoutTableData?> getWorkoutByNameOrNull(String name) {
    return (select(workoutTable)
      ..where((w) => w.name.equals(name))).getSingleOrNull();
  }

  Future<List<WorkoutSetTableData>> getPreviousWorkoutSetsForExercise({
    required int exerciseId,
    required DateTime beforeDate,
    required int templateWorkoutId,
    int? excludeScheduledWorkoutId,
  }) async {
    final scheduledQuery = select(scheduledWorkoutTable)..where(
      (sw) =>
          sw.scheduledDate.isSmallerThanValue(beforeDate) &
          sw.isCompleted.equals(true) &
          sw.templateWorkoutId.equals(templateWorkoutId),
    );
    if (excludeScheduledWorkoutId != null) {
      scheduledQuery.where((sw) => sw.id.isNotIn([excludeScheduledWorkoutId]));
    }
    final previousScheduledWorkout =
        await (scheduledQuery
              ..orderBy([(sw) => OrderingTerm.desc(sw.scheduledDate)])
              ..limit(1))
            .getSingleOrNull();

    if (previousScheduledWorkout == null) return [];

    final workoutExercises =
        await (select(workoutExerciseTable)..where(
          (we) =>
              we.workoutId.equals(previousScheduledWorkout.workoutId) &
              we.exerciseId.equals(exerciseId),
        )).get();

    if (workoutExercises.isEmpty) return [];

    final allSets = <WorkoutSetTableData>[];
    for (final workoutExercise in workoutExercises) {
      final sets =
          await (select(workoutSetTable)
                ..where(
                  (ws) =>
                      ws.scheduledWorkoutExerciseId.equals(workoutExercise.id),
                )
                ..orderBy([(ws) => OrderingTerm.asc(ws.setNumber)]))
              .get();
      allSets.addAll(sets);
    }

    return allSets;
  }

  Future<int?> importCsvWorkouts(
    String csvContent, {
    bool createPlan = false,
    String? planName,
  }) async {
    final rows = const CsvToListConverter().convert(csvContent);

    if (rows.isEmpty) return null;

    // Do the entire import in a transaction for consistency
    int? createdPlanId;
    await transaction(() async {
      // Skip header row
      final dataRows = rows.skip(1);

      // Group by date (each date becomes a separate workout)
      final workoutsByDate = <String, List<List<dynamic>>>{};

      for (final row in dataRows) {
        if (row.length < 2) continue; // minimal columns

        final date = row[0].toString();
        if (!workoutsByDate.containsKey(date)) {
          workoutsByDate[date] = [];
        }
        workoutsByDate[date]!.add(row);
      }

      if (workoutsByDate.isEmpty) return;

      int? planId;
      if (createPlan) {
        // Create a workout plan for this import
        final firstDate = workoutsByDate.keys.first;
        final usedPlanName = planName ?? 'Imported Plan ($firstDate)';
        final planCompanion = WorkoutPlanTableCompanion(
          name: Value(usedPlanName),
          description: Value('Imported from CSV'),
          startDate: Value(DateTime.now()),
          isActive: Value(true),
        );

        // Deactivate existing plans
        await (update(db.workoutPlanTable)..where(
          (p) => p.isActive.equals(true),
        )).write(WorkoutPlanTableCompanion(isActive: Value(false)));

        planId = await into(db.workoutPlanTable).insert(planCompanion);
        createdPlanId = planId;
      }

      // For each date, create a workout and its exercises/sets
      for (final entry in workoutsByDate.entries) {
        final date = entry.key;
        final workoutRows = entry.value;

        // Group exercises by name
        final exercisesByName = <String, List<List<dynamic>>>{};

        for (final row in workoutRows) {
          final exerciseName = row[1].toString();
          if (!exercisesByName.containsKey(exerciseName)) {
            exercisesByName[exerciseName] = [];
          }
          exercisesByName[exerciseName]!.add(row);
        }

        // Create workout (store as historical instance so it can be used in graphs)
        final workoutName = 'Workout on $date';
        DateTime? parsedDate;
        try {
          parsedDate = DateTime.parse(date);
        } catch (_) {
          parsedDate = null;
        }

        final workoutCompanion = WorkoutTableCompanion(
          name: Value(workoutName),
          description: Value('Imported from CSV'),
          difficulty: Value(1), // Beginner
          estimatedDurationMinutes: Value(60),
          // Mark as instance (not a template) so it represents a historical workout
          isTemplate: Value(false),
          // Set scheduled and completed dates when available
          scheduledDate: Value(parsedDate),
          completedDate: Value(parsedDate),
        );

        final workoutId = await into(workoutTable).insert(workoutCompanion);

        // Link workout to plan if requested
        if (planId != null) {
          await into(db.workoutPlanWorkoutTable).insert(
            WorkoutPlanWorkoutTableCompanion(
              planId: Value(planId),
              workoutId: Value(workoutId),
            ),
          );
        }

        int orderPosition = 0;
        for (final exerciseEntry in exercisesByName.entries) {
          final exerciseName = exerciseEntry.key;
          final exerciseRows = exerciseEntry.value;

          // Find or create exercise
          var exercise =
              await (select(exerciseTable)
                ..where((e) => e.name.equals(exerciseName))).getSingleOrNull();

          if (exercise == null) {
            // Create basic exercise
            final exerciseCompanion = ExerciseTableCompanion(
              name: Value(exerciseName),
              description: Value('Imported exercise'),
              type: Value(ExerciseType.strength.index),
              targetMuscleGroups: Value(''), // Empty string for now
              imageUrl: Value.absent(),
              isCustom: Value(true),
            );
            final exerciseId = await into(
              exerciseTable,
            ).insert(exerciseCompanion);
            exercise =
                await (select(exerciseTable)
                  ..where((e) => e.id.equals(exerciseId))).getSingle();
          }

          // Add exercise to workout
          final exerciseCompanion = WorkoutExerciseTableCompanion(
            workoutId: Value(workoutId),
            exerciseId: Value(exercise.id),
            orderPosition: Value(orderPosition++),
          );

          final exerciseInstanceId = await into(
            workoutExerciseTable,
          ).insert(exerciseCompanion);

          // Add sets
          int setNumber = 1;
          for (final row in exerciseRows) {
            final weight =
                double.tryParse(row.length > 3 ? row[3].toString() : '') ?? 0.0;
            final weightUnit = row.length > 4 ? row[4].toString() : 'kg';
            final reps =
                int.tryParse(row.length > 5 ? row[5].toString() : '') ?? 0;

            final setCompanion = WorkoutSetTableCompanion(
              scheduledWorkoutExerciseId: Value(exerciseInstanceId),
              setNumber: Value(setNumber++),
              reps: Value(reps),
              weight: Value(weight),
              weightUnit: Value(weightUnit),
              // Mark sets as completed when importing historical data so graphing can use them
              isCompleted: Value(true),
            );

            await into(workoutSetTable).insert(setCompanion);
          }
        }
      }

      // If we created a plan, ensure it is active (others were deactivated above)
      if (planId != null) {
        final pid = planId;
        await (update(db.workoutPlanTable)..where(
          (p) => p.id.equals(pid),
        )).write(WorkoutPlanTableCompanion(isActive: Value(true)));
      }
    });

    return createdPlanId;
  }

  /// Maps a sorted comma-joined category signature to a friendly workout name.
  static String _categorySignatureToName(String signature) {
    const known = {
      'Chest': 'Chest',
      'Back': 'Back',
      'Shoulders': 'Shoulders',
      'Biceps': 'Biceps',
      'Triceps': 'Triceps',
      'Legs': 'Legs',
      'Abs': 'Core',
      'Core': 'Core',
      'Abs,Core': 'Core',
      'Back,Biceps': 'Back & Biceps',
      'Chest,Triceps': 'Chest & Triceps',
      'Chest,Shoulders,Triceps': 'Push',
      'Back,Biceps,Forearms': 'Pull',
      'Abs,Legs': 'Legs & Core',
    };
    return known[signature] ?? signature.split(',').join(' & ');
  }

  /// Maps a FitNotes category string to a [MuscleGroup] index.
  static int _fitNotesCategory(String category) {
    switch (category.toLowerCase().trim()) {
      case 'chest':
        return MuscleGroup.chest.index;
      case 'back':
        return MuscleGroup.back.index;
      case 'shoulders':
        return MuscleGroup.shoulders.index;
      case 'biceps':
        return MuscleGroup.biceps.index;
      case 'triceps':
        return MuscleGroup.triceps.index;
      case 'legs':
      case 'quads':
      case 'hamstrings':
      case 'calves':
      case 'glutes':
        return MuscleGroup.legs.index;
      case 'abs':
      case 'core':
        return MuscleGroup.abs.index;
      default:
        return MuscleGroup.fullBody.index;
    }
  }

  /// Import a FitNotes-format CSV as completed historical workout sessions.
  ///
  /// Creates one template [WorkoutTable] entry that all dates share, then
  /// creates proper [ScheduledWorkoutTable] / [ScheduledWorkoutExerciseTable]
  /// entries so the data appears correctly in the progress dashboard.
  Future<FitNotesImportResult> importFitNotesCsv(String csvContent) {
    return transaction(() async {
      // ── Phase 0: Parse & normalize CSV ───────────────────────────────────
      csvContent = csvContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      final rows = const CsvToListConverter().convert(csvContent, eol: '\n');
      if (rows.length < 2) {
        return FitNotesImportResult(
          sessions: 0,
          setsImported: 0,
          newExercises: [],
          workoutsCreated: 0,
        );
      }

      final dataRows =
          rows
              .skip(1)
              .where((r) => r.length >= 6 && r[0].toString().trim().isNotEmpty)
              .toList();

      if (dataRows.isEmpty) {
        return FitNotesImportResult(
          sessions: 0,
          setsImported: 0,
          newExercises: [],
          workoutsCreated: 0,
        );
      }

      // ── Phase 1: Find-or-create ExerciseTable entries ────────────────────
      // exerciseName → category (last seen wins)
      final exerciseCategoryMap = <String, String>{};
      for (final row in dataRows) {
        final name = row[1].toString().trim();
        final category = row[2].toString().trim();
        if (name.isNotEmpty) exerciseCategoryMap[name] = category;
      }

      final exerciseIdByName = <String, int>{};
      final newExercises = <String>[];

      for (final entry in exerciseCategoryMap.entries) {
        final existing =
            await (select(exerciseTable)
              ..where((e) => e.name.equals(entry.key))).getSingleOrNull();
        if (existing == null) {
          final id = await into(exerciseTable).insert(
            ExerciseTableCompanion(
              name: Value(entry.key),
              description: const Value('Imported from FitNotes'),
              type: Value(ExerciseType.strength.index),
              targetMuscleGroups: Value(
                _fitNotesCategory(entry.value).toString(),
              ),
              isCustom: const Value(true),
            ),
          );
          exerciseIdByName[entry.key] = id;
          newExercises.add(entry.key);
        } else {
          exerciseIdByName[entry.key] = existing.id;
        }
      }

      // ── Phase 2: Group rows by date; compute category signature per date ─
      final rowsByDate = <String, List<List<dynamic>>>{};
      for (final row in dataRows) {
        rowsByDate.putIfAbsent(row[0].toString().trim(), () => []).add(row);
      }

      final signatureByDate = <String, String>{};
      for (final entry in rowsByDate.entries) {
        final cats =
            entry.value
                .map((r) => r[2].toString().trim())
                .where((c) => c.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        signatureByDate[entry.key] = cats.join(',');
      }

      // ── Phase 3: Cluster signatures, cap at 10 templates ─────────────────
      final sigFrequency = <String, int>{};
      for (final sig in signatureByDate.values) {
        sigFrequency[sig] = (sigFrequency[sig] ?? 0) + 1;
      }

      // Keep top 9 by frequency; everything else → 'Mixed'
      final topSigs =
          (sigFrequency.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .take(9)
              .map((e) => e.key)
              .toSet();

      final canonicalSigByDate = signatureByDate.map(
        (date, sig) => MapEntry(date, topSigs.contains(sig) ? sig : 'Mixed'),
      );
      final uniqueSigs = canonicalSigByDate.values.toSet();

      // ── Phase 4: Create one WorkoutTable template per unique signature ────
      // Collect union of exercises per signature
      final exercisesBySig = <String, Set<String>>{};
      for (final entry in canonicalSigByDate.entries) {
        final sig = entry.value;
        final exercises = rowsByDate[entry.key]!.map(
          (r) => r[1].toString().trim(),
        );
        exercisesBySig.putIfAbsent(sig, () => {}).addAll(exercises);
      }

      final templateIdBySig = <String, int>{};
      // sig → exerciseName → WorkoutExerciseTable.id
      final weIdBySigAndName = <String, Map<String, int>>{};

      for (final sig in uniqueSigs) {
        final name =
            sig == 'Mixed' ? 'Mixed (FitNotes)' : _categorySignatureToName(sig);
        final templateId = await into(workoutTable).insert(
          WorkoutTableCompanion(
            name: Value(name),
            description: const Value('Imported from FitNotes CSV'),
            difficulty: const Value(1),
            estimatedDurationMinutes: const Value(60),
            isTemplate: const Value(true),
          ),
        );
        templateIdBySig[sig] = templateId;

        int orderPos = 0;
        final weMap = <String, int>{};
        for (final exerciseName in (exercisesBySig[sig]!.toList()..sort())) {
          final exerciseId = exerciseIdByName[exerciseName];
          if (exerciseId == null) continue;
          final weId = await into(workoutExerciseTable).insert(
            WorkoutExerciseTableCompanion(
              workoutId: Value(templateId),
              exerciseId: Value(exerciseId),
              orderPosition: Value(orderPos++),
            ),
          );
          weMap[exerciseName] = weId;
        }
        weIdBySigAndName[sig] = weMap;
      }

      // ── Phase 6: Create historical scheduled entries ──────────────────────
      int totalSets = 0;

      for (final entry in rowsByDate.entries) {
        final dateStr = entry.key;
        final sessionRows = entry.value;
        final sig = canonicalSigByDate[dateStr]!;
        final templateId = templateIdBySig[sig]!;
        final weMap = weIdBySigAndName[sig]!;
        final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();

        final scheduledId = await into(db.scheduledWorkoutTable).insert(
          ScheduledWorkoutTableCompanion(
            workoutId: Value(templateId),
            scheduledDate: Value(parsedDate),
            isCompleted: const Value(true),
            templateWorkoutId: Value(templateId),
          ),
        );

        final byExercise = <String, List<List<dynamic>>>{};
        for (final row in sessionRows) {
          byExercise.putIfAbsent(row[1].toString().trim(), () => []).add(row);
        }

        for (final exEntry in byExercise.entries) {
          final weId = weMap[exEntry.key];
          if (weId == null) continue;

          final sweId = await into(db.scheduledWorkoutExerciseTable).insert(
            ScheduledWorkoutExerciseTableCompanion(
              scheduledWorkoutId: Value(scheduledId),
              workoutExerciseId: Value(weId),
              isCompleted: const Value(true),
            ),
          );

          int setNumber = 1;
          for (final row in exEntry.value) {
            final weight = double.tryParse(row[3].toString()) ?? 0.0;
            final weightUnit =
                row[4].toString().trim().isNotEmpty
                    ? row[4].toString().trim()
                    : 'kg';
            final reps = int.tryParse(row[5].toString()) ?? 0;
            await into(workoutSetTable).insert(
              WorkoutSetTableCompanion(
                scheduledWorkoutExerciseId: Value(sweId),
                setNumber: Value(setNumber++),
                reps: Value(reps),
                weight: Value(weight),
                weightUnit: Value(weightUnit),
                isCompleted: const Value(true),
              ),
            );
            totalSets++;
          }
        }
      }

      return FitNotesImportResult(
        sessions: rowsByDate.length,
        setsImported: totalSets,
        newExercises: newExercises,
        workoutsCreated: templateIdBySig.length,
      );
    });
  }
}

class ScheduledWorkoutExerciseFull {
  final ScheduledWorkoutExerciseTableData scheduled;
  final WorkoutExerciseTableData workoutExercise;
  final ExerciseTableData exercise;

  ScheduledWorkoutExerciseFull({
    required this.scheduled,
    required this.workoutExercise,
    required this.exercise,
  });
}

@DriftAccessor(tables: [WorkoutSetTemplateTable])
class WorkoutSetTemplateTableDao extends DatabaseAccessor<AppDatabase>
    with _$WorkoutSetTemplateTableDaoMixin {
  WorkoutSetTemplateTableDao(AppDatabase db) : super(db);

  Future<List<WorkoutSetTemplateData>> getForWorkoutExercise(
    int workoutExerciseId,
  ) {
    return (select(workoutSetTemplateTable)
      ..where((t) => t.workoutExerciseId.equals(workoutExerciseId))).get();
  }
}

@DriftAccessor(tables: [ScheduledWorkoutExerciseTable])
class ScheduledWorkoutExerciseDao extends DatabaseAccessor<AppDatabase>
    with _$ScheduledWorkoutExerciseDaoMixin {
  ScheduledWorkoutExerciseDao(AppDatabase db) : super(db);

  /// Create scheduled exercises when a workout is scheduled
  Future<void> createForScheduledWorkout({
    required int scheduledWorkoutId,
    required List<int> workoutExerciseIds,
  }) async {
    await batch((batch) {
      batch.insertAll(
        scheduledWorkoutExerciseTable,
        workoutExerciseIds.map(
          (id) => ScheduledWorkoutExerciseTableCompanion.insert(
            scheduledWorkoutId: scheduledWorkoutId,
            workoutExerciseId: id,
          ),
        ),
      );
    });
  }

  /// Watch exercises for ONE scheduled workout (selected date)
  Stream<List<ScheduledWorkoutExerciseFull>> watchForScheduledWorkout(
    int scheduledWorkoutId,
  ) {
    final query =
        select(scheduledWorkoutExerciseTable).join([
            innerJoin(
              workoutExerciseTable,
              workoutExerciseTable.id.equalsExp(
                scheduledWorkoutExerciseTable.workoutExerciseId,
              ),
            ),
            innerJoin(
              exerciseTable,
              exerciseTable.id.equalsExp(workoutExerciseTable.exerciseId),
            ),
          ])
          ..where(
            scheduledWorkoutExerciseTable.scheduledWorkoutId.equals(
              scheduledWorkoutId,
            ),
          )
          ..orderBy([OrderingTerm.asc(workoutExerciseTable.orderPosition)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return ScheduledWorkoutExerciseFull(
          scheduled: row.readTable(scheduledWorkoutExerciseTable),
          workoutExercise: row.readTable(workoutExerciseTable),
          exercise: row.readTable(exerciseTable),
        );
      }).toList();
    });
  }

  Future<List<ScheduledWorkoutExerciseFull>> getForScheduledWorkout(
    int scheduledWorkoutId,
  ) async {
    final query = select(scheduledWorkoutExerciseTable).join([
      leftOuterJoin(
        workoutExerciseTable,
        workoutExerciseTable.id.equalsExp(
          scheduledWorkoutExerciseTable.workoutExerciseId,
        ),
      ),
      leftOuterJoin(
        exerciseTable,
        exerciseTable.id.equalsExp(workoutExerciseTable.exerciseId),
      ),
    ])..where(
      scheduledWorkoutExerciseTable.scheduledWorkoutId.equals(
        scheduledWorkoutId,
      ),
    );

    final rows = await query.get();

    return rows.map((row) {
      return ScheduledWorkoutExerciseFull(
        scheduled: row.readTable(scheduledWorkoutExerciseTable),
        workoutExercise: row.readTable(workoutExerciseTable),
        exercise: row.readTable(exerciseTable),
      );
    }).toList();
  }

  /// 3️⃣ Update exercise notes (date-specific!)
  Future<void> updateNotes(int id, String? notes) {
    return (update(scheduledWorkoutExerciseTable)..where(
      (tbl) => tbl.id.equals(id),
    )).write(ScheduledWorkoutExerciseTableCompanion(notes: Value(notes)));
  }

  /// 4️⃣ Mark exercise completed
  Future<void> setCompleted(int id, bool completed) {
    return (update(scheduledWorkoutExerciseTable)
      ..where((tbl) => tbl.id.equals(id))).write(
      ScheduledWorkoutExerciseTableCompanion(isCompleted: Value(completed)),
    );
  }

  Future<List<WorkoutExerciseTemplate>> getTemplateWithExercises(
    int workoutId,
  ) async {
    final driftExercises =
        await (select(workoutExerciseTable)
              ..where((e) => e.workoutId.equals(workoutId))
              ..orderBy([(e) => OrderingTerm.asc(e.orderPosition)]))
            .get();

    List<WorkoutExerciseTemplate> result = [];

    for (final driftExercise in driftExercises) {
      final driftSets =
          await (select(WorkoutSetTemplateTableDao(db).workoutSetTemplateTable)
                ..where((s) => s.workoutExerciseId.equals(driftExercise.id))
                ..orderBy([(s) => OrderingTerm.asc(s.orderPosition)]))
              .get();

      final sets =
          driftSets.map((s) {
            return WorkoutSetTemplate(
              id: s.id,
              setNumber: s.setNumber,
              targetReps: s.targetReps,
              orderPosition: s.orderPosition,
            );
          }).toList();

      result.add(
        WorkoutExerciseTemplate(
          id: driftExercise.id,
          exerciseId: driftExercise.exerciseId,
          orderPosition: driftExercise.orderPosition,
          sets: sets,
        ),
      );
    }

    return result;
  }
}

@DriftAccessor(tables: [WorkoutPlanTable, WorkoutPlanWorkoutTable])
class WorkoutPlanDao extends DatabaseAccessor<AppDatabase>
    with _$WorkoutPlanDaoMixin {
  WorkoutPlanDao(AppDatabase db) : super(db);

  // Get all workout plans
  Future<List<WorkoutPlanTableData>> getAllPlans() =>
      select(workoutPlanTable).get();

  // Get active workout plans
  Future<List<WorkoutPlanTableData>> getActivePlans() =>
      (select(workoutPlanTable)..where((p) => p.isActive.equals(true))).get();

  // Get a specific plan with its workouts
  Future<WorkoutPlan?> getCompletePlanById(int id) async {
    final planData =
        await (select(workoutPlanTable)
          ..where((p) => p.id.equals(id))).getSingleOrNull();

    if (planData == null) return null;

    // Get all workout IDs in this plan
    final workoutLinks =
        await (select(workoutPlanWorkoutTable)
          ..where((link) => link.planId.equals(id))).get();

    final workoutIds = workoutLinks.map((link) => link.workoutId).toList();

    // Get all workouts
    final workouts = <Workout>[];
    final workoutDao = db.workoutDao;

    for (final workoutId in workoutIds) {
      final workout = await workoutDao.getCompleteWorkoutById(workoutId);
      if (workout != null) {
        workouts.add(workout);
      }
    }

    // Create and return the complete plan
    return WorkoutPlan(
      id: planData.id,
      name: planData.name,
      description: planData.description,
      startDate: planData.startDate,
      workouts: workouts,
      isActive: planData.isActive,
      isFreeChoice: planData.isFreeChoice,
    );
  }

  // Save a workout plan with its workouts
  Future<int> saveWorkoutPlan(WorkoutPlan plan) async {
    return transaction(() async {
      // 1. Save the plan
      final planCompanion = WorkoutPlanTableCompanion(
        id: plan.id == null ? const Value.absent() : Value(plan.id!),
        name: Value(plan.name),
        description: Value(plan.description),
        startDate: Value(plan.startDate),
        isActive: Value(plan.isActive),
      );

      final planId = await into(
        workoutPlanTable,
      ).insert(planCompanion, mode: InsertMode.insertOrReplace);

      // If updating, delete old workout links
      if (plan.id != null) {
        await (delete(workoutPlanWorkoutTable)
          ..where((link) => link.planId.equals(plan.id!))).go();
      }

      // 2. Save each workout in the plan
      final workoutDao = db.workoutDao;

      for (final workout in plan.workouts) {
        // Save the workout
        final workoutId = await workoutDao.saveCompleteWorkout(workout);

        // Create link between plan and workout
        await into(workoutPlanWorkoutTable).insert(
          WorkoutPlanWorkoutTableCompanion(
            planId: Value(planId),
            workoutId: Value(workoutId),
          ),
        );
      }

      return planId;
    });
  }

  // Delete a workout plan and unlink its workouts
  Future<bool> deleteWorkoutPlan(int id) {
    return transaction(() async {
      // Delete links to workouts
      await (delete(workoutPlanWorkoutTable)
        ..where((link) => link.planId.equals(id))).go();

      // Delete plan
      final rowsDeleted =
          await (delete(workoutPlanTable)..where((p) => p.id.equals(id))).go();

      return rowsDeleted > 0;
    });
  }

  // Remove a workout from a plan (delete the relationship, not the workout)
  Future<bool> removeWorkoutFromPlan(int planId, int workoutId) async {
    final rowsDeleted =
        await (delete(workoutPlanWorkoutTable)..where(
          (link) =>
              link.planId.equals(planId) & link.workoutId.equals(workoutId),
        )).go();

    return rowsDeleted > 0;
  }
}
