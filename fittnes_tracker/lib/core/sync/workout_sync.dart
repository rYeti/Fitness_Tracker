part of 'sync_service.dart';

/// Workouts, their exercise entries and each entry's set templates (its prescription).
extension WorkoutSync on SyncService {
  Future<void> syncWorkoutTemplates() async {
    final unsynced = await _db.workoutDao.getUnsyncedTemplates();
    if (unsynced.isEmpty) return;

    for (final workout in unsynced) {
      try {
        switch (SyncStatus.fromDb(workout.syncStatus)) {
          case SyncStatus.pending:
            await _syncNewWorkout(workout);
          case SyncStatus.pendingUpdate:
            await _syncUpdateWorkout(workout);
          case SyncStatus.pendingDelete:
            await _syncDeleteWorkout(workout);
          case SyncStatus.synced || SyncStatus.retired:
            break;
        }
      } catch (e) {
        _logger.w('Workout sync failed for local ${workout.id}: $e');
      }
    }
  }

  Future<void> _syncNewWorkout(WorkoutTableData w) async {
    final response = await _create(
      'api/Workout',
      {'id': w.serverId, ..._workoutBody(w)},
      _db.workoutTable,
      [w.id],
    );
    if (response == null) return;
    final serverId = response.data['id'] as String;
    await _markSent(_db.workoutTable, w.id, serverId, w.localRev);

    // Its exercises that never reached the server. A removed or retired row
    // is not pending, so one the user took out is never posted back.
    final exercises = await _db.workoutDao.getExercisesForWorkoutRaw(w.id);
    await _syncNewWorkoutExercisesBatch(
      exercises
          .where((e) => !SyncStatus.fromDb(e.syncStatus).isOnServer)
          .toList(),
      serverId,
    );
    _logger.i('Synced new workout ${w.id} → server $serverId');
  }

  Map<String, dynamic> _workoutBody(WorkoutTableData w) => {
    'name': w.name,
    'description': w.description,
    'difficulty': w.difficulty,
    'estimatedDurationMinutes': w.estimatedDurationMinutes,
    'isTemplate': w.isTemplate,
    'scheduledDate': w.scheduledDate?.toUtc().toIso8601String(),
    'color': w.color?.toSigned(32),
  };

  /// Sends the workout row itself. Its exercises are pushed by
  /// [_syncWorkoutExercises] on their own status, not from here: gating them
  /// on the workout's status is how a removed exercise's DELETE came to sit
  /// behind a workout that no longer looked dirty, and was never sent (see
  /// `docs/sync-account-switch-duplication.md` §2).
  Future<void> _syncUpdateWorkout(WorkoutTableData w) async {
    if (w.serverId == null) {
      await _syncNewWorkout(w);
      return;
    }
    await _apiClient.put('api/Workout/${w.serverId}', data: _workoutBody(w));
    await _markSent(_db.workoutTable, w.id, w.serverId!, w.localRev);
    _logger.i('Updated workout ${w.id} on server ${w.serverId}');
  }

