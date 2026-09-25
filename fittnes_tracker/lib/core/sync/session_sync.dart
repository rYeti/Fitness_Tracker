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

  /// What a session's create and update send, or null while a row it refers
  /// to — its workout, its plan, the workout it was generated from — is on
  /// this device but not on the server yet. The session then waits, dirty,
  /// for a push after that row's.
  ///
  /// It used to wait only for its workout (a foreign key the server would
  /// refuse) and send null for a plan it couldn't name yet. The server took
  /// the null at its word: the session was stored with no plan, marked sent,
  /// and never sent again, and an update to a session it already had cleared
  /// the plan it held. `pending` doesn't even mean the server lacks the plan —
  /// only that this device hasn't heard back. A reference that can't be sent
  /// yet defers the row; it never goes as null. A plan or template gone from
  /// this device altogether does go as null: there is nothing to wait for.
  Future<Map<String, dynamic>?> _scheduledWorkoutBody(
    ScheduledWorkoutTableData sw,
  ) async {
    final workoutRow =
        await ((_db.select(_db.workoutTable))
          ..where((w) => w.id.equals(sw.workoutId))).getSingleOrNull();
    final workoutServerId =
        workoutRow == null
            ? null
            : SyncService._serverIdIfPushed(
              workoutRow.serverId,
              workoutRow.syncStatus,
            );
    if (workoutServerId == null) return null;

    String? planServerId;
    if (sw.workoutPlanId != null) {
      final planRow =
          await ((_db.select(_db.workoutPlanTable))
            ..where((p) => p.id.equals(sw.workoutPlanId!))).getSingleOrNull();
      if (planRow != null) {
        planServerId = SyncService._serverIdIfPushed(
          planRow.serverId,
          planRow.syncStatus,
        );
        if (planServerId == null) return null;
      }
    }

    String? templateWorkoutServerId;
    if (sw.templateWorkoutId != null) {
      final templateRow =
          await ((_db.select(_db.workoutTable))..where(
            (w) => w.id.equals(sw.templateWorkoutId!),
          )).getSingleOrNull();
      if (templateRow != null) {
        templateWorkoutServerId = SyncService._serverIdIfPushed(
          templateRow.serverId,
          templateRow.syncStatus,
        );
        if (templateWorkoutServerId == null) return null;
      }
    }

    return {
      'workoutId': workoutServerId,
      'workoutPlanId': planServerId,
      'templateWorkoutId': templateWorkoutServerId,
      'scheduledDate': sw.scheduledDate.toUtc().toIso8601String(),
      'notes': sw.notes,
      'isCompleted': sw.isCompleted,
      'isSkipped': sw.isSkipped,
    };
  }

  Future<void> _syncNewScheduledWorkout(ScheduledWorkoutTableData sw) async {
    final body = await _scheduledWorkoutBody(sw);
    if (body == null) return; // a row it refers to isn't on the server yet

    final response = await _create(
      'api/ScheduledWorkout',
      {'id': sw.serverId, ...body},
      _db.scheduledWorkoutTable,
      [sw.id],
    );
    if (response == null) return;
    // Usually the id sent. A session the server already holds for the same
    // workout on the same day — another device's — comes back under its own
    // id, and this row becomes that session. The server returned that session
    // as it was, without this device's completion, skip or notes, so it stays
    // `pendingUpdate` and the next push PUTs them; marked clean, the next pull
    // would have put the server's values over them — a workout finished here
    // shown as not done.
    final swServerId = response.data['id'] as String;
    await _markSent(
      _db.scheduledWorkoutTable,
      sw.id,
      swServerId,
      swServerId == sw.serverId ? sw.localRev : -1,
    );

    // The server creates a session's exercises itself, one per exercise of
    // the workout, and returns them: link this device's to them by the
    // workout exercise each performs. Any left over are created by
    // _syncSessionExercises, which also pushes the sets.
    //
    // These are the one answer paired by content rather than by the id sent:
    // nothing was sent for them. The server made them from the workout, one
    // per workout exercise, and (session, workout exercise) is the key it
    // made them on — two ids, not a position or a name.
    final serverExercises =
        (response.data['exercises'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
    await _storeScheduledExerciseServerIds(sw.id, swServerId, serverExercises);

    await _syncSetsForScheduledWorkout(sw.id, swServerId);
    _logger.i('Synced new scheduled workout ${sw.id} → server $swServerId');
  }

  Future<void> _syncUpdateScheduledWorkout(ScheduledWorkoutTableData sw) async {
    if (sw.serverId == null) {
      await _syncNewScheduledWorkout(sw);
      return;
    }

    final body = await _scheduledWorkoutBody(sw);
    if (body == null) {
      _logger.w(
        '_syncUpdateScheduledWorkout: SW ${sw.id} skipped — a row it refers '
        'to is not on the server yet',
      );
      return;
    }

    await _apiClient.put('api/ScheduledWorkout/${sw.serverId}', data: body);
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

  /// Links the local [ScheduledWorkoutExerciseTable] rows of one session that
  /// the server doesn't have yet to the server's, by the workout exercise each
  /// one performs — one entry per workout exercise per session is the key the
  /// server's session create and its exercise batch are both idempotent on.
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
        .where((e) => !SyncStatus.fromDb(e.syncStatus).isOnServer);

    for (final localEx in localExercises) {
      final weServerId = await _workoutExerciseServerId(
        localEx.workoutExerciseId,
      );
      if (weServerId == null) continue;

      // Find the matching server exercise by its workoutExerciseId.
      final serverEx = serverExercises.cast<Map<String, dynamic>>().firstWhere(
        (s) => s['workoutExerciseId'] == weServerId,
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

  /// Links the session exercises in [sentLocalIds] to the entries a batch
  /// answered them with, by the id each was sent with (`requestedId`).
  ///
  /// Not by the workout exercise each performs, and never by position: the
  /// answer names the item it answers, so nothing has to be inferred. One the
  /// answer doesn't name — its workout exercise isn't this account's — stays
  /// pending. The link keeps the row dirty if its note differs from the
  /// entry's (`linkScheduledExerciseToServer`), which is what sends this
  /// device's note to an entry the server already held.
  Future<void> _linkAnsweredScheduledExercises(
    List<int> sentLocalIds,
    List<Map<String, dynamic>> answer,
  ) async {
    final byRequested = {
      for (final s in answer)
        if (s['requestedId'] != null) s['requestedId'] as String: s,
    };
    for (final localId in sentLocalIds) {
      final local =
          await (_db.select(_db.scheduledWorkoutExerciseTable)
            ..where((t) => t.id.equals(localId))).getSingleOrNull();
      final entry = local == null ? null : byRequested[local.serverId];
      if (entry == null) continue;
      await _db.scheduledWorkoutExerciseDao.linkScheduledExerciseToServer(
        localId,
        entry['id'] as String,
        serverNotes: entry['notes'] as String?,
      );
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
      if (!SyncStatus.fromDb(localEx.syncStatus).isOnServer) {
        _logger.w(
          '_syncSetsForScheduledWorkout: skipping exercise ${localEx.id} (workoutExerciseId=${localEx.workoutExerciseId}) — not on the server yet',
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

  /// Sends an exercise's whole log, which the server makes its log. Each set
  /// goes under the id this device minted for it, which the server keeps, so
  /// what comes back is marked by id.
  ///
  /// The server used to mint fresh ids for every set on every replace, and
  /// the answer was paired with the request by position. Both are gone: the
  /// ids this device holds are the ids the server stores.
  Future<void> _syncNewWorkoutSetsBatch(
    List<WorkoutSetTableData> sets,
    String swServerId,
    String scheduledExerciseServerId,
  ) async {
    final Response response;
    try {
      response = await _apiClient.post(
        'api/ScheduledWorkout/$swServerId/exercises/$scheduledExerciseServerId/sets/batch',
        data:
            sets
                .map(
                  (s) => {
                    'id': s.serverId,
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
    } catch (e) {
      if (SyncService._isIdConflict(e)) {
        await _mintNewIds(_db.workoutSetTable, sets.map((s) => s.id));
      }
      rethrow;
    }
    final stored = {
      for (final s in (response.data as List).cast<Map<String, dynamic>>())
        s['id'] as String,
    };
    for (final s in sets) {
      if (stored.contains(s.serverId)) {
        await _db.workoutDao.markWorkoutSetSynced(s.id, s.serverId!);
      }
    }
    _logger.i(
      '_syncNewWorkoutSetsBatch: pushed ${sets.length} sets to SW $swServerId / exercise $scheduledExerciseServerId',
    );
  }

  /// The server id of a workout exercise, if the server has it.
  Future<String?> _workoutExerciseServerId(int localWorkoutExerciseId) async {
    final we =
        await ((_db.select(_db.workoutExerciseTable))
          ..where((t) => t.id.equals(localWorkoutExerciseId))).getSingleOrNull();
    return we == null
        ? null
        : SyncService._serverIdIfPushed(we.serverId, we.syncStatus);
  }

  /// For every session the server has, creates the exercises of it the server
  /// doesn't have yet, then pushes whatever changed in each exercise's log.
  ///
  /// An exercise not on the server yet is sent to the session's exercise batch
  /// under the id this device minted for it. The server answers with every
  /// exercise the session now holds, each one that answers an item carrying
  /// the id that item was sent with (`requestedId`), and this device's rows
  /// are linked by it. The answer's own id can differ: the session may
  /// already have had an entry for that workout exercise — the server makes
  /// one per workout exercise when the session is created — and then that
  /// one is this one; or the id sent was stored elsewhere, and the server
  /// minted another.
  ///
  /// This used to start with a GET of every such session, to find out which of
  /// the device's exercises the server had made while a lost response kept the
  /// device from hearing about it. The batch answers that now, in the same
  /// request that creates what's missing.
  Future<void> _syncSessionExercises() async {
    // Only the sessions with something to send — see _syncWorkoutExercises.
    final ids =
        (await _db.customSelect('''
      SELECT DISTINCT sw.id FROM scheduled_workout_table sw
      JOIN scheduled_workout_exercise_table se ON se.scheduled_workout_id = sw.id
      LEFT JOIN workout_set_table s ON s.scheduled_workout_exercise_id = se.id
      WHERE sw.sync_status NOT IN (0, 3) AND (
        se.sync_status IN (0, 2) OR s.sync_status IN (0, 2, 3)
      )
    ''').get()).map((r) => r.read<int>('id')).toList();
    if (ids.isEmpty) return;
    final syncedSws =
        await (_db.select(_db.scheduledWorkoutTable)
          ..where((sw) => sw.id.isIn(ids))).get();

    for (final sw in syncedSws) {
      // Outside the try: a lease lost mid-push must stop the push, not be
      // logged as one item's failure.
      await SyncLease.current?.renew();
      try {
        final unpushed =
            (await _db.scheduledWorkoutExerciseDao.getAllForScheduledWorkout(
              sw.id,
            )).where((e) => !SyncStatus.fromDb(e.syncStatus).isOnServer);
        final items = <Map<String, dynamic>>[];
        final sent = <int>[];
        for (final localEx in unpushed) {
          final weServerId = await _workoutExerciseServerId(
            localEx.workoutExerciseId,
          );
          if (weServerId == null) continue;
          items.add({'id': localEx.serverId, 'workoutExerciseId': weServerId});
          sent.add(localEx.id);
        }
        if (items.isNotEmpty) {
          final response = await _create(
            'api/ScheduledWorkout/${sw.serverId}/exercises/batch',
            items,
            _db.scheduledWorkoutExerciseTable,
            sent,
          );
          if (response != null) {
            await _linkAnsweredScheduledExercises(
              sent,
              (response.data as List).cast<Map<String, dynamic>>(),
            );
          }
        }

        await _syncSetsForScheduledWorkout(sw.id, sw.serverId!);
      } catch (e) {
        _logger.w('_syncSessionExercises failed for sw ${sw.id}: $e');
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
          await (_db.select(_db.scheduledWorkoutTable)..where(
                (t) =>
                    t.serverId.isNotNull() &
                    t.syncStatus.isNotValue(SyncStatus.pending.index),
              ))
              .get(),
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
        // A session this device made for the same workout and day, not yet
        // pushed, is this one: the server keeps one per workout per day, and
        // would answer its create with this session anyway. One the server
        // already has under another id is a server-side duplicate — skip it.
        if (SyncStatus.fromDb(existingByContent.syncStatus).isOnServer) {
          return;
        }
        localSwId = existingByContent.id;
        await (_db.update(_db.scheduledWorkoutTable)
          ..where((t) => t.id.equals(existingByContent.id))).write(
          ScheduledWorkoutTableCompanion(
            serverId: Value(swServerId),
            syncStatus: const Value(1),
            isCompleted: Value(sw['isCompleted'] as bool),
            isSkipped: Value(sw['isSkipped'] as bool),
            notes: Value(sw['notes'] as String?),
          ),
        );
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

        // If a local entry for this session and this workout exercise exists
        // that the server doesn't have yet, stamp it rather than inserting a
        // second one. The scheduled workout above and the sets below both have this
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
                        t.syncStatus.equals(SyncStatus.pending.index),
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
  /// device having replaced the log since, with rows under its own ids.
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
          // Under the ids they have: the replace keeps them.
          await (_db.update(_db.workoutSetTable)..where(
                (t) => t.scheduledWorkoutExerciseId.equals(localSeId),
              ))
              .write(const WorkoutSetTableCompanion(syncStatus: Value(0)));
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
