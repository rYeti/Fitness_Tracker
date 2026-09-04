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

  Future<void> markPlanWorkoutSynced(int localId, String serverId) =>
      (update(workoutPlanWorkoutTable)
        ..where((pw) => pw.id.equals(localId))).write(
        WorkoutPlanWorkoutTableCompanion(
          syncStatus: const Value(1),
          serverId: Value(serverId),
        ),
      );

  Future<WorkoutPlanTableData?> getPlanByServerId(String serverId) =>
      (select(workoutPlanTable)
            ..where((p) => p.serverId.equals(serverId))
            ..limit(1))
          .getSingleOrNull();
}
