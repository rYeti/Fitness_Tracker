part of 'sync_service.dart';

/// Scheduled workouts (sessions), their exercises, and the sets logged in them.
extension SessionSync on SyncService {
  Future<void> syncScheduledWorkouts() async {
    final unsynced = await _db.workoutDao.getUnsyncedScheduledWorkouts();
    _logger.i('syncScheduledWorkouts: ${unsynced.length} unsynced rows');
    if (unsynced.isEmpty) return;

    for (final sw in unsynced) {
      try {
        switch (SyncStatus.fromDb(sw.syncStatus)) {
          case SyncStatus.pending:
            await _syncNewScheduledWorkout(sw);
          case SyncStatus.pendingUpdate:
            await _syncUpdateScheduledWorkout(sw);
          case SyncStatus.pendingDelete:
            await _syncDeleteScheduledWorkout(sw);
          case SyncStatus.synced || SyncStatus.retired:
            break;
        }
      } catch (e) {
        _logger.w('ScheduledWorkout sync failed for local ${sw.id}: $e');
      }
    }
  }

  Future<void> _syncNewScheduledWorkout(ScheduledWorkoutTableData sw) async {
    // Resolve server IDs for the referenced workout and plan.
    final workoutRow =
        await ((_db.select(_db.workoutTable))
          ..where((w) => w.id.equals(sw.workoutId))).getSingleOrNull();
    if (workoutRow?.serverId == null) return; // workout not synced yet

    String? planServerId;
    if (sw.workoutPlanId != null) {
      final planRow =
          await ((_db.select(_db.workoutPlanTable))
            ..where((p) => p.id.equals(sw.workoutPlanId!))).getSingleOrNull();
      planServerId = planRow?.serverId;
    }

    String? templateWorkoutServerId;
    if (sw.templateWorkoutId != null) {
      final templateRow =
          await ((_db.select(_db.workoutTable))..where(
            (w) => w.id.equals(sw.templateWorkoutId!),
          )).getSingleOrNull();
      templateWorkoutServerId = templateRow?.serverId;
    }

    final response = await _apiClient.post(
      'api/ScheduledWorkout',
      data: {
        'workoutId': workoutRow!.serverId,
        'workoutPlanId': planServerId,
        'templateWorkoutId': templateWorkoutServerId,
        'scheduledDate': sw.scheduledDate.toUtc().toIso8601String(),
        'notes': sw.notes,
        'isCompleted': sw.isCompleted,
        'isSkipped': sw.isSkipped,
      },
    );
    final swServerId = response.data['id'] as String;
    await _markSent(_db.scheduledWorkoutTable, sw.id, swServerId, sw.localRev);

    // The API returns the scheduled workout exercises in the response.
    // Store their server IDs so we can push sets against them.
    final serverExercises =
        (response.data['exercises'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
    await _storeScheduledExerciseServerIds(sw.id, swServerId, serverExercises);

    // Push unsynced workout sets.
    await _syncSetsForScheduledWorkout(sw.id, swServerId);
    _logger.i('Synced new scheduled workout ${sw.id} → server $swServerId');
  }

  Future<void> _syncUpdateScheduledWorkout(ScheduledWorkoutTableData sw) async {
    if (sw.serverId == null) {
      await _syncNewScheduledWorkout(sw);
      return;
    }

    final workoutRow =
        await ((_db.select(_db.workoutTable))
          ..where((w) => w.id.equals(sw.workoutId))).getSingleOrNull();
    if (workoutRow?.serverId == null) {
      _logger.w(
        '_syncUpdateScheduledWorkout: SW ${sw.id} skipped — workout ${sw.workoutId} has no serverId (workout not yet synced)',
      );
      return;
    }

    String? planServerId;
    if (sw.workoutPlanId != null) {
      final planRow =
          await ((_db.select(_db.workoutPlanTable))
            ..where((p) => p.id.equals(sw.workoutPlanId!))).getSingleOrNull();
      planServerId = planRow?.serverId;
    }

    String? templateWorkoutServerId;
    if (sw.templateWorkoutId != null) {
      final templateRow =
          await ((_db.select(_db.workoutTable))..where(
            (w) => w.id.equals(sw.templateWorkoutId!),
          )).getSingleOrNull();
      templateWorkoutServerId = templateRow?.serverId;
    }

    await _apiClient.put(
      'api/ScheduledWorkout/${sw.serverId}',
      data: {
        'workoutId': workoutRow!.serverId,
        'workoutPlanId': planServerId,
        'templateWorkoutId': templateWorkoutServerId,
        'scheduledDate': sw.scheduledDate.toUtc().toIso8601String(),
        'notes': sw.notes,
        'isCompleted': sw.isCompleted,
        'isSkipped': sw.isSkipped,
      },
    );
    await _markSent(
      _db.scheduledWorkoutTable,
      sw.id,
      sw.serverId!,
      sw.localRev,
    );
    await _syncSetsForScheduledWorkout(sw.id, sw.serverId!);
    _logger.i('Updated scheduled workout ${sw.id} on server ${sw.serverId}');
  }

  Future<void> _syncDeleteScheduledWorkout(ScheduledWorkoutTableData sw) async {
    if (sw.serverId != null) {
      try {
        await _apiClient.delete('api/ScheduledWorkout/${sw.serverId}');
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) rethrow;
      }
    }
    // Its exercises and their sets by hand: foreign keys aren't enforced on
    // this database, so deleting the session alone left both behind.
    await _db.untracked(() => _deleteScheduledWorkoutLocally(sw.id));
    _logger.i('Deleted scheduled workout ${sw.id} (server ${sw.serverId})');
  }

  Future<void> _deleteScheduledWorkoutLocally(int swId) async {
    final exercises = await _db.scheduledWorkoutExerciseDao
        .getAllForScheduledWorkout(swId);
    for (final ex in exercises) {
      await (_db.delete(_db.workoutSetTable)
        ..where((t) => t.scheduledWorkoutExerciseId.equals(ex.id))).go();
    }
    await (_db.delete(_db.scheduledWorkoutExerciseTable)
      ..where((t) => t.scheduledWorkoutId.equals(swId))).go();
    await (_db.delete(_db.scheduledWorkoutTable)
      ..where((t) => t.id.equals(swId))).go();
  }

  /// Matches server exercise IDs back to the local [ScheduledWorkoutExerciseTable]
  /// rows of one session that have none yet, by the workout exercise each one
  /// performs.
  ///
  /// Already-linked rows are left alone: relinking one reset its status from
  /// a notes comparison, which quietly marked an exercise with unsent sets as
  /// synced.
  Future<void> _storeScheduledExerciseServerIds(
    int localSwId,
    String swServerId,
    List<Map<String, dynamic>> serverExercises,
  ) async {
    final localExercises = (await _db.scheduledWorkoutExerciseDao
            .getAllForScheduledWorkout(localSwId))
        .where((e) => e.serverId == null);

    for (final localEx in localExercises) {
      // Look up the server UUID of this exercise's workout exercise template.
      final weRow =
          await ((_db.select(_db.workoutExerciseTable))..where(
            (we) => we.id.equals(localEx.workoutExerciseId),
          )).getSingleOrNull();
      if (weRow?.serverId == null) continue;

      // Find the matching server exercise by its workoutExerciseId.
      final serverEx = serverExercises.cast<Map<String, dynamic>>().firstWhere(
        (s) => s['workoutExerciseId'] == weRow!.serverId,
        orElse: () => {},
      );
      if (serverEx.isEmpty) continue;

      final serverExId = serverEx['id'] as String?;
      if (serverExId != null) {
        await _db.scheduledWorkoutExerciseDao.linkScheduledExerciseToServer(
          localEx.id,
          serverExId,
          serverNotes: serverEx['notes'] as String?,
        );
      }
    }
  }

  /// Pushes what changed on each exercise of one session: the client's note
  /// on it, and its logged sets.
  ///
  /// The sets are an owned list. The endpoint replaces an exercise's whole
  /// log, and the active workout rewrites the log as fresh rows on every save,
  /// so any change to any set — a new one, an edited one, a deleted one — is
  /// sent as the complete log. The database marks the exercise itself dirty on
  /// each of those (`sync_triggers.dart`), which is how a deleted set, which
  /// leaves no row behind to find, is still noticed. Sets that are unsent from
  /// before the database tracked changes (the schema-40 backfill) count too.
  ///
  /// An exercise whose whole log was deleted sends nothing: the endpoint treats
  /// an empty batch as a no-op, so the server keeps its last copy.
  Future<void> _syncSetsForScheduledWorkout(
    int localSwId,
    String swServerId,
  ) async {
    final localExercises = await _db.scheduledWorkoutExerciseDao
        .getAllForScheduledWorkout(localSwId);

    for (final localEx in localExercises) {
      if (localEx.serverId == null) {
        _logger.w(
          '_syncSetsForScheduledWorkout: skipping exercise ${localEx.id} (workoutExerciseId=${localEx.workoutExerciseId}) — no serverId',
        );
        continue;
      }
      final dirty =
          SyncStatus.fromDb(localEx.syncStatus) == SyncStatus.pendingUpdate;
      final sets = await _db.workoutDao.getSetsForScheduledExercise(localEx.id);
      final live =
          sets
              .where(
                (s) => SyncStatus.fromDb(s.syncStatus) != SyncStatus.pendingDelete,
              )
              .toList();
      if (!dirty && sets.every((s) => s.syncStatus == SyncStatus.synced.index)) {
        continue;
      }

      try {
        if (dirty) {
          await _apiClient.put(
            'api/ScheduledWorkout/exercises/${localEx.serverId}/notes',
            data: {'notes': localEx.notes},
          );
        }
        if (live.isNotEmpty) {
          await _syncNewWorkoutSetsBatch(live, swServerId, localEx.serverId!);
        }
        // The replace already removed anything this device meant to delete.
        await _db.untracked(
          () =>
              (_db.delete(_db.workoutSetTable)..where(
                    (t) =>
                        t.scheduledWorkoutExerciseId.equals(localEx.id) &
                        t.syncStatus.equals(SyncStatus.pendingDelete.index),
                  ))
                  .go(),
        );
        await _markSent(
          _db.scheduledWorkoutExerciseTable,
          localEx.id,
          localEx.serverId!,
          localEx.localRev,
        );
      } catch (e) {
        _logger.w('Set sync failed for exercise ${localEx.id}: $e');
      }
    }
  }

  Future<void> _syncNewWorkoutSetsBatch(
    List<WorkoutSetTableData> sets,
    String swServerId,
    String scheduledExerciseServerId,
  ) async {
    final response = await _apiClient.post(
      'api/ScheduledWorkout/$swServerId/exercises/$scheduledExerciseServerId/sets/batch',
      data:
          sets
              .map(
                (s) => {
                  'setNumber': s.setNumber,
                  'reps': s.reps,
                  'weight': s.weight,
                  'weightUnit': s.weightUnit,
                  'durationSeconds': s.durationSeconds,
                  'rpe': s.rpe,
                  'setType': s.setType,
                  'side': s.side,
                  'isCompleted': s.isCompleted,
                  'notes': s.notes,
                },
              )
              .toList(),
    );
    final serverList = (response.data as List).cast<Map<String, dynamic>>();
    for (var i = 0; i < sets.length && i < serverList.length; i++) {
      await _db.workoutDao.markWorkoutSetSynced(
        sets[i].id,
        serverList[i]['id'] as String,
      );
    }
    _logger.i(
      '_syncNewWorkoutSetsBatch: pushed ${serverList.length} sets to SW $swServerId / exercise $scheduledExerciseServerId',
    );
  }

  /// For every synced scheduled workout, ensures local scheduled exercise
  /// serverIds are stamped (by fetching the SW from the server), then pushes
  /// any pending sets.  Never creates duplicate exercises: exercises are
  /// auto-created server-side when the SW is POSTed, so we only need to store
  /// their IDs — not create new ones.
  Future<void> _syncMissingScheduledExerciseSets() async {
    // Only the sessions with something to send — see _syncWorkoutExercises.
    final ids =
        (await _db.customSelect('''
      SELECT DISTINCT sw.id FROM scheduled_workout_table sw
      JOIN scheduled_workout_exercise_table se ON se.scheduled_workout_id = sw.id
      LEFT JOIN workout_set_table s ON s.scheduled_workout_exercise_id = se.id
      WHERE sw.server_id IS NOT NULL AND (
        se.server_id IS NULL OR se.sync_status = 2 OR s.sync_status IN (0, 2, 3)
      )
    ''').get()).map((r) => r.read<int>('id')).toList();
    if (ids.isEmpty) return;
    final syncedSws =
        await (_db.select(_db.scheduledWorkoutTable)
          ..where((sw) => sw.id.isIn(ids))).get();

    _logger.i(
      '_syncMissingScheduledExerciseSets: checking ${syncedSws.length} synced SWs',
    );
    for (final sw in syncedSws) {
      // Outside the try: a lease lost mid-push must stop the push, not be
      // logged as one item's failure.
      await SyncLease.current?.renew();
      try {
        final localExercises = await _db.scheduledWorkoutExerciseDao
            .getAllForScheduledWorkout(sw.id);
        final missingServerId =
            localExercises.where((e) => e.serverId == null).toList();
        if (missingServerId.isNotEmpty) {
          _logger.w(
            '_syncMissingScheduledExerciseSets: SW ${sw.id} has ${missingServerId.length} exercises with no serverId — fetching from server',
          );
          // Fetch the existing scheduled workout from the server to get the
          // server-assigned exercise IDs.  The server auto-creates exercises
          // when the SW is POSTed, so they should already exist — we must NOT
          // POST again or we will create duplicates.
          final swResponse = await _apiClient.get(
            'api/ScheduledWorkout/${sw.serverId}',
          );
          final serverExercises =
              (swResponse.data['exercises'] as List? ?? [])
                  .cast<Map<String, dynamic>>();

          await _storeScheduledExerciseServerIds(
            sw.id,
            sw.serverId!,
            serverExercises,
          );

          // After stamping from the server, check if any are genuinely absent
          // (e.g. workout template changed after SW was created on server).
          final stillMissing =
              (await _db.scheduledWorkoutExerciseDao.getAllForScheduledWorkout(
                sw.id,
              )).where((e) => e.serverId == null).toList();

          if (stillMissing.isNotEmpty) {
            final weServerIds = <String>[];
            final valid = <ScheduledWorkoutExerciseTableData>[];
            for (final localEx in stillMissing) {
              final weRow =
                  await (_db.select(_db.workoutExerciseTable)..where(
                    (we) => we.id.equals(localEx.workoutExerciseId),
                  )).getSingleOrNull();
              if (weRow?.serverId == null) continue;
              weServerIds.add(weRow!.serverId!);
              valid.add(localEx);
            }
            if (weServerIds.isNotEmpty) {
              final response = await _apiClient.post(
                'api/ScheduledWorkout/${sw.serverId}/exercises/batch',
                data: weServerIds,
              );
              // Matched on the workout exercise each entry performs, not on
              // position: the endpoint answers with *every* entry the session
              // now has, in no promised order, so pairing by index linked
              // entries to the wrong exercise and their sets were then pushed
              // under it.
              await _storeScheduledExerciseServerIds(
                sw.id,
                sw.serverId!,
                (response.data as List).cast<Map<String, dynamic>>(),
              );
            }
          }
        }

        // Push any sets that still have no serverId.
        await _syncSetsForScheduledWorkout(sw.id, sw.serverId!);
      } catch (e) {
        _logger.w(
          '_syncMissingScheduledExerciseSets failed for sw ${sw.id}: $e',
        );
      }
    }
  }

  /// Re-fetches each synced scheduled workout from the server and stores
  /// exercise serverIds for any local scheduled exercise that still has none.
  /// This fixes the case where `_pullWorkouts` skipped some workout exercises
  /// (missing exercise serverId), so `_pullScheduledWorkouts` couldn't link them.
  Future<void> _relinkMissingScheduledExercises() async {
    final syncedSws =
        await (_db.select(_db.scheduledWorkoutTable)
          ..where((sw) => sw.serverId.isNotNull())).get();

    for (final sw in syncedSws) {
      try {
        final exercises = await _db.scheduledWorkoutExerciseDao
            .getAllForScheduledWorkout(sw.id);
        if (exercises.any((e) => e.serverId == null)) {
          final response = await _apiClient.get(
            'api/ScheduledWorkout/${sw.serverId}',
          );
          final serverExercises =
              (response.data['exercises'] as List? ?? [])
                  .cast<Map<String, dynamic>>();
          await _storeScheduledExerciseServerIds(
            sw.id,
            sw.serverId!,
            serverExercises,
          );
        }
      } catch (e) {
        _logger.w(
          '_relinkMissingScheduledExercises failed for sw ${sw.id}: $e',
        );
      }
    }
  }

  Future<void> _pullScheduledWorkouts() async {
    final response = await _apiClient.get('api/ScheduledWorkout');
    final list = (response.data as List).cast<Map<String, dynamic>>();
    await _applyEach('sessions', list, _applyServerScheduledWorkout);

    await _removeDeletedElsewhere<ScheduledWorkoutTableData>(
      what: 'sessions',
      serverIds: {for (final sw in list) sw['id'] as String},
      locals:
          await (_db.select(_db.scheduledWorkoutTable)
            ..where((t) => t.serverId.isNotNull())).get(),
      serverIdOf: (r) => r.serverId!,
      syncStatusOf: (r) => r.syncStatus,
      // Sessions are only ever deleted on purpose — a user removing one on
      // another device, or a workout deleted with its unlogged placeholders.
      // Anything this device logged and hasn't sent yet stays.
      delete: (r) async {
        final exercises = await _db.scheduledWorkoutExerciseDao
            .getAllForScheduledWorkout(r.id);
        for (final ex in exercises) {
          if (SyncStatus.fromDb(ex.syncStatus).isDirty) return false;
          final sets = await _db.workoutDao.getSetsForScheduledExercise(ex.id);
          if (sets.any((s) => SyncStatus.fromDb(s.syncStatus).isDirty)) {
            return false;
          }
        }
        await _deleteScheduledWorkoutLocally(r.id);
        return true;
      },
    );
  }

  Future<void> _applyServerScheduledWorkout(Map<String, dynamic> sw) async {
    final swServerId = sw['id'] as String;
    final localWorkout = await _db.workoutDao.getWorkoutByServerId(
      sw['workoutId'] as String,
    );
    if (localWorkout == null) return;

    // Resolve (or create) the local scheduled workout row.
    int localSwId;
    final existingBySid = await _db.scheduledWorkoutDao.getByServerId(
      swServerId,
    );
    if (existingBySid != null) {
      localSwId = existingBySid.id;
      // Always update mutable server-authoritative fields so completions/skips
      // made on other devices are reflected locally.
      if (existingBySid.syncStatus == 1) {
        await (_db.update(_db.scheduledWorkoutTable)
          ..where((t) => t.id.equals(localSwId))).write(
          ScheduledWorkoutTableCompanion(
            isCompleted: Value(sw['isCompleted'] as bool),
            isSkipped: Value(sw['isSkipped'] as bool),
            notes: Value(sw['notes'] as String?),
          ),
        );
      }
    } else {
      // Convert to local time for comparison — locally stored dates use local midnight.
      final scheduledDate =
          DateTime.parse(sw['scheduledDate'] as String).toLocal();
      final dateStart = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
      );
      final dateEnd = dateStart.add(const Duration(days: 1));
      final existingByContent =
          await (_db.select(_db.scheduledWorkoutTable)
                ..where(
                  (t) =>
                      t.workoutId.equals(localWorkout.id) &
                      t.scheduledDate.isBiggerOrEqualValue(dateStart) &
                      t.scheduledDate.isSmallerThanValue(dateEnd),
                )
                ..limit(1))
              .getSingleOrNull();

      if (existingByContent != null) {
        // If it already has a different serverId, this is a server-side duplicate — skip entirely.
        if (existingByContent.serverId != null &&
            existingByContent.serverId != swServerId) {
          return;
        }
        localSwId = existingByContent.id;
        final companion =
            existingByContent.serverId == null
                ? ScheduledWorkoutTableCompanion(
                  serverId: Value(swServerId),
                  syncStatus: const Value(1),
                  isCompleted: Value(sw['isCompleted'] as bool),
                  isSkipped: Value(sw['isSkipped'] as bool),
                  notes: Value(sw['notes'] as String?),
                )
                : ScheduledWorkoutTableCompanion(
                  isCompleted: Value(sw['isCompleted'] as bool),
                  isSkipped: Value(sw['isSkipped'] as bool),
                  notes: Value(sw['notes'] as String?),
                );
        await (_db.update(_db.scheduledWorkoutTable)
          ..where((t) => t.id.equals(existingByContent.id))).write(companion);
      } else {
        int? localPlanId;
        if (sw['workoutPlanId'] != null) {
          localPlanId =
              (await _db.workoutPlanDao.getPlanByServerId(
                sw['workoutPlanId'] as String,
              ))?.id;
        }
        int? localTemplateId;
        if (sw['templateWorkoutId'] != null) {
          localTemplateId =
              (await _db.workoutDao.getWorkoutByServerId(
                sw['templateWorkoutId'] as String,
              ))?.id;
        }
        localSwId = await _db.scheduledWorkoutDao.scheduleWorkout(
          ScheduledWorkoutTableCompanion(
            workoutId: Value(localWorkout.id),
            scheduledDate: Value(scheduledDate),
            createdAt: Value(DateTime.parse(sw['createdAt'] as String)),
            notes: Value(sw['notes'] as String?),
            isCompleted: Value(sw['isCompleted'] as bool),
            isSkipped: Value(sw['isSkipped'] as bool),
            workoutPlanId: Value(localPlanId),
            templateWorkoutId: Value(localTemplateId),
            serverId: Value(swServerId),
            syncStatus: const Value(1),
          ),
        );
      }
    }

    // Always sync exercises and sets — fill in anything missing locally.
    for (final se in (sw['exercises'] as List).cast<Map<String, dynamic>>()) {
      final seServerId = se['id'] as String;

      final existingSe = await _db.scheduledWorkoutExerciseDao.getByServerId(
        seServerId,
      );
      int localSeId;
      if (existingSe != null) {
        localSeId = existingSe.id;
        await _relinkOrphanedScheduledExercise(
          existingSe,
          se['workoutExerciseId'] as String,
        );
        // Only a clean local copy is reconciled; a pending one is the push's.
        final serverNotes = se['notes'] as String?;
        final serverHasNote =
            serverNotes != null && serverNotes.trim().isNotEmpty;
        final localHasNote =
            existingSe.notes != null && existingSe.notes!.trim().isNotEmpty;
        if (existingSe.syncStatus == 1 && existingSe.notes != serverNotes) {
          await (_db.update(_db.scheduledWorkoutExerciseTable)
            ..where((t) => t.id.equals(localSeId))).write(
            serverHasNote || !localHasNote
                // Written on another device.
                ? ScheduledWorkoutExerciseTableCompanion(
                  notes: Value(serverNotes),
                )
                // A note here and none on the server is a note that never
                // left: until notes were pushed at all, every one written
                // was stamped synced without being sent. Clearing it to
                // match the server would delete it; queue it instead.
                : const ScheduledWorkoutExerciseTableCompanion(
                  syncStatus: Value(2),
                ),
          );
        }
      } else {
        final localWe = await _db.workoutDao.getWorkoutExerciseByServerId(
          se['workoutExerciseId'] as String,
        );
        if (localWe == null) {
          _logger.w(
            'Pull SW $swServerId: skipping exercise $seServerId — no local workout exercise for ${se['workoutExerciseId']}',
          );
          continue;
        }

        // If a local entry for this session and this workout exercise already
        // exists without a serverId, stamp it rather than inserting a second
        // one. The scheduled workout above and the sets below both have this
        // fallback; without it here, every locally-created-but-unstamped
        // entry got a twin on pull — and the content de-duplication pass then
        // kept the *older* of the two, dropping the row that had just been
        // linked and setting the whole cycle up to repeat.
        final unlinkedSe =
            await (_db.select(_db.scheduledWorkoutExerciseTable)
                  ..where(
                    (t) =>
                        t.scheduledWorkoutId.equals(localSwId) &
                        t.workoutExerciseId.equals(localWe.id) &
                        t.serverId.isNull(),
                  )
                  ..limit(1))
                .getSingleOrNull();

        if (unlinkedSe != null) {
          localSeId = unlinkedSe.id;
          await _db.scheduledWorkoutExerciseDao.linkScheduledExerciseToServer(
            localSeId,
            seServerId,
            serverNotes: se['notes'] as String?,
          );
          _logger.i(
            'Pull SW $swServerId: re-linked local exercise $localSeId to server $seServerId',
          );
        } else {
          localSeId = await _db
              .into(_db.scheduledWorkoutExerciseTable)
              .insert(
                ScheduledWorkoutExerciseTableCompanion(
                  scheduledWorkoutId: Value(localSwId),
                  workoutExerciseId: Value(localWe.id),
                  isCompleted: Value(se['isCompleted'] as bool),
                  notes: Value(se['notes'] as String?),
                  serverId: Value(seServerId),
                  syncStatus: const Value(1),
                ),
              );
        }
      }

      await _reconcileLoggedSets(
        localSeId,
        (se['sets'] as List).cast<Map<String, dynamic>>(),
      );
    }
    _logger.i('Pulled scheduled workout $swServerId');
  }