  /// Deletes a workout the user removed — unless training history hangs on
  /// it, in which case it is kept and shown again.
  ///
  /// The history check comes first, before the server is asked. A session's
  /// sets are pushed after workouts, so the server may not know about them yet
  /// and would accept a DELETE the device then couldn't carry out. Left like
  /// that, the row stayed hidden and `pendingDelete` for good, re-sending the
  /// DELETE on every push and keeping the sign-out warning up. Keeping it is
  /// the same answer the server gives (409) once it does know, and the same
  /// rule a deleted plan follows (`docs/sync-architecture.md` §12).
  Future<void> _syncDeleteWorkout(WorkoutTableData w) async {
    if (await _db.workoutDao.hasLoggedSessions(w.id)) {
      await _keepWorkoutForHistory(w);
      return;
    }
    if (w.serverId != null) {
      try {
        await _apiClient.delete('api/Workout/${w.serverId}');
      } on DioException catch (e) {
        if (e.response?.statusCode == 409) {
          await _keepWorkoutForHistory(w);
          return;
        }
        if (e.response?.statusCode != 404) rethrow;
      }
    }
    final deleted = await _db.untracked(
      () => _db.workoutDao.deleteWorkout(w.id),
    );
    if (!deleted && await _db.workoutDao.hasLoggedSessions(w.id)) {
      // A set was logged against it between the check above and now — an
      // active workout still open on it. The server copy is gone, so it comes
      // back as a new workout: the history under it has to be pushable. Under
      // the ids it already has — the server deleted those rows, so a create
      // under them makes them afresh.
      await _db.untracked(() async {
        await (_db.update(_db.workoutTable)
          ..where((t) => t.id.equals(w.id))).write(
          WorkoutTableCompanion(syncStatus: Value(SyncStatus.pending.index)),
        );
        final live = (await _db.workoutDao.getExercisesForWorkoutRaw(
          w.id,
        )).where(_isLive).map((e) => e.id);
        await (_db.update(_db.workoutExerciseTable)
          ..where((t) => t.id.isIn(live))).write(
          WorkoutExerciseTableCompanion(
            syncStatus: Value(SyncStatus.pending.index),
          ),
        );
        await (_db.update(_db.workoutSetTemplateTable)
          ..where((t) => t.workoutExerciseId.isIn(live))).write(
          WorkoutSetTemplateTableCompanion(
            syncStatus: Value(SyncStatus.pending.index),
          ),
        );
      });
      _logger.w('Workout ${w.id} gained logged sets mid-delete; re-creating it');
      return;
    }
    _logger.i('Deleted workout ${w.id} (server ${w.serverId})');
  }

  /// Shows a deleted workout again because history hangs on it, as `pending`.
  ///
  /// This used to choose `pendingUpdate` if the server had the workout and
  /// `pending` if it didn't, by whether the row had a server id. Every row has
  /// one now, and a pending delete doesn't record whether it reached the
  /// server. It doesn't need to: the create goes out under the id the workout
  /// already has, and the server answers with the row it holds, updated to
  /// match, or makes it if it has none. Either way the sessions logged under
  /// it can follow.
  Future<void> _keepWorkoutForHistory(WorkoutTableData w) async {
    await _db.untracked(
      () => (_db.update(_db.workoutTable)..where((t) => t.id.equals(w.id)))
          .write(
            WorkoutTableCompanion(syncStatus: Value(SyncStatus.pending.index)),
          ),
    );
    _logger.w('Workout ${w.id} has logged history; kept instead of deleted');
  }

  static bool _isLive(WorkoutExerciseTableData we) {
    final status = SyncStatus.fromDb(we.syncStatus);
    return status != SyncStatus.pendingDelete && status != SyncStatus.retired;
  }

  /// The server id of the exercise a workout exercise performs, if the server
  /// has it.
  ///
  /// A built-in exercise has one once `_syncSystemExerciseIds` has linked it
  /// to the server's catalogue, on the pull; until then this is null, and an
  /// entry performing it waits, pending, rather than going up as something
  /// else. It used to fall back to "a linked built-in of the same name" —
  /// found with a substring search, so an unlinked "Squat" could go up as
  /// "Front Squat", and since the update path used it too, an edit could
  /// turn an entry the server already held into a different lift on every
  /// device. A name is not an identity, and the push matches nothing by one.
  Future<String?> _exerciseServerId(int localExerciseId) async {
    final exercise = await _db.exerciseDao.getExerciseById(localExerciseId);
    if (exercise == null) return null;
    return SyncService._serverIdIfPushed(
      exercise.serverId,
      exercise.syncStatus,
    );
  }

