import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import '../../../feature/workout_planning/data/models/exercise.dart';
import '../../../feature/workout_planning/data/models/workout.dart';
import '../../../feature/workout_planning/data/models/workout_exercise.dart';
import '../../../feature/workout_planning/data/models/workout_set.dart';
import '../../app_database.dart';

part 'workout_dao.g.dart';

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
  WorkoutDao(super.db);

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
              ..where(
                (we) =>
                    we.workoutId.equals(id) &
                    we.syncStatus.isNotValue(3) &
                    we.syncStatus.isNotValue(4),
              )
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
          supersetGroupId: exerciseInstance.supersetGroupId,
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
              ..where(
                (we) =>
                    we.workoutId.equals(workoutId) &
                    we.syncStatus.isNotValue(3) &
                    we.syncStatus.isNotValue(4),
              )
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
          await (select(workoutSetTemplateTable)
                ..where((t) => t.workoutExerciseId.equals(workoutExercise.id))
                ..orderBy([(t) => OrderingTerm.asc(t.setNumber)]))
              .get();

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

        // An edit to an already-synced workout has to re-enter the push queue,
        // or nothing below this line ever reaches the server: syncWorkoutTemplates
        // only looks at rows whose syncStatus != synced, so leaving it at synced
        // stranded every rename, every set change, and — worst — every
        // pendingDelete stamped on a removed exercise in step 2️⃣, which is what
        // put deleted exercises back on the next full pull.
        //
        // Only synced is promoted: pending (a workout that has never reached the
        // server) and pendingDelete (one on its way out) both outrank an update
        // and must not be overwritten by it.
        final current =
            await (select(workoutTable)
              ..where((w) => w.id.equals(workoutId))).getSingleOrNull();
        if (current?.syncStatus == 1) {
          await markWorkoutPendingUpdate(workoutId);
        }
      }

      // 🔹 2️⃣ If updating, diff old vs new exercises.
      // Match by the existing workoutExercise row id (which callers already
      // carry over for exercises they didn't remove) rather than exerciseId —
      // a workout can contain the same exercise more than once (e.g. a
      // superset pairing the same move), and matching by exerciseId can't
      // tell those instances apart: a Set<exerciseId>.contains() check stays
      // true as long as ANY instance of that exercise remains, so removing
      // one of several duplicates was silently ignored and the wrong row
      // could get updated in its place.
      // Update in-place when the row id is still present so that
      // workoutExercise.id stays stable — historical scheduledWorkoutExercise
      // rows (and the progress-screen JOIN) depend on these IDs not changing.
      // Only hard-delete rows for exercises that were actually removed.
      Map<int, WorkoutExerciseTableData> existingById = {};
      if (workout.id != null) {
        // Excludes retired (4) rows: the builder never showed them, so they
        // can never appear in keptIds below, and diffing them in would mark
        // them pendingDelete and eventually hard-delete them — destroying the
        // historic sets that stamping them retired in the first place was
        // meant to preserve. See WorkoutExerciseTable's doc comment.
        final existingExercises =
            await (select(workoutExerciseTable)..where(
                  (we) =>
                      we.workoutId.equals(workoutId) &
                      we.syncStatus.isNotValue(4),
                ))
                .get();

        existingById = {for (final e in existingExercises) e.id: e};

        final keptIds =
            workout.exercises.map((e) => e.id).whereType<int>().toSet();

        // Remove only the exercises that are no longer in the workout.
        // If the exercise was already pushed to the server (has a serverId),
        // don't hard-delete it yet — mark it pendingDelete so SyncService can
        // issue the DELETE call first. Hard-deleting here would drop the
        // serverId before sync ever runs, so the exercise would never be
        // removed server-side and would reappear on the next pull/reconcile.
        for (final ex in existingExercises) {
          if (!keptIds.contains(ex.id)) {
            if (ex.serverId != null) {
              await (update(workoutExerciseTable)
                ..where((we) => we.id.equals(ex.id))).write(
                const WorkoutExerciseTableCompanion(
                  syncStatus: Value(3), // pendingDelete
                ),
              );
            } else {
              await (delete(workoutSetTemplateTable)
                ..where((t) => t.workoutExerciseId.equals(ex.id))).go();
              await (delete(workoutExerciseTable)
                ..where((we) => we.id.equals(ex.id))).go();
            }
          }
        }
      }

      // 🔹 3️⃣ Save exercises + sets
      for (final exercise in workout.exercises) {
        int exerciseInstanceId;

        final existing = exercise.id != null ? existingById[exercise.id] : null;
        if (existing != null) {
          // Update in-place — preserve the ID so historical data stays linked.
          exerciseInstanceId = existing.id;
          await (update(workoutExerciseTable)
            ..where((we) => we.id.equals(exerciseInstanceId))).write(
            WorkoutExerciseTableCompanion(
              orderPosition: Value(exercise.orderPosition),
              notes: Value(exercise.notes),
              supersetGroupId: Value(exercise.supersetGroupId),
            ),
          );
        } else {
          // New exercise added to the workout — insert fresh.
          exerciseInstanceId = await into(workoutExerciseTable).insert(
            WorkoutExerciseTableCompanion(
              workoutId: Value(workoutId),
              exerciseId: Value(exercise.exerciseId),
              orderPosition: Value(exercise.orderPosition),
              notes: Value(exercise.notes),
              supersetGroupId: Value(exercise.supersetGroupId),
            ),
          );
        }

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
              rpe: Value(set.rpe),
              setType: Value(set.setType.index),
              side: Value(set.side.index),
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

  // ── Sync helpers ─────────────────────────────────────────────────────────────

  // Workouts (templates only)
  Future<List<WorkoutTableData>> getUnsyncedTemplates() =>
      (select(workoutTable)..where(
        (w) => w.isTemplate.equals(true) & w.syncStatus.isNotValue(1),
      )).get();

  Future<void> markWorkoutSynced(int localId, String serverId) =>
      (update(workoutTable)..where((w) => w.id.equals(localId))).write(
        WorkoutTableCompanion(
          syncStatus: const Value(1),
          serverId: Value(serverId),
        ),
      );

  Future<void> markWorkoutPendingUpdate(int id) => (update(workoutTable)..where(
    (w) => w.id.equals(id),
  )).write(const WorkoutTableCompanion(syncStatus: Value(2)));

  Future<void> markWorkoutPendingDelete(int id) => (update(workoutTable)..where(
    (w) => w.id.equals(id),
  )).write(const WorkoutTableCompanion(syncStatus: Value(3)));

  // WorkoutExercises
  Future<List<WorkoutExerciseTableData>> getUnsyncedWorkoutExercises() =>
      (select(workoutExerciseTable)..where(
        (we) => we.syncStatus.isNotValue(1) & we.syncStatus.isNotValue(4),
      )).get();

  Future<void> markWorkoutExerciseSynced(int localId, String serverId) =>
      (update(workoutExerciseTable)
        ..where((we) => we.id.equals(localId))).write(
        WorkoutExerciseTableCompanion(
          syncStatus: const Value(1),
          serverId: Value(serverId),
        ),
      );

  Future<List<WorkoutExerciseTableData>> getExercisesForWorkoutRaw(
    int workoutId,
  ) =>
      (select(workoutExerciseTable)
        ..where((we) => we.workoutId.equals(workoutId))).get();

  /// Hard-deletes a workout exercise (and its set templates) after it has
  /// been removed on the server, or immediately if it was never synced.
  Future<void> deleteWorkoutExercise(int id) => transaction(() async {
    await (delete(workoutSetTemplateTable)
      ..where((t) => t.workoutExerciseId.equals(id))).go();
    await (delete(workoutExerciseTable)..where((we) => we.id.equals(id))).go();
  });

  // WorkoutSetTemplates
  Future<List<WorkoutSetTemplateData>> getUnsyncedSetTemplates() =>
      (select(workoutSetTemplateTable)
        ..where((t) => t.syncStatus.isNotValue(1))).get();

  Future<void> markSetTemplateSynced(int localId, String serverId) =>
      (update(workoutSetTemplateTable)
        ..where((t) => t.id.equals(localId))).write(
        WorkoutSetTemplateTableCompanion(
          syncStatus: const Value(1),
          serverId: Value(serverId),
        ),
      );

  // ScheduledWorkouts
  Future<List<ScheduledWorkoutTableData>> getUnsyncedScheduledWorkouts() =>
      (select(scheduledWorkoutTable)
        ..where((sw) => sw.syncStatus.isNotValue(1))).get();

  Future<void> markScheduledWorkoutSynced(int localId, String serverId) =>
      (update(scheduledWorkoutTable)
        ..where((sw) => sw.id.equals(localId))).write(
        ScheduledWorkoutTableCompanion(
          syncStatus: const Value(1),
          serverId: Value(serverId),
        ),
      );

  Future<void> markScheduledWorkoutPendingDelete(int id) =>
      (update(scheduledWorkoutTable)..where(
        (sw) => sw.id.equals(id),
      )).write(const ScheduledWorkoutTableCompanion(syncStatus: Value(3)));

  // WorkoutSets
  Future<List<WorkoutSetTableData>> getUnsyncedWorkoutSets() =>
      (select(workoutSetTable)..where((s) => s.syncStatus.isNotValue(1))).get();

  Future<List<WorkoutSetTableData>> getSetsForScheduledExercise(
    int scheduledExerciseId,
  ) =>
      (select(workoutSetTable)..where(
        (s) => s.scheduledWorkoutExerciseId.equals(scheduledExerciseId),
      )).get();

  Future<void> markWorkoutSetSynced(int localId, String serverId) =>
      (update(workoutSetTable)..where((s) => s.id.equals(localId))).write(
        WorkoutSetTableCompanion(
          syncStatus: const Value(1),
          serverId: Value(serverId),
        ),
      );

  Future<void> markWorkoutSetPendingDelete(int id) => (update(workoutSetTable)
    ..where(
      (s) => s.id.equals(id),
    )).write(const WorkoutSetTableCompanion(syncStatus: Value(3)));

  Future<WorkoutTableData?> getWorkoutByServerId(String serverId) =>
      (select(workoutTable)
            ..where((w) => w.serverId.equals(serverId))
            ..limit(1))
          .getSingleOrNull();

  Future<WorkoutExerciseTableData?> getWorkoutExerciseByServerId(
    String serverId,
  ) =>
      (select(workoutExerciseTable)
            ..where((we) => we.serverId.equals(serverId))
            ..limit(1))
          .getSingleOrNull();

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