  /// Repoints a session exercise whose workout exercise no longer exists on
  /// this device at the row the server says it performed.
  ///
  /// Before the push retired a removed exercise instead of deleting it, the
  /// device that removed one kept the session entries that referred to it but
  /// lost the row they referred to. Foreign keys aren't enforced here, so
  /// nothing stopped that, and every screen that inner-joins the two dropped
  /// those entries — the lift's history vanished from the device that logged
  /// it. The server kept the exercise (as `removedAt`) and the pull recreates
  /// it under a new local id; this is what reattaches the orphans to it.
  Future<void> _relinkOrphanedScheduledExercise(
    ScheduledWorkoutExerciseTableData local,
    String workoutExerciseServerId,
  ) async {
    final current =
        await (_db.select(_db.workoutExerciseTable)
          ..where((we) => we.id.equals(local.workoutExerciseId))).getSingleOrNull();
    if (current != null) return;
    final target = await _db.workoutDao.getWorkoutExerciseByServerId(
      workoutExerciseServerId,
    );
    if (target == null) return;
    await (_db.update(_db.scheduledWorkoutExerciseTable)
      ..where((t) => t.id.equals(local.id))).write(
      ScheduledWorkoutExerciseTableCompanion(workoutExerciseId: Value(target.id)),
    );
    _logger.i(
      'Pull: reattached session exercise ${local.id} to workout exercise '
      '${target.id} (its old one was gone)',
    );
  }

