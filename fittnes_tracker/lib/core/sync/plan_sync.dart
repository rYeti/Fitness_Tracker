part of 'sync_service.dart';

/// Workout plans and the workouts each one holds.
extension PlanSync on SyncService {
  Future<void> syncWorkoutPlans() async {
    final unsynced = await _db.workoutPlanDao.getUnsyncedPlans();
    if (unsynced.isEmpty) return;

    for (final plan in unsynced) {
      try {
        switch (SyncStatus.fromDb(plan.syncStatus)) {
          case SyncStatus.pending:
            await _syncNewPlan(plan);
          case SyncStatus.pendingUpdate:
            await _syncUpdatePlan(plan);
          case SyncStatus.pendingDelete:
            await _syncDeletePlan(plan);
          case SyncStatus.synced || SyncStatus.retired:
            break;
        }
      } catch (e) {
        _logger.w('Plan sync failed for local ${plan.id}: $e');
      }
    }
  }

  Future<int?> _getPlanDurationDays(int planId) async {
    final row = await _db
        .customSelect(
          'SELECT duration_days FROM workout_plan_table WHERE id = ?',
          variables: [Variable.withInt(planId)],
        )
        .getSingleOrNull();
    return row?.read<int?>('duration_days');
  }

  Future<void> _syncNewPlan(WorkoutPlanTableData p) async {
    final durationDays = await _getPlanDurationDays(p.id);
    final response = await _apiClient.post(
      'api/WorkoutPlan',
      data: {
        'name': p.name,
        'description': p.description,
        'startDate': p.startDate.toUtc().toIso8601String(),
        'cyclePatternJson': p.cyclePatternJson,
        'isFreeChoice': p.isFreeChoice,
        'durationDays': durationDays,
      },
    );
    final serverId = response.data['id'] as String;
    await _markSent(_db.workoutPlanTable, p.id, serverId, p.localRev);

    // Link workouts to the plan (batch).
    final links = await _db.workoutPlanDao.getPlanWorkoutsForPlan(p.id);
    await _syncNewPlanWorkoutsBatch(
      links.where((l) => l.syncStatus != 1).toList(),
      serverId,
    );
    _logger.i('Synced new plan ${p.id} → server $serverId');
  }

  Future<void> _syncUpdatePlan(WorkoutPlanTableData p) async {
    if (p.serverId == null) {
      await _syncNewPlan(p);
      return;
    }
    final durationDays = await _getPlanDurationDays(p.id);
    await _apiClient.put(
      'api/WorkoutPlan/${p.serverId}',
      data: {
        'name': p.name,
        'description': p.description,
        'startDate': p.startDate.toUtc().toIso8601String(),
        'cyclePatternJson': p.cyclePatternJson,
        'isFreeChoice': p.isFreeChoice,
        'durationDays': durationDays,
      },
    );

    // The links before the plan is marked synced: a new link is what dirtied
    // the plan (the database marks the owner), so marking it first and then
    // failing on the links left them behind a plan that no longer looked like
    // it had anything to send.
    final links = await _db.workoutPlanDao.getPlanWorkoutsForPlan(p.id);
    await _syncNewPlanWorkoutsBatch(
      links.where((l) => l.syncStatus != 1).toList(),
      p.serverId!,
    );
    await _markSent(_db.workoutPlanTable, p.id, p.serverId!, p.localRev);
    _logger.i('Updated plan ${p.id} on server ${p.serverId}');
  }

