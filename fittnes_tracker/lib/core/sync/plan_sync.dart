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
    final response = await _create(
      'api/WorkoutPlan',
      {'id': p.serverId, ...await _planBody(p)},
      _db.workoutPlanTable,
      [p.id],
    );
    if (response == null) return;
    final serverId = response.data['id'] as String;
    // Out of `pending` the moment the server has it, and still dirty until its
    // workouts are across. Marked after the list instead, a list that failed
    // left a plan the server held at `pending` — and the sessions pushed next
    // in the same run, reading that as "the server has no such plan", went
    // up without it, for good.
    await _markSent(_db.workoutPlanTable, p.id, serverId, -1);
    if (await _putPlanWorkouts(p.id, serverId)) {
      await _markSent(_db.workoutPlanTable, p.id, serverId, p.localRev);
    }
    _logger.i('Synced new plan ${p.id} → server $serverId');
  }

  Future<Map<String, dynamic>> _planBody(WorkoutPlanTableData p) async => {
    'name': p.name,
    'description': p.description,
    'startDate': p.startDate.toUtc().toIso8601String(),
    'cyclePatternJson': p.cyclePatternJson,
    'isFreeChoice': p.isFreeChoice,
    'durationDays': await _getPlanDurationDays(p.id),
  };

  Future<void> _syncUpdatePlan(WorkoutPlanTableData p) async {
    if (p.serverId == null) {
      await _syncNewPlan(p);
      return;
    }
    await _apiClient.put(
      'api/WorkoutPlan/${p.serverId}',
      data: await _planBody(p),
    );

    // The list before the plan is marked synced: a changed list is what
    // dirtied the plan (the database marks the owner), so marking it first
    // and then failing on the list left it behind a plan that no longer
    // looked like it had anything to send.
    final complete = await _putPlanWorkouts(p.id, p.serverId!);
    await _markSent(
      _db.workoutPlanTable,
      p.id,
      p.serverId!,
      complete ? p.localRev : -1,
    );
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

  /// Sends the plan's whole list of workouts, which the server makes the
  /// plan's list: links it lacks are added, and links not in it removed.
  ///
  /// This replaced adding new links in a batch and removing each dropped one
  /// with its own DELETE, which needed the database to record every removal.
  /// A removal now only has to dirty the plan (`sync_triggers.dart`), and the
  /// list says the rest. A link has no id of its own, so there is nothing to
  /// upsert it by, as a meal's foods are; the cost is last-writer-wins for
  /// the list (`docs/sync-architecture.md` §18).
  ///
  /// Returns false, sending nothing, while a workout in the plan is not on
  /// the server yet; the plan stays dirty and goes when the workout has. It
  /// used to send the list without that workout — but "not on the server" is
  /// only what this device has heard: a create whose answer was lost, or a
  /// workout kept for its history, is `pending` on a server that has it, and
  /// the list without it unlinked it there.
  Future<bool> _putPlanWorkouts(int localPlanId, String planServerId) async {
    final links = await _db.workoutPlanDao.getPlanWorkoutsForPlan(localPlanId);
    final workoutServerIds = <String>[];
    for (final link in links) {
      final workout =
          await ((_db.select(_db.workoutTable))
            ..where((w) => w.id.equals(link.workoutId))).getSingleOrNull();
      if (workout == null) continue; // a dangling link names nothing to send
      final id = SyncService._serverIdIfPushed(
        workout.serverId,
        workout.syncStatus,
      );
      if (id == null) {
        _logger.i(
          'Plan $localPlanId: workout ${workout.id} is not on the server yet; '
          'its list waits for it',
        );
        return false;
      }
      workoutServerIds.add(id);
    }
    await _apiClient.put(
      'api/WorkoutPlan/$planServerId/workouts',
      data: workoutServerIds,
    );
    await _db.untracked(
      () => (_db.update(_db.workoutPlanWorkoutTable)
            ..where((l) => l.planId.equals(localPlanId)))
          .write(
            WorkoutPlanWorkoutTableCompanion(
              syncStatus: Value(SyncStatus.synced.index),
            ),
          ),
    );
    return true;
  }

  Future<void> _pullWorkoutPlans() async {
    final response = await _apiClient.get('api/WorkoutPlan');
    final list = (response.data as List).cast<Map<String, dynamic>>();
    await _applyEach('plans', list, _applyServerPlan);

    await _removeDeletedElsewhere<WorkoutPlanTableData>(
      what: 'plans',
      serverIds: {for (final p in list) p['id'] as String},
      locals:
          await (_db.select(_db.workoutPlanTable)..where(
                (t) =>
                    t.serverId.isNotNull() &
                    t.syncStatus.isNotValue(SyncStatus.pending.index),
              ))
              .get(),
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
      // A trainer building a client's plan from the console adds workouts to
      // it after the plan itself exists, so a device that already pulled the
      // plan picks the new membership up here.
      await _mirrorPlanWorkoutLinks(existingPlan, p);
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

  /// Makes a clean plan's workouts match the server's list; leaves a dirty
  /// one alone.
  ///
  /// This used to only ever add, and it didn't need to remove: the push added
  /// links a batch at a time and never re-sent one the server already had. It
  /// now sends the plan's whole list, so a link left here after it went on the
  /// server — removed there by another device — would go back up with the
  /// next edit to the plan. A clean plan holds nothing the server hasn't seen,
  /// so its list is the server's to set; a dirty one holds this device's
  /// unsent change to it, which the push sends whole.
  ///
  /// The schedule the plan already generated on this device is not touched.
  Future<void> _mirrorPlanWorkoutLinks(
    WorkoutPlanTableData plan,
    Map<String, dynamic> p,
  ) async {
    if (SyncStatus.fromDb(plan.syncStatus) != SyncStatus.synced) return;

    final wanted = <int>{};
    for (final workoutServerId in (p['workoutIds'] as List).cast<String>()) {
      // Removed here by an older build and not yet removed on the server.
      if (_linksRemovedHere.contains('${p['id']}|$workoutServerId')) continue;
      final localWorkout = await _db.workoutDao.getWorkoutByServerId(
        workoutServerId,
      );
      if (localWorkout != null) wanted.add(localWorkout.id);
    }

    final links = await _db.workoutPlanDao.getPlanWorkoutsForPlan(plan.id);
    final linked = links.map((l) => l.workoutId).toSet();
    for (final link in links) {
      if (wanted.contains(link.workoutId)) continue;
      // A workout the server doesn't hold stays linked: it may just not have
      // arrived, and the server can't have removed what it never had.
      final workout =
          await ((_db.select(_db.workoutTable))
            ..where((w) => w.id.equals(link.workoutId))).getSingleOrNull();
      if (workout == null ||
          SyncService._serverIdIfPushed(workout.serverId, workout.syncStatus) ==
              null) {
        continue;
      }
      await (_db.delete(_db.workoutPlanWorkoutTable)
        ..where((l) => l.id.equals(link.id))).go();
    }
    for (final workoutId in wanted.difference(linked)) {
      await _db
          .into(_db.workoutPlanWorkoutTable)
          .insert(
            WorkoutPlanWorkoutTableCompanion(
              planId: Value(plan.id),
              workoutId: Value(workoutId),
              syncStatus: const Value(1),
            ),
          );
    }
  }
}