  /// A set type ordinal from the server, clamped to one this build knows.
  /// The stored ordinal is later read as `SetType.values[i]`, which throws on
  /// a value a newer server or app added — so an unknown one reads as normal
  /// rather than crashing every screen that lists the set.
  static int _setTypeOrdinal(Object? raw) =>
      raw is int && raw >= 0 && raw < SetType.values.length ? raw : 0;

  /// A side ordinal from the server; unknown reads as both. See
  /// [_setTypeOrdinal].
  static int _setSideOrdinal(Object? raw) =>
      raw is int && raw >= 0 && raw < SetSide.values.length ? raw : 0;

  /// Brings one scheduled exercise's logged sets in line with the server's.
  ///
  /// Decided per exercise, not per set. This used to insert every server set
  /// whose id the device didn't know — and the server held many it didn't: the
  /// sets batch appended, and the active workout rewrites an exercise's sets
  /// as fresh rows on every save, so each save that followed a push left
  /// another copy of the exercise on the server. The pull then carried every
  /// stale copy back onto the device beside the real rows. See
  /// docs/sync-concurrent-runs.md.
  ///
  /// | Local log                              | Action                         |
  /// |----------------------------------------|--------------------------------|
  /// | holds an unpushed set                  | leave it — the push replaces   |
  /// | empty                                  | insert the server's            |
  /// | every id still on the server, + extras | re-queue it to overwrite them  |
  /// | an id the server no longer has         | take the server's              |
  ///
  /// The third row is the server holding stale copies next to what this
  /// device pushed last. The device's rows are the ones it wrote, so they are
  /// re-queued and the replace push clears the copies — which is what fixes a
  /// session the Trainer Console shows twice over. The fourth is another
  /// device having replaced the log since; a replace always mints fresh ids.
  ///
  /// Server sets are folded to one per set number on the way in: set numbers
  /// are ordinals, and the active workout keys every input on them.
  Future<void> _reconcileLoggedSets(
    int localSeId,
    List<Map<String, dynamic>> serverSets,
  ) => _db.transaction(() async {
    // An exercise marked dirty holds a change to its log the push hasn't sent
    // — a deleted set leaves no row behind to find below, only this mark.
    final exercise =
        await (_db.select(_db.scheduledWorkoutExerciseTable)
          ..where((t) => t.id.equals(localSeId))).getSingleOrNull();
    if (exercise != null &&
        SyncStatus.fromDb(exercise.syncStatus) == SyncStatus.pendingUpdate) {
      return;
    }
    final local =
        await (_db.select(_db.workoutSetTable)..where(
              (t) => t.scheduledWorkoutExerciseId.equals(localSeId),
            ))
            .get();
    if (local.any((s) => s.syncStatus != 1)) return;

    final serverIds = {for (final s in serverSets) s['id'] as String};
    if (local.isNotEmpty) {
      if (local.every((s) => serverIds.contains(s.serverId))) {
        if (serverIds.length > local.length) {
          await (_db.update(_db.workoutSetTable)..where(
                (t) => t.scheduledWorkoutExerciseId.equals(localSeId),
              ))
              .write(
                const WorkoutSetTableCompanion(
                  serverId: Value(null),
                  syncStatus: Value(0),
                ),
              );
          _logger.i(
            'Pull: server holds ${serverIds.length - local.length} stale '
            'set(s) for scheduled exercise $localSeId — re-queued the local log',
          );
        }
        return;
      }
      await (_db.delete(_db.workoutSetTable)..where(
            (t) => t.scheduledWorkoutExerciseId.equals(localSeId),
          ))
          .go();
    }

    final seen = <int>{};
    for (final s in serverSets) {
      if (!seen.add(s['setNumber'] as int)) continue;
      await _db
          .into(_db.workoutSetTable)
          .insert(
            WorkoutSetTableCompanion(
              scheduledWorkoutExerciseId: Value(localSeId),
              setNumber: Value(s['setNumber'] as int),
              reps: Value(s['reps'] as int?),
              weight: Value((s['weight'] as num?)?.toDouble()),
              weightUnit: Value(s['weightUnit'] as String?),
              durationSeconds: Value(s['durationSeconds'] as int?),
              rpe: Value(s['rpe'] as int?),
              setType: Value(_setTypeOrdinal(s['setType'])),
              side: Value(_setSideOrdinal(s['side'])),
              isCompleted: Value(s['isCompleted'] as bool),
              notes: Value(s['notes'] as String?),
              serverId: Value(s['id'] as String),
              syncStatus: const Value(1),
            ),
          );
    }
  });
}
