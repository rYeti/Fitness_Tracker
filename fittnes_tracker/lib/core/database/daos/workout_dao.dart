import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import '../../../feature/workout_planning/data/models/exercise.dart';
import '../../../feature/workout_planning/data/models/workout.dart';
import '../../../feature/workout_planning/data/models/workout_exercise.dart';
import '../../../feature/workout_planning/data/models/workout_set.dart';
import '../../app_database.dart';

part 'workout_dao.g.dart';

/// The heaviest set logged for one exercise, with the reps it was performed
/// at. One set that actually happened, never a best weight paired with a best
/// rep count from a different day — see [WorkoutDao.getAllTimeBestSets].
typedef PersonalBestSet = ({double weight, int reps});

/// Whether [candidate] beats [incumbent] as a personal best: heavier wins, and
/// reps only break a tie on equal weight — never the other way round, because
/// "best" here means heaviest, not highest-volume.
///
/// The same ordering is spelled a second time as the `ORDER BY ws.weight DESC,
/// ws.reps DESC` of the queries below, which no compiler can check against
/// this. It exists in Dart because two of the three places that need it never
/// touch SQL at all: the live, unsaved sets a trainee is typing, and the fold
/// that merges those with what the database already holds.
bool beatsPersonalBest(PersonalBestSet candidate, PersonalBestSet incumbent) =>
    candidate.weight > incumbent.weight ||
    (candidate.weight == incumbent.weight && candidate.reps > incumbent.reps);

/// The better of two personal bests, either of which may be absent. Returns
/// null only when both are.
PersonalBestSet? bestOf(PersonalBestSet? a, PersonalBestSet? b) {
  if (a == null) return b;
  if (b == null) return a;
  return beatsPersonalBest(b, a) ? b : a;
}