  Future<void> _syncDeletePlan(WorkoutPlanTableData p) async {
    if (p.serverId != null) {
      try {
        await _apiClient.delete('api/WorkoutPlan/${p.serverId}');
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) rethrow;
      }
    }
    await _db.untracked(() => _db.workoutPlanDao.deleteWorkoutPlan(p.id));
    _logger.i('Deleted plan ${p.id} (server ${p.serverId})');
  }

  Future<void> _syncNewPlanWorkoutsBatch(
    List<WorkoutPlanWorkoutTableData> links,
    String planServerId,
  ) async {
    final serverIds = <String>[];
    final valid = <WorkoutPlanWorkoutTableData>[];
    for (final link in links) {
      final workoutRow =
          await ((_db.select(_db.workoutTable))
            ..where((w) => w.id.equals(link.workoutId))).getSingleOrNull();
      if (workoutRow?.serverId == null) continue;
      serverIds.add(workoutRow!.serverId!);
      valid.add(link);
    }
    if (serverIds.isEmpty) return;
    await _apiClient.post(
      'api/WorkoutPlan/$planServerId/workouts/batch',
      data: serverIds,
    );
    for (final link in valid) {
      await _db.workoutPlanDao.markPlanWorkoutSynced(link.id, planServerId);
    }
  }

  Future<void> _pullWorkoutPlans() async {
    final response = await _apiClient.get('api/WorkoutPlan');
    final list = (response.data as List).cast<Map<String, dynamic>>();
    await _applyEach('plans', list, _applyServerPlan);

    await _removeDeletedElsewhere<WorkoutPlanTableData>(
      what: 'plans',
      serverIds: {for (final p in list) p['id'] as String},
      locals:
          await (_db.select(_db.workoutPlanTable)
            ..where((t) => t.serverId.isNotNull())).get(),
      serverIdOf: (r) => r.serverId!,
      syncStatusOf: (r) => r.syncStatus,
      // Deleting a plan never touches its days server-side (only the
      // grouping goes away — see TrainerConsoleService.DeleteClientWorkoutPlanAsync),
      // so nothing here needs to protect logged history; deleteWorkoutPlan
      // detaches the sessions that pointed at it.
      delete: (r) => _db.workoutPlanDao.deleteWorkoutPlan(r.id),
    );
  }

  Future<void> _applyServerPlan(Map<String, dynamic> p) async {
    final planServerId = p['id'] as String;
    final existingPlan = await _db.workoutPlanDao.getPlanByServerId(
      planServerId,
    );
    if (existingPlan != null) {
      // A trainer building a client's plan from the console adds workouts
      // to it after the plan itself already exists, so a device that
      // pulled the plan before that happened needs to pick the new
      // membership up on a later sync — this pull otherwise only ever
      // runs the insert path below, which nothing here reaches a second
      // time. Additive only: there's no path in this method (or in
      // `_pullScheduledWorkouts`) for removing a link, so trying to
      // reconcile a workout *out* of the plan here would have nothing to
      // undo the schedule it already generated on the device.
      await _addMissingPlanWorkoutLinks(existingPlan.id, p);
      return;
    }
    final localPlanId = await _db
        .into(_db.workoutPlanTable)
        .insert(
          WorkoutPlanTableCompanion(
            name: Value(p['name'] as String),
            description: Value(p['description'] as String?),
            startDate: Value(DateTime.parse(p['startDate'] as String)),
            createdAt: Value(DateTime.parse(p['createdAt'] as String)),
            isActive: Value(p['isActive'] as bool),
            cyclePatternJson: Value(p['cyclePatternJson'] as String),
            isFreeChoice: Value(p['isFreeChoice'] as bool),
            serverId: Value(planServerId),
            syncStatus: const Value(1),
          ),
        );
    final serverDurationDays = p['durationDays'] as int?;
    if (serverDurationDays != null) {
      await _db.customStatement(
        'UPDATE workout_plan_table SET duration_days = ? WHERE id = ?',
        [serverDurationDays, localPlanId],
      );
    }
    for (final workoutServerId in (p['workoutIds'] as List).cast<String>()) {
      final localWorkout = await _db.workoutDao.getWorkoutByServerId(
        workoutServerId,
      );
      if (localWorkout == null) continue;
      await _db
          .into(_db.workoutPlanWorkoutTable)
          .insert(
            WorkoutPlanWorkoutTableCompanion(
              planId: Value(localPlanId),
              workoutId: Value(localWorkout.id),
              syncStatus: const Value(1),
            ),
          );
    }
    _logger.i('Pulled plan $planServerId');
  }

  /// Adds whatever workout-plan links the server reports that this device
  /// doesn't have yet. Never removes one — see the call site's note on why
  /// there's nothing downstream that could safely absorb a removal.
  Future<void> _addMissingPlanWorkoutLinks(
    int localPlanId,
    Map<String, dynamic> p,
  ) async {
    for (final workoutServerId in (p['workoutIds'] as List).cast<String>()) {
      if (_linksRemovedHere.contains('${p['id']}|$workoutServerId')) continue;
      final localWorkout = await _db.workoutDao.getWorkoutByServerId(
        workoutServerId,
      );
      if (localWorkout == null) continue;

      final alreadyLinked =
          await (_db.select(_db.workoutPlanWorkoutTable)..where(
                (t) =>
                    t.planId.equals(localPlanId) &
                    t.workoutId.equals(localWorkout.id),
              ))
              .getSingleOrNull();
      if (alreadyLinked != null) continue;

      await _db
          .into(_db.workoutPlanWorkoutTable)
          .insert(
            WorkoutPlanWorkoutTableCompanion(
              planId: Value(localPlanId),
              workoutId: Value(localWorkout.id),
              syncStatus: const Value(1),
            ),
          );
    }
  }
}
