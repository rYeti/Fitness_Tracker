import 'package:drift/drift.dart';
import '../../../feature/workout_planning/data/models/workout_template_models.dart';
import '../../app_database.dart';

part 'scheduled_workout_exercise_dao.g.dart';

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

@DriftAccessor(tables: [ScheduledWorkoutExerciseTable])
class ScheduledWorkoutExerciseDao extends DatabaseAccessor<AppDatabase>
    with _$ScheduledWorkoutExerciseDaoMixin {
  ScheduledWorkoutExerciseDao(super.db);

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
    return (update(scheduledWorkoutExerciseTable)
      ..where((tbl) => tbl.id.equals(id))).write(
      ScheduledWorkoutExerciseTableCompanion(
        notes: Value(notes),
        syncStatus: const Value(2),
      ),
    );
  }

  /// 4️⃣ Mark exercise completed
  Future<void> setCompleted(int id, bool completed) {
    return (update(scheduledWorkoutExerciseTable)
      ..where((tbl) => tbl.id.equals(id))).write(
      ScheduledWorkoutExerciseTableCompanion(
        isCompleted: Value(completed),
        syncStatus: const Value(2),
      ),
    );
  }

  // ── Sync helpers ─────────────────────────────────────────────────────────────

  Future<List<ScheduledWorkoutExerciseTableData>> getAllForScheduledWorkout(
    int scheduledWorkoutId,
  ) =>
      (select(scheduledWorkoutExerciseTable)
        ..where((e) => e.scheduledWorkoutId.equals(scheduledWorkoutId))).get();

  Future<void> markScheduledExerciseSynced(int localId, String serverId) =>
      (update(scheduledWorkoutExerciseTable)
        ..where((e) => e.id.equals(localId))).write(
        ScheduledWorkoutExerciseTableCompanion(
          syncStatus: const Value(1),
          serverId: Value(serverId),
        ),
      );

  Future<ScheduledWorkoutExerciseTableData?> getByServerId(String serverId) =>
      (select(scheduledWorkoutExerciseTable)
            ..where((e) => e.serverId.equals(serverId))
            ..limit(1))
          .getSingleOrNull();

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