/// One exercise's aggregates for one completed day, as the progress dashboard
/// charts them. See [WorkoutDao.getExerciseProgressRows] for what
/// [ExerciseProgressRow.firstSetReps] is and is not.
typedef ExerciseProgressRow =
    ({
      int exerciseId,
      String exerciseName,
      DateTime date,
      double totalVolume,
      double maxWeight,
      int totalReps,
      int setCount,
      int firstSetReps,
    });

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
  // Excludes pendingDelete (3): a delete now marks rather than removes the
  // row outright, so a workout the trainee just deleted must stop appearing
  // here well before the sync push actually reaches the server.
  Future<List<WorkoutTableData>> getAllWorkouts() =>
      (select(workoutTable)..where((w) => w.syncStatus.isNotValue(3))).get();

  // Get workout templates only
  Future<List<WorkoutTableData>> getWorkoutTemplates() => (select(
    workoutTable,
  )..where((w) => w.isTemplate.equals(true) & w.syncStatus.isNotValue(3))).get();

  // Get scheduled workouts
  Future<List<WorkoutTableData>> getScheduledWorkouts() => (select(
    workoutTable,
  )..where((w) => w.isTemplate.equals(false) & w.syncStatus.isNotValue(3))).get();

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
            ..where((w) => w.isTemplate.equals(false))
            ..where((w) => w.syncStatus.isNotValue(3)))
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
              // id breaks ties so two rows sharing a position (possible in data
              // written before positions were kept contiguous) can't swap
              // places between one load and the next.
              ..orderBy([
                (we) => OrderingTerm(expression: we.orderPosition),
                (we) => OrderingTerm.asc(we.id),
              ]))
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
      final setRows = _oneTemplatePerSetNumber(
        await (select(workoutSetTemplateTable)
              ..where((s) => s.workoutExerciseId.equals(exerciseInstance.id))
              ..orderBy([(s) => OrderingTerm(expression: s.setNumber)]))
            .get(),
      );

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
              ..orderBy([
                (we) => OrderingTerm.asc(we.orderPosition),
                (we) => OrderingTerm.asc(we.id),
              ]))
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

      final templates = _oneTemplatePerSetNumber(
        await (select(workoutSetTemplateTable)
              ..where((t) => t.workoutExerciseId.equals(workoutExercise.id))
              ..orderBy([(t) => OrderingTerm.asc(t.setNumber)]))
            .get(),
      );

      if (exercise != null) {
        results.add((exercise, templates, workoutExercise));
      }
    }

    return results;
  }

  /// Keeps the first template for each set number.
  ///
  /// Set numbers are ordinals within an exercise, so two rows numbered 1 are
  /// the same set. A device can still be holding twins left by two pulls that
  /// overlapped (docs/sync-concurrent-runs.md) until the next sync folds them
  /// at rest, and the sync is throttled to once every six hours. Read
  /// unfolded, the active workout lists every set twice with both inputs on
  /// one controller, and the builder saves the twins straight back as pending.
  List<WorkoutSetTemplateData> _oneTemplatePerSetNumber(
    List<WorkoutSetTemplateData> templates,
  ) {
    final seen = <int>{};
    return [
      for (final t in templates)
        if (seen.add(t.setNumber)) t,
    ];
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
        // No status to set here, for this row or any below it: the database
        // marks a synced row pendingUpdate whenever a column the push sends
        // actually changes (lib/core/sync/sync_triggers.dart). This method used
        // to do it by hand, and every write that forgot to — this one included,
        // until it was fixed twice — was an edit that never left the device.
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
          // A reorder, a note or a superset change dirties the row by itself;
          // one that changes nothing leaves it synced (see
          // docs/workout-exercise-order.md for why both halves matter).
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

        // Logged sets are never written here. They belong to a session
        // (`workout_set_table.scheduled_workout_exercise_id`), and the active
        // workout writes them against one. This method used to insert a
        // non-template workout's sets with a *workout* exercise id in that
        // column — an id from another table, which attached them to whichever
        // unrelated session happened to hold that number.

        // Rebuild the prescription only when it changed. Every set template is
        // part of the exercise's list on the server, so rewriting them marks
        // the exercise for pushing (the database treats any change to an owned
        // list as a change to its owner); rewriting an unchanged list on every
        // save would PUT every exercise of the workout for a rename.
        final prescription = [
          for (final set in exercise.sets)
            (set.setNumber, set.targetReps ?? '8 - 12', set.setNumber - 1),
        ];
        final stored = [
          for (final t in await getSetTemplatesForWorkoutExercise(
            exerciseInstanceId,
          ))
            (t.setNumber, t.targetReps, t.orderPosition),
        ];
        if (!_samePrescription(stored, prescription)) {
          await (delete(workoutSetTemplateTable)
            ..where((t) => t.workoutExerciseId.equals(exerciseInstanceId))).go();

          for (final (setNumber, targetReps, orderPosition) in prescription) {
            await into(workoutSetTemplateTable).insert(
              WorkoutSetTemplateTableCompanion(
                workoutExerciseId: Value(exerciseInstanceId),
                setNumber: Value(setNumber),
                targetReps: Value(targetReps),
                orderPosition: Value(orderPosition),
              ),
            );
          }
        }
      }

      return workoutId;
    });
  }

  static bool _samePrescription(
    List<(int, String, int)> a,
    List<(int, String, int)> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Deletes a workout with everything that belongs only to it: its exercise
  /// entries, their set templates, its plan links, and the sessions scheduled
  /// from it that nothing was logged in.
  ///
  /// Returns false, deleting nothing, when a session of it holds logged sets —
  /// the same rule the server applies (it answers 409). Training history
  /// outranks tidiness.
  ///
  /// Foreign keys aren't enforced on this database, so all of it is removed by
  /// hand; nothing cascades. This used to delete logged sets `where
  /// scheduledWorkoutExerciseId == <a workout exercise's id>` — an id from
  /// another table — which removed sets from whichever unrelated sessions
  /// happened to hold those numbers, and left this workout's own templates
  /// and sessions behind.
  Future<bool> deleteWorkout(int id) {
    return transaction(() async {
      final sessions =
          await (select(scheduledWorkoutTable)
            ..where((sw) => sw.workoutId.equals(id))).get();
      final sessionExerciseTable = attachedDatabase.scheduledWorkoutExerciseTable;
      final sessionExercises =
          sessions.isEmpty
              ? <ScheduledWorkoutExerciseTableData>[]
              : await (select(sessionExerciseTable)..where(
                    (se) => se.scheduledWorkoutId.isIn(sessions.map((s) => s.id)),
                  ))
                  .get();
      if (sessionExercises.isNotEmpty) {
        final logged =
            await (select(workoutSetTable)
                  ..where(
                    (s) => s.scheduledWorkoutExerciseId.isIn(
                      sessionExercises.map((e) => e.id),
                    ),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (logged != null) return false;
      }

      await (delete(sessionExerciseTable)..where(
            (se) => se.scheduledWorkoutId.isIn(sessions.map((s) => s.id)),
          ))
          .go();
      await (delete(scheduledWorkoutTable)
        ..where((sw) => sw.workoutId.equals(id))).go();

      final exerciseInstances =
          await (select(workoutExerciseTable)
            ..where((we) => we.workoutId.equals(id))).get();
      await (delete(workoutSetTemplateTable)..where(
            (t) => t.workoutExerciseId.isIn(exerciseInstances.map((e) => e.id)),
          ))
          .go();
      await (delete(workoutExerciseTable)
        ..where((we) => we.workoutId.equals(id))).go();
      await (delete(workoutPlanWorkoutTable)
        ..where((l) => l.workoutId.equals(id))).go();

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

  /// The exercise a set was actually performed as.
  ///
  /// A scheduled exercise can be swapped for the day
  /// (`ScheduledWorkoutExerciseTable.overrideExerciseId`) without touching the
  /// workout it came from, so `workout_exercise_table.exercise_id` names what
  /// was *planned*. Crediting a swap's sets to the exercise it replaced puts
  /// dumbbell presses in the bench press's history.
  static const _performedExerciseId =
      'COALESCE(swe.override_exercise_id, we.exercise_id)';

  /// The all-time heaviest completed, non-warmup set logged for each exercise,
  /// keyed by exercise id. An exercise never logged with a weight is absent
  /// from the map rather than present as a zero — "no PB yet" and "a PB of
  /// 0 kg" are different things and only one of them should be rendered.
  ///
  /// Scoped by exercise rather than by workout: the same lift trained under
  /// two different workouts — which is what any trainer edit produces, see
  /// `docs/trainer-workout-builder.md` — shares one personal best, because
  /// that is what all-time means to the person lifting. Which exercise a set
  /// counts toward is [_performedExerciseId], so a day's swap credits the
  /// exercise actually performed. Ties on weight go to the higher rep count,
  /// so a PB is always one set that actually happened rather than a best
  /// weight welded to a best rep count from another day.
  ///
  /// A set needs both a weight and a rep count to be a PB: "100 kg × 0 reps"
  /// is a half-filled row mid-entry, not a lift.
  ///
  /// Pass [exerciseIds] whenever the caller already knows which exercises it
  /// is about to render, so this stays a single round trip instead of one per
  /// exercise.
  Future<Map<int, PersonalBestSet>> getAllTimeBestSets({
    List<int>? exerciseIds,
  }) => _bestSets(exerciseIds: exerciseIds);

  /// The heaviest completed, non-warmup set for each exercise **within one
  /// training plan** — the collection of workouts a trainee is currently
  /// working through (Upper A, Upper B, …), not one day of it and not all of
  /// history.
  ///
  /// This is the scope a trainee means by "my best on this programme". It sits
  /// between the other two numbers the active-workout screen shows and is
  /// bounded by both: it can never exceed [getAllTimeBestSets] for the same
  /// exercise, and it can never be beaten by the session in progress without
  /// the session's own set becoming the new plan best.
  ///
  /// Scoped by `scheduled_workout_table.workout_plan_id` — the plan a *session*
  /// was scheduled under — rather than by the plan's list of workouts. Those
  /// two differ after any trainer edit, which leaves the plan pointing at a
  /// reshaped workout (see `docs/trainer-workout-builder.md`); the sessions
  /// already logged keep their plan id either way, so the trainee's history on
  /// the programme survives an edit that the workout list would have dropped.
  ///
  /// [planId] is nullable because a scheduled session need not belong to a plan
  /// — one pulled from a server whose plan didn't resolve locally, or one whose
  /// plan was deleted (`SyncService` nulls the column rather than orphaning the
  /// row). With no plan there is no collection of workouts to span, so the
  /// scope degenerates to the sessions of [workoutId] alone, which is the only
  /// collection left. Callers must label the result for the scope they got.
  Future<Map<int, PersonalBestSet>> getPlanBestSets({
    required int? planId,
    required int workoutId,
    List<int>? exerciseIds,
  }) => _bestSets(
    exerciseIds: exerciseIds,
    scopeFilter:
        planId != null
            ? 'AND sw.workout_plan_id = ?'
            : 'AND sw.workout_id = ?',
    scopeVariables: [Variable<int>(planId ?? workoutId)],
  );

  /// Shared body of [getAllTimeBestSets] and [getPlanBestSets]: the two differ
  /// only in which completed sessions they look at, and every other rule about
  /// what counts as a personal best — warmups excluded, a weight and a rep
  /// count both required, the set credited to [_performedExerciseId] — has to
  /// stay identical or the two numbers on screen stop being comparable.
  ///
  /// [scopeFilter] is appended verbatim to the `WHERE` clause and its
  /// placeholders are bound from [scopeVariables], in that order, between the
  /// warmup variable and the exercise-id list.
  Future<Map<int, PersonalBestSet>> _bestSets({
    required List<int>? exerciseIds,
    String scopeFilter = '',
    List<Variable> scopeVariables = const [],
  }) async {
    final ids = exerciseIds?.toSet().toList();
    if (ids != null && ids.isEmpty) return {};

    final idFilter =
        ids == null
            ? ''
            : 'AND $_performedExerciseId IN (${List.filled(ids.length, '?').join(',')})';

    final rows =
        await customSelect(
          '''
      SELECT $_performedExerciseId AS exercise_id, ws.weight AS weight, ws.reps AS reps
      FROM workout_set_table ws
      JOIN scheduled_workout_exercise_table swe ON swe.id = ws.scheduled_workout_exercise_id
      JOIN scheduled_workout_table sw ON sw.id = swe.scheduled_workout_id
      JOIN workout_exercise_table we ON we.id = swe.workout_exercise_id
      WHERE sw.is_completed = 1
        AND ws.set_type != ?
        AND ws.weight IS NOT NULL
        AND ws.reps IS NOT NULL
        AND ws.reps > 0
        $scopeFilter
        $idFilter
      ORDER BY exercise_id, ws.weight DESC, ws.reps DESC
      ''',
          variables: [
            Variable<int>(SetType.warmup.index),
            ...scopeVariables,
            if (ids != null) ...ids.map((id) => Variable<int>(id)),
          ],
        ).get();

    // The ORDER BY already puts each exercise's best set first, so the first
    // row seen for an id wins. Folded here rather than by a window function:
    // those need a newer SQLite than some Android builds ship with, and the
    // result set is one row per logged set for the handful of exercises a
    // caller asks about.
    final best = <int, PersonalBestSet>{};
    for (final row in rows) {
      final exerciseId = row.read<int>('exercise_id');
      if (best.containsKey(exerciseId)) continue;
      best[exerciseId] = (
        weight: row.read<double>('weight'),
        reps: row.read<int>('reps'),
      );
    }

    return best;
  }

  /// One row per exercise per completed day: the volume, heaviest set and rep
  /// totals the progress dashboard charts. Warmups are excluded so they can't
  /// drag a day's numbers around, and only completed sessions count.
  ///
  /// `firstSetReps` is the reps of that day's *first* set, not the reps at
  /// [ExerciseProgressRow.maxWeight] — the dashboard labels points with it and
  /// nothing here should be mistaken for a personal best. Use
  /// [getAllTimeBestSets] for that.
  Future<List<ExerciseProgressRow>> getExerciseProgressRows({
    required DateTime start,
    required DateTime end,
  }) async {
    final rows =
        await customSelect(
          '''
      SELECT
        $_performedExerciseId AS exercise_id,
        e.name            AS exercise_name,
        sw.scheduled_date,
        COALESCE(SUM(COALESCE(ws.weight, 0.0) * COALESCE(ws.reps, 0)), 0.0) AS total_volume,
        COALESCE(MAX(COALESCE(ws.weight, 0.0)), 0.0)  AS max_weight,
        COALESCE(SUM(COALESCE(ws.reps, 0)), 0)        AS total_reps,
        COUNT(ws.id)                                   AS set_count,
        COALESCE((SELECT ws2.reps FROM workout_set_table ws2
                  WHERE ws2.scheduled_workout_exercise_id = swe.id
                  ORDER BY ws2.set_number ASC LIMIT 1), 0) AS first_set_reps
      FROM scheduled_workout_table sw
      JOIN scheduled_workout_exercise_table swe ON swe.scheduled_workout_id = sw.id
      JOIN workout_exercise_table           we  ON we.id  = swe.workout_exercise_id
      JOIN exercise_table                   e   ON e.id   = $_performedExerciseId
      JOIN workout_set_table                ws  ON ws.scheduled_workout_exercise_id = swe.id
      WHERE sw.is_completed = 1
        AND (ws.reps IS NOT NULL OR ws.weight IS NOT NULL)
        AND ws.set_type != ?
        AND sw.scheduled_date >= ?
        AND sw.scheduled_date <= ?
      GROUP BY exercise_id, sw.scheduled_date
      ORDER BY e.name ASC, sw.scheduled_date ASC
      ''',
          variables: [
            Variable<int>(SetType.warmup.index),
            Variable<DateTime>(start),
            Variable<DateTime>(end),
          ],
        ).get();

    return rows
        .map(
          (row) => (
            exerciseId: row.read<int>('exercise_id'),
            exerciseName: row.read<String>('exercise_name'),
            date: row.read<DateTime>('scheduled_date'),
            totalVolume: row.readNullable<double>('total_volume') ?? 0.0,
            maxWeight: row.readNullable<double>('max_weight') ?? 0.0,
            totalReps: row.readNullable<int>('total_reps') ?? 0,
            setCount: row.read<int>('set_count'),
            firstSetReps: row.readNullable<int>('first_set_reps') ?? 0,
          ),
        )
        .toList();
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