  /// Creates workout exercises the server doesn't have yet, under the ids this
  /// device minted for them, and then their prescriptions.
  ///
  /// Each answer says which item it answers: `requestedId`, the id that item
  /// was sent with. Its own id differs in one case: the workout already holds
  /// an entry for that exercise at that position — the slot the server's
  /// create has always been idempotent on — and the server answers with that
  /// entry, which this row then becomes. Such a row stays `pendingUpdate`: the
  /// server returned its entry as it was, so this device's notes and superset
  /// group reach it only with the next push's PUT.
  ///
  /// This used to pair an unmatched answer with its request by the slot
  /// itself, on this side — the exercise and the position. A position is not
  /// an identity, and it paired a new row with one the same push was about to
  /// delete (see [_syncWorkoutExercises]).
  Future<void> _syncNewWorkoutExercisesBatch(
    List<WorkoutExerciseTableData> exercises,
    String workoutServerId,
  ) async {
    final dtos = <Map<String, dynamic>>[];
    final valid = <WorkoutExerciseTableData>[];
    for (final we in exercises) {
      final exerciseServerId = await _exerciseServerId(we.exerciseId);
      if (exerciseServerId == null) {
        _logger.w(
          '_syncNewWorkoutExercisesBatch: skipping workoutExercise ${we.id} '
          '(pos ${we.orderPosition}, exerciseId=${we.exerciseId}) — its '
          'exercise is not on the server yet',
        );
        continue;
      }
      dtos.add({
        'id': we.serverId,
        'exerciseId': exerciseServerId,
        'orderPosition': we.orderPosition,
        'notes': we.notes,
        'supersetGroupId': we.supersetGroupId,
      });
      valid.add(we);
    }
    if (dtos.isEmpty) return;

    final response = await _create(
      'api/Workout/$workoutServerId/exercises/batch',
      dtos,
      _db.workoutExerciseTable,
      valid.map((we) => we.id),
    );
    if (response == null) return;
    final answered = {
      for (final s in (response.data as List).cast<Map<String, dynamic>>())
        if (s['requestedId'] != null)
          s['requestedId'] as String: s['id'] as String,
    };

    for (final we in valid) {
      final weServerId = answered[we.serverId];
      if (weServerId == null) {
        _logger.w(
          'Workout exercise ${we.id} is missing from the batch answer; '
          'left pending',
        );
        continue;
      }
      await _markSent(
        _db.workoutExerciseTable,
        we.id,
        weServerId,
        weServerId == we.serverId ? we.localRev : -1,
      );

      final templates = await _db.workoutDao.getSetTemplatesForWorkoutExercise(
        we.id,
      );
      // The whole prescription, for the same reason as in
      // _syncWorkoutExercises: the endpoint replaces rather than appends.
      if (templates.isNotEmpty) {
        await _syncNewSetTemplatesBatch(templates, weServerId);
      }
    }
  }

  /// Sends an edited exercise entry and its whole prescription. The entry is
  /// dirty either because a field of its own changed or because one of its set
  /// templates did — the database marks the owner for both — and the template
  /// endpoint replaces the list, so it is always sent whole.
  Future<void> _syncUpdateWorkoutExercise(WorkoutExerciseTableData we) async {
    if (we.serverId == null) return;
    final exerciseServerId = await _exerciseServerId(we.exerciseId);
    if (exerciseServerId == null) return;

    await _apiClient.put(
      'api/Workout/exercises/${we.serverId}',
      data: {
        'exerciseId': exerciseServerId,
        'orderPosition': we.orderPosition,
        'notes': we.notes,
        'supersetGroupId': we.supersetGroupId,
      },
    );
    final templates = await _db.workoutDao.getSetTemplatesForWorkoutExercise(
      we.id,
    );
    if (templates.isNotEmpty) {
      await _syncNewSetTemplatesBatch(templates, we.serverId!);
    }
    await _markSent(_db.workoutExerciseTable, we.id, we.serverId!, we.localRev);
  }

