import 'package:drift/drift.dart';
import '../../../feature/workout_planning/data/models/workout.dart';
import '../../../feature/workout_planning/data/models/workout_plan.dart';
import '../../app_database.dart';

part 'workout_plan_dao.g.dart';

@DriftAccessor(tables: [WorkoutPlanTable, WorkoutPlanWorkoutTable])
class WorkoutPlanDao extends DatabaseAccessor<AppDatabase>
    with _$WorkoutPlanDaoMixin {
  WorkoutPlanDao(super.db);

  // Get all workout plans. Excludes pendingDelete (3): a delete now marks
  // rather than removes the row outright, so a plan the trainee just deleted
  // must stop appearing here well before the sync push actually reaches the
  // server — see WorkoutPlanDao.markPlanPendingDelete.
  Future<List<WorkoutPlanTableData>> getAllPlans() =>
      (select(workoutPlanTable)..where((p) => p.syncStatus.isNotValue(3))).get();

  // Get active workout plans
  Future<List<WorkoutPlanTableData>> getActivePlans() => (select(
    workoutPlanTable,
  )..where((p) => p.isActive.equals(true) & p.syncStatus.isNotValue(3))).get();

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

      // Update in place rather than INSERT OR REPLACE, which deletes the row
      // and inserts a fresh one — losing its server id, its sync status and
      // every column this companion doesn't set.
      final int planId;
      if (plan.id == null) {
        planId = await into(workoutPlanTable).insert(planCompanion);
      } else {
        planId = plan.id!;
        await (update(workoutPlanTable)
          ..where((p) => p.id.equals(planId))).write(planCompanion);
      }

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

      // Sessions scheduled from it outlive it, detached — the server's
      // ON DELETE SET NULL on the same column. Foreign keys aren't enforced
      // here, so nothing else would clear it, and a session left pointing at a
      // deleted plan's id would be grouped under a plan that no longer exists.
      await (update(attachedDatabase.scheduledWorkoutTable)
        ..where((sw) => sw.workoutPlanId.equals(id))).write(
        const ScheduledWorkoutTableCompanion(workoutPlanId: Value(null)),
      );

      // Delete plan
      final rowsDeleted =
          await (delete(workoutPlanTable)..where((p) => p.id.equals(id))).go();

      return rowsDeleted > 0;
    });
  }

  /// Deletes a plan the way the user means it: the plan goes, and so do the
  /// sessions it scheduled that were never trained — but every session the
  /// user actually did stays, with its logged sets.
  ///
  /// A session counts as trained if it has any logged set or was marked
  /// complete. The plan itself is marked `pendingDelete` so the push can tell
  /// the server; once it has, [deleteWorkoutPlan] detaches the sessions that
  /// were kept. The untrained ones are deleted outright, which the database
  /// records as server DELETEs for any the server already has
  /// (`lib/core/sync/sync_triggers.dart`), and which takes them off the
  /// calendar at once rather than after the next sync.
  ///
  /// The workouts list used to mark *every* session of the plan for deletion,
  /// logged ones included, and the server then deleted that training history
  /// for good. The plan editor did the opposite and left even the future,
  /// never-trained sessions behind on the calendar. Both call this now.
  Future<void> deletePlanKeepingHistory(int planId) {
    final db = attachedDatabase;
    return transaction(() async {
      final sessions =
          await (select(db.scheduledWorkoutTable)
            ..where((sw) => sw.workoutPlanId.equals(planId))).get();
      for (final session in sessions) {
        if (session.isCompleted) continue;
        final exercises =
            await (select(db.scheduledWorkoutExerciseTable)
              ..where((se) => se.scheduledWorkoutId.equals(session.id))).get();
        final logged =
            exercises.isEmpty
                ? null
                : await (select(db.workoutSetTable)
                      ..where(
                        (s) => s.scheduledWorkoutExerciseId.isIn(
                          exercises.map((e) => e.id),
                        ),
                      )
                      ..limit(1))
                    .getSingleOrNull();
        if (logged != null) continue;

        await (delete(db.scheduledWorkoutExerciseTable)
          ..where((se) => se.scheduledWorkoutId.equals(session.id))).go();
        await (delete(db.scheduledWorkoutTable)
          ..where((sw) => sw.id.equals(session.id))).go();
      }
      await markPlanPendingDelete(planId);
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

  // ── Sync helpers ─────────────────────────────────────────────────────────────

  Future<List<WorkoutPlanTableData>> getUnsyncedPlans() =>
      (select(workoutPlanTable)
        ..where((p) => p.syncStatus.isNotValue(1))).get();

  Future<void> markPlanSynced(int localId, String serverId) =>
      (update(workoutPlanTable)..where((p) => p.id.equals(localId))).write(
        WorkoutPlanTableCompanion(
          syncStatus: const Value(1),
          serverId: Value(serverId),
        ),
      );

  Future<void> markPlanPendingUpdate(int id) => (update(workoutPlanTable)
    ..where(
      (p) => p.id.equals(id),
    )).write(const WorkoutPlanTableCompanion(syncStatus: Value(2)));

  Future<void> markPlanPendingDelete(int id) => (update(workoutPlanTable)
    ..where(
      (p) => p.id.equals(id),
    )).write(const WorkoutPlanTableCompanion(syncStatus: Value(3)));

  Future<List<WorkoutPlanWorkoutTableData>> getPlanWorkoutsForPlan(
    int planId,
  ) =>
      (select(workoutPlanWorkoutTable)
        ..where((pw) => pw.planId.equals(planId))).get();

  Future<List<WorkoutPlanWorkoutTableData>> getUnsyncedPlanWorkouts() =>
      (select(workoutPlanWorkoutTable)
        ..where((pw) => pw.syncStatus.isNotValue(1))).get();

  Future<WorkoutPlanTableData?> getPlanByServerId(String serverId) =>
      (select(workoutPlanTable)
            ..where((p) => p.serverId.equals(serverId))
            ..limit(1))
          .getSingleOrNull();
}