  /// Tells the server an exercise left the workout, then retires the local row
  /// rather than deleting it whenever a session on this device logged sets
  /// against it.
  ///
  /// The server does the same (`RemovedAt`), for the same reason: a session's
  /// exercises point at this row. Foreign keys aren't enforced here, so a
  /// delete didn't cascade into history, it orphaned it — and the queries that
  /// inner-join a session's exercises to this table dropped the orphans, so the
  /// history for that lift vanished on the very device that logged it. The
  /// next pull then re-inserted the server's retired copy under a new local id,
  /// which nothing pointed at, and the pull after that crashed on it (see
  /// `docs/sync-architecture.md` §1).
  Future<void> _syncDeleteWorkoutExercise(WorkoutExerciseTableData we) async {
    if (we.serverId != null) {
      try {
        await _apiClient.delete('api/Workout/exercises/${we.serverId}');
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) rethrow;
      }
    }
    await _db.untracked(() async {
      final referenced =
          await (_db.select(_db.scheduledWorkoutExerciseTable)
                ..where((se) => se.workoutExerciseId.equals(we.id))
                ..limit(1))
              .getSingleOrNull();
      if (referenced != null) {
        await (_db.update(_db.workoutExerciseTable)
          ..where((t) => t.id.equals(we.id))).write(
          WorkoutExerciseTableCompanion(
            syncStatus: Value(SyncStatus.retired.index),
          ),
        );
      } else {
        await _db.workoutDao.deleteWorkoutExercise(we.id);
      }
    });
    _logger.i('Removed workout exercise ${we.id} (server ${we.serverId})');
  }

  /// Pushes an exercise's prescription. The endpoint replaces whatever the
  /// exercise currently has, matching the local save path, which rebuilds every
  /// set template rather than diffing them — so [templates] must always be the
  /// exercise's complete list, never only the rows that still need syncing.
  ///
  /// Each template goes under the id this device minted for it, which the
  /// replace keeps, so what comes back is marked by id. It used to be paired
  /// with the request by position — and the replace minted fresh ids every
  /// time, so the ids this device held named rows the server had just deleted.
  Future<void> _syncNewSetTemplatesBatch(
    List<WorkoutSetTemplateData> templates,
    String workoutExerciseServerId,
  ) async {
    final Response response;
    try {
      response = await _apiClient.post(
        'api/Workout/exercises/$workoutExerciseServerId/sets/batch',
        data:
            templates
                .map(
                  (t) => {
                    'id': t.serverId,
                    'setNumber': t.setNumber,
                    'targetReps': t.targetReps,
                    'orderPosition': t.orderPosition,
                  },
                )
                .toList(),
      );
    } catch (e) {
      if (SyncService._isIdConflict(e)) {
        await _mintNewIds(
          _db.workoutSetTemplateTable,
          templates.map((t) => t.id),
        );
      }
      rethrow;
    }
    final stored = {
      for (final s in (response.data as List).cast<Map<String, dynamic>>())
        s['id'] as String,
    };
    for (final t in templates) {
      if (stored.contains(t.serverId)) {
        await _db.workoutDao.markSetTemplateSynced(t.id, t.serverId!);
      }
    }
  }

  /// Pushes every changed exercise entry of every workout the server has, on
  /// the entry's own status.
  ///
  /// - `pendingDelete` → the DELETE is sent and the row retired or removed —
  ///   first, before anything is created (below);
  /// - never pushed → created, under the id it already has;
  /// - `pendingUpdate` → the entry and its whole prescription are sent;
  /// - an entry the server has whose prescription holds unsent rows (only
  ///   possible for data written before the database tracked changes) → the
  ///   prescription is sent whole.
  ///
  /// A never-pushed entry used to be checked against the server first, with a
  /// GET of the whole workout and a match on exercise and position: a POST
  /// whose response was lost had still created the row, and posting again made
  /// a second. With the id minted here, posting again *is* the check — the
  /// server answers a repeat with the row it made.
  ///
  /// Deletes go before creates. An entry removed here keeps its slot on the
  /// server until its DELETE lands, and the server answers a create for an
  /// occupied slot with the entry in it. Remove an exercise and add it back
  /// in the same place — an undo, or taking the last one out and putting it
  /// back — and the new row, created first, was answered with the old one,
  /// took its id, and then lost it to the DELETE the same push sent next: the
  /// re-added exercise vanished from every device. A delete that fails stops
  /// this workout's push for this run, for the same reason.
  Future<void> _syncWorkoutExercises() async {
    // Only the workouts with something to send, found in one query: the push
    // now runs after every edit, and walking every workout's exercises and
    // templates to find nothing to do cost more the longer someone had used
    // the app.
    final ids =
        (await _db.customSelect('''
      SELECT DISTINCT w.id FROM workout_table w
      JOIN workout_exercise_table we ON we.workout_id = w.id
      LEFT JOIN workout_set_template_table t ON t.workout_exercise_id = we.id
      WHERE w.sync_status != 0 AND (
        we.sync_status IN (0, 2, 3)
        OR (we.sync_status = 1 AND t.id IS NOT NULL AND t.sync_status != 1)
      )
    ''').get()).map((r) => r.read<int>('id')).toList();
    if (ids.isEmpty) return;
    final syncedWorkouts =
        await (_db.select(_db.workoutTable)..where((w) => w.id.isIn(ids))).get();

    for (final w in syncedWorkouts) {
      // Outside the try: a lease lost mid-push must stop the push, not be
      // logged as one item's failure.
      await SyncLease.current?.renew();
      try {
        var exercises = await _db.workoutDao.getExercisesForWorkoutRaw(w.id);
        for (final ex in exercises.where(
          (e) => SyncStatus.fromDb(e.syncStatus) == SyncStatus.pendingDelete,
        )) {
          await _syncDeleteWorkoutExercise(ex);
        }

        // pendingDelete and retired rows are on the server, so one the user
        // took out is never posted back.
        final unpushed =
            (await _db.workoutDao.getExercisesForWorkoutRaw(w.id))
                .where((e) => !SyncStatus.fromDb(e.syncStatus).isOnServer)
                .toList();
        if (unpushed.isNotEmpty) {
          await _syncNewWorkoutExercisesBatch(unpushed, w.serverId!);
        }
        exercises = await _db.workoutDao.getExercisesForWorkoutRaw(w.id);

        for (final ex in exercises) {
          switch (SyncStatus.fromDb(ex.syncStatus)) {
            case SyncStatus.pendingUpdate:
              await _syncUpdateWorkoutExercise(ex);
            case SyncStatus.synced:
              final templates = await _db.workoutDao
                  .getSetTemplatesForWorkoutExercise(ex.id);
              // Push the whole prescription, not just the unsent rows: the
              // endpoint replaces what the exercise has, so a partial list
              // would delete the templates that did make it across on an
              // earlier attempt.
              if (templates.any(
                (t) => t.syncStatus != SyncStatus.synced.index,
              )) {
                await _syncNewSetTemplatesBatch(templates, ex.serverId!);
              }
            case SyncStatus.pending ||
                SyncStatus.pendingDelete ||
                SyncStatus.retired:
              break;
          }
        }
      } catch (e) {
        _logger.w('_syncWorkoutExercises failed for workout ${w.id}: $e');
      }
    }
  }

  /// Folds a workout's server-side exercises down to one per
  /// `(exerciseId, orderPosition)`.
  ///
  /// `POST api/Workout/{id}/exercises/batch` had no idempotency, so a push whose
  /// response was lost and then retried left a second identical row behind. The
  /// endpoint is fixed, but the rows it already created are still stored, and a
  /// full pull — which only happens once the local tables have been emptied, so
  /// in practice after an account switch — would materialise every one of them.
  ///
  /// Position is part of the key on purpose: a workout may hold the same
  /// movement twice as a superset, and those instances are genuinely distinct.
  /// Two entries sharing both the exercise *and* the slot are not.
  List<Map<String, dynamic>> _collapseDuplicateServerExercises(
    List<Map<String, dynamic>> exercises,
  ) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    var dropped = 0;
    for (final ex in exercises) {
      // The caller skips retired rows on its own; pass them through rather than
      // letting one occupy a slot and hide the live entry behind it.
      if (ex['removedAt'] != null) {
        result.add(ex);
        continue;
      }
      final key = '${ex['exerciseId']}@${ex['orderPosition']}';
      if (!seen.add(key)) {
        dropped++;
        continue;
      }
      result.add(ex);
    }
    if (dropped > 0) {
      _logger.i(
        'Pull: collapsed $dropped duplicate workout exercise(s) from the server',
      );
    }
    return result;
  }

  /// Folds an exercise's prescription down to one row per set number.
  ///
  /// `AddSetTemplatesBatchAsync` appended rather than replaced until 1.0.2+12
  /// (see `docs/trainer-session-review.md` §4), so a workout saved three times
  /// left three complete copies of its prescription on the server. Set numbers
  /// are ordinals within an exercise — two templates numbered 2 are by
  /// definition the same set — so collapsing them is not a heuristic. Session
  /// Review already does exactly this server-side; the sync client is the other
  /// reader that needed to.
  List<Map<String, dynamic>> _collapseDuplicateSetTemplates(
    List<Map<String, dynamic>> templates,
  ) {
    final seen = <int>{};
    final result = <Map<String, dynamic>>[];
    var dropped = 0;
    for (final st in templates) {
      if (!seen.add(st['setNumber'] as int)) {
        dropped++;
        continue;
      }
      result.add(st);
    }
    if (dropped > 0) {
      _logger.i('Pull: collapsed $dropped duplicate set template(s)');
    }
    return result;
  }

  Future<void> _pullWorkouts() async {
    final response = await _apiClient.get('api/Workout');
    final list = (response.data as List).cast<Map<String, dynamic>>();
    await _applyEach('workouts', list, _applyServerWorkout);

    await _removeDeletedElsewhere<WorkoutTableData>(
      what: 'workouts',
      serverIds: {for (final w in list) w['id'] as String},
      locals:
          await (_db.select(_db.workoutTable)..where(
                (t) =>
                    t.serverId.isNotNull() &
                    t.syncStatus.isNotValue(SyncStatus.pending.index),
              ))
              .get(),
      serverIdOf: (r) => r.serverId!,
      syncStatusOf: (r) => r.syncStatus,
      // Only ever a workout deleted from another device or by a trainer from
      // the console — this device's own delete leaves no row to find. Kept if
      // a session on this device logged sets against it, the same way the
      // server keeps (409s) a workout with logged history.
      delete: (r) => _db.workoutDao.deleteWorkout(r.id),
    );
  }

  Future<void> _applyServerWorkout(Map<String, dynamic> w) async {
    final workoutServerId = w['id'] as String;
    final existingWorkout = await _db.workoutDao.getWorkoutByServerId(
      workoutServerId,
    );
    if (existingWorkout != null) {
      // Every other row this method pulls is written once and left alone —
      // the trainee is the only writer, so nothing else changes a workout
      // out from under a device that already has it. That stopped being
      // true once a trainer could edit a client's workout from the Trainer
      // Console: the server row changes, but this device never asks about
      // it again unless the workout is new to it. Reconcile is what makes
      // an edit actually reach a device that already pulled the workout
      // once.
      //
      // Only a clean copy is safe to overwrite. A dirty one (pending /
      // pendingUpdate / pendingDelete) is this device's own unsent edit —
      // the server hasn't seen it yet, so refreshing from the server here
      // would silently throw it away instead of pushing it.
      if (SyncStatus.fromDb(existingWorkout.syncStatus) == SyncStatus.synced) {
        await _reconcileWorkoutFromServer(existingWorkout, w);
      }
      return;
    }

    // A workout this device has never held. It used to be matched to any
    // unlinked local workout *of the same name* first — which linked a
    // trainee's own "Upper A" to their trainer's "Upper A" and merged the two.
    // A name is not an identity; two workouts may share one.
    final localWorkoutId = await _db
        .into(_db.workoutTable)
        .insert(
          WorkoutTableCompanion(
            name: Value(w['name'] as String),
            description: Value(w['description'] as String?),
            difficulty: Value(w['difficulty'] as int),
            estimatedDurationMinutes: Value(
              w['estimatedDurationMinutes'] as int? ?? 30,
            ),
            isTemplate: Value(w['isTemplate'] as bool),
            scheduledDate: Value(
              w['scheduledDate'] != null
                  ? DateTime.parse(w['scheduledDate'] as String)
                  : null,
            ),
            completedDate: Value(
              w['completedDate'] != null
                  ? DateTime.parse(w['completedDate'] as String)
                  : null,
            ),
            color: Value(w['color'] as int?),
            serverId: Value(workoutServerId),
            syncStatus: const Value(1),
          ),
        );

    final exercises = _collapseDuplicateServerExercises(
      (w['exercises'] as List).cast<Map<String, dynamic>>(),
    );
    for (final ex in exercises) {
      final exServerId = ex['id'] as String;
      if (await _db.workoutDao.getWorkoutExerciseByServerId(exServerId) !=
          null) {
        continue;
      }
      final localExercise = await _db.exerciseDao.getExerciseByServerId(
        ex['exerciseId'] as String,
      );
      if (localExercise == null) {
        _logger.w(
          'Pull workout $workoutServerId: skipping exercise — no local match for exercise server ID ${ex['exerciseId']}',
        );
        continue;
      }

      // A retired exercise is still returned so that logged sessions can
      // resolve what was performed, but it is no longer part of the
      // workout. Pulling it back in as a normal (visible) row would put an
      // exercise the user removed back into their plan — but skipping it
      // entirely, as this used to do, left nothing for a
      // ScheduledWorkoutExercise pulled afterwards to link against, so any
      // set logged against it could never be pulled onto another device.
      // Store it as `retired`: present for FK resolution, hidden from
      // every workout-builder/active-workout listing, and never pushed.
      final retired = ex['removedAt'] != null;
      final localWeId = await _db
          .into(_db.workoutExerciseTable)
          .insert(
            WorkoutExerciseTableCompanion(
              workoutId: Value(localWorkoutId),
              exerciseId: Value(localExercise.id),
              orderPosition: Value(ex['orderPosition'] as int),
              notes: Value(ex['notes'] as String?),
              supersetGroupId: Value(ex['supersetGroupId'] as int?),
              serverId: Value(exServerId),
              syncStatus: Value(
                retired ? SyncStatus.retired.index : SyncStatus.synced.index,
              ),
            ),
          );
      if (retired) continue;

      for (final st in _collapseDuplicateSetTemplates(
        (ex['setTemplates'] as List).cast<Map<String, dynamic>>(),
      )) {
        await _db
            .into(_db.workoutSetTemplateTable)
            .insert(
              WorkoutSetTemplateTableCompanion(
                workoutExerciseId: Value(localWeId),
                setNumber: Value(st['setNumber'] as int),
                targetReps: Value(st['targetReps'] as String),
                orderPosition: Value(st['orderPosition'] as int),
                serverId: Value(st['id'] as String),
                syncStatus: const Value(1),
              ),
            );
      }
    }
    _logger.i('Pulled workout $workoutServerId');
  }

  /// Refreshes a workout this device already holds from the server's current
  /// copy. The counterpart to the insert path above: that one only ever
  /// fires for a workout the device has never seen, so it can't see a
  /// trainer's later edit. This one can, but only touches what's clean —
  /// see the call site's note on why a dirty row is skipped instead.
  Future<void> _reconcileWorkoutFromServer(
    WorkoutTableData existing,
    Map<String, dynamic> w,
  ) async {
    await (_db.update(_db.workoutTable)
      ..where((t) => t.id.equals(existing.id))).write(
      WorkoutTableCompanion(
        name: Value(w['name'] as String),
        description: Value(w['description'] as String?),
        difficulty: Value(w['difficulty'] as int),
        estimatedDurationMinutes: Value(
          w['estimatedDurationMinutes'] as int? ?? 30,
        ),
        isTemplate: Value(w['isTemplate'] as bool),
        color: Value(w['color'] as int?),
      ),
    );

    final serverExercises = _collapseDuplicateServerExercises(
      (w['exercises'] as List).cast<Map<String, dynamic>>(),
    );
    final serverExerciseIds = serverExercises
        .map((e) => e['id'] as String)
        .toSet();

    final localExercises =
        await (_db.select(_db.workoutExerciseTable)
              ..where((t) => t.workoutId.equals(existing.id)))
            .get();
    final localByServerId = {
      for (final le in localExercises)
        if (le.serverId != null) le.serverId!: le,
    };

    for (final ex in serverExercises) {
      final exServerId = ex['id'] as String;
      final local = localByServerId[exServerId];
      final isRetiredOnServer = ex['removedAt'] != null;

      if (local == null) {
        // The server has an exercise entry this device has never pulled —
        // the same insert a brand-new workout would get on its first pull.
        final localExercise = await _db.exerciseDao.getExerciseByServerId(
          ex['exerciseId'] as String,
        );
        if (localExercise == null) {
          _logger.w(
            'Reconcile workout $exServerId: skipping exercise — no local match for exercise server ID ${ex['exerciseId']}',
          );
          continue;
        }
        final localWeId = await _db
            .into(_db.workoutExerciseTable)
            .insert(
              WorkoutExerciseTableCompanion(
                workoutId: Value(existing.id),
                exerciseId: Value(localExercise.id),
                orderPosition: Value(ex['orderPosition'] as int),
                notes: Value(ex['notes'] as String?),
                supersetGroupId: Value(ex['supersetGroupId'] as int?),
                serverId: Value(exServerId),
                // Arrives already retired if the server reports it that
                // way — e.g. a swap the trainer made before this device
                // ever pulled the workout once.
                syncStatus: Value(isRetiredOnServer ? 4 : 1),
              ),
            );
        if (!isRetiredOnServer) {
          await _replaceLocalSetTemplates(localWeId, ex);
        }
        continue;
      }

      // Same rule as the workout level, one row down: a dirty local copy of
      // this exercise is this device's own unsent edit.
      if (SyncStatus.fromDb(local.syncStatus) != SyncStatus.synced) continue;

      if (isRetiredOnServer) {
        if (local.syncStatus != 4) {
          await (_db.update(_db.workoutExerciseTable)
            ..where((t) => t.id.equals(local.id))).write(
            const WorkoutExerciseTableCompanion(syncStatus: Value(4)),
          );
        }
        continue;
      }

      await (_db.update(_db.workoutExerciseTable)
        ..where((t) => t.id.equals(local.id))).write(
        WorkoutExerciseTableCompanion(
          orderPosition: Value(ex['orderPosition'] as int),
          notes: Value(ex['notes'] as String?),
          supersetGroupId: Value(ex['supersetGroupId'] as int?),
        ),
      );
      await _replaceLocalSetTemplates(local.id, ex);
    }

    // A locally-live, clean exercise the server no longer lists at all —
    // not even as `removedAt` — has been taken out of the workout entirely.
    // Retire it here for the same reason `removedAt` does: a scheduled
    // session on this device may still point at it.
    for (final le in localExercises) {
      // Only a clean one: a pending row was never pushed, so it is not the
      // server's to take away, and a dirty one is this device's unsent edit.
      if (SyncStatus.fromDb(le.syncStatus) != SyncStatus.synced) continue;
      if (serverExerciseIds.contains(le.serverId)) continue;
      await (_db.update(_db.workoutExerciseTable)
        ..where((t) => t.id.equals(le.id))).write(
        const WorkoutExerciseTableCompanion(syncStatus: Value(4)),
      );
    }
  }

  /// Replaces a clean workout-exercise's set templates with the server's.
  /// Skips the whole exercise if any of its local set templates are dirty —
  /// same "device's own unsent edit" rule as everywhere else in reconcile,
  /// applied one level further down since a set template can be edited
  /// without its parent exercise row changing at all.
  ///
  /// The check, the delete and the inserts are one transaction. Outside one,
  /// two pulls running at once each delete, then each insert, and the
  /// exercise ends up with every set twice — `1, 2, 1, 2`, which the active
  /// workout lists as "set 1, set 1, set 2, set 2" with the twin inputs
  /// sharing one controller. `pullAll` no longer overlaps itself, but the
  /// background WorkManager isolate has its own SyncService and its own
  /// connection, which only the database's own locking can see.
  Future<void> _replaceLocalSetTemplates(
    int localWeId,
    Map<String, dynamic> ex,
  ) => _db.transaction(() async {
    final localSets =
        await (_db.select(_db.workoutSetTemplateTable)
              ..where((t) => t.workoutExerciseId.equals(localWeId)))
            .get();
    if (localSets.any(
      (s) => SyncStatus.fromDb(s.syncStatus) != SyncStatus.synced,
    )) {
      return;
    }

    await (_db.delete(_db.workoutSetTemplateTable)
          ..where((t) => t.workoutExerciseId.equals(localWeId)))
        .go();

    for (final st in _collapseDuplicateSetTemplates(
      (ex['setTemplates'] as List).cast<Map<String, dynamic>>(),
    )) {
      await _db
          .into(_db.workoutSetTemplateTable)
          .insert(
            WorkoutSetTemplateTableCompanion(
              workoutExerciseId: Value(localWeId),
              setNumber: Value(st['setNumber'] as int),
              targetReps: Value(st['targetReps'] as String),
              orderPosition: Value(st['orderPosition'] as int),
              serverId: Value(st['id'] as String),
              syncStatus: const Value(1),
            ),
          );
    }
  });
}
