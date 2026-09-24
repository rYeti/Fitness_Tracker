part of 'sync_service.dart';

/// Folding duplicates earlier sync bugs left on the device.
extension _SyncDedup on SyncService {
  /// Removes duplicate rows (same serverId) from every synced table, keeping
  /// the row with the lowest local id. Cascades to child tables.
  Future<void> _deduplicateScheduledWorkoutsByContent() async {
    try {
      final all =
          await (_db.select(_db.scheduledWorkoutTable)
            ..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

      // Group by workoutId + scheduledDate (date-only, so a UTC-stored and a
      // locally-stored copy of the same calendar day match), then choose which
      // row survives.
      final groups = <String, List<ScheduledWorkoutTableData>>{};
      for (final sw in all) {
        final d = sw.scheduledDate;
        groups
            .putIfAbsent(
              '${sw.workoutId}_${d.year}-${d.month}-${d.day}',
              () => [],
            )
            .add(sw);
      }

      for (final group in groups.values) {
        if (group.length < 2) continue;

        // Deleting a session takes its logged sets with it, so a session the
        // user actually trained outranks everything else — the old rule kept
        // the lowest id and could throw away the only copy of a workout that
        // happened. After that, prefer the row the server knows about.
        final logged = <int, bool>{};
        for (final sw in group) {
          logged[sw.id] = await _hasLoggedSets(sw.id);
        }
        final winner = group.firstWhere(
          (sw) => logged[sw.id] == true,
          orElse:
              () => group.firstWhere(
                (sw) => _onServer(sw.syncStatus),
                orElse: () => group.first,
              ),
        );

        for (final loser in group.where((sw) => sw.id != winner.id)) {
          if (logged[loser.id] == true) {
            _logger.w(
              'Dedup by content: keeping duplicate SW ${loser.id} — it has logged '
              'sets and so does the survivor ${winner.id}; refusing to delete training history',
            );
            continue;
          }
          final exercises = await _db.scheduledWorkoutExerciseDao
              .getAllForScheduledWorkout(loser.id);
          for (final ex in exercises) {
            await (_db.delete(_db.workoutSetTable)
              ..where((t) => t.scheduledWorkoutExerciseId.equals(ex.id))).go();
          }
          await (_db.delete(_db.scheduledWorkoutExerciseTable)
            ..where((t) => t.scheduledWorkoutId.equals(loser.id))).go();
          await (_db.delete(_db.scheduledWorkoutTable)
            ..where((t) => t.id.equals(loser.id))).go();
          _logger.i(
            'Dedup by content: removed duplicate SW ${loser.id} (workout ${loser.workoutId} date ${loser.scheduledDate})',
          );
        }
      }
    } catch (e) {
      _logger.w('_deduplicateScheduledWorkoutsByContent failed: $e');
    }
  }

  Future<void> _deduplicateScheduledExercisesByContent() async {
    try {
      final all =
          await (_db.select(_db.scheduledWorkoutExerciseTable)
            ..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

      // Group first, then choose a survivor — the old pass kept whichever row
      // had the lowest id, which is generally the stale unstamped one. It
      // therefore deleted the row that had just been linked to the server and
      // left the group unlinked again, so the next pull re-created the twin and
      // the next dedup deleted it again, forever. Prefer the linked row, the
      // same way MealDao.deduplicateMeals already does.
      final groups = <String, List<ScheduledWorkoutExerciseTableData>>{};
      for (final ex in all) {
        groups
            .putIfAbsent(
              '${ex.scheduledWorkoutId}_${ex.workoutExerciseId}',
              () => [],
            )
            .add(ex);
      }

      for (final group in groups.values) {
        if (group.length < 2) continue;
        final winner = group.firstWhere(
          (e) => _onServer(e.syncStatus),
          orElse: () => group.first,
        );
        for (final loser in group.where((e) => e.id != winner.id)) {
          await _moveLoggedSets(from: loser.id, to: winner.id);
          await (_db.delete(_db.scheduledWorkoutExerciseTable)
            ..where((t) => t.id.equals(loser.id))).go();
          _logger.i(
            'Dedup by content: merged duplicate ScheduledExercise ${loser.id} '
            'into ${winner.id} (SW ${loser.scheduledWorkoutId}, WE ${loser.workoutExerciseId})',
          );
        }
      }
    } catch (e) {
      _logger.w('_deduplicateScheduledExercisesByContent failed: $e');
    }
  }

  /// Whether a scheduled workout has anything the user actually logged against
  /// it. Used to decide which of two duplicate sessions is the real one.
  /// Folds set templates that share `(workoutExerciseId, setNumber)` into one.
  ///
  /// Set numbers are ordinals within an exercise, so two templates numbered 1
  /// are the same set — the rule `_collapseDuplicateSetTemplates` applies to
  /// the server's list, applied here to what is already on the device. Two
  /// pulls overlapping used to leave every set twice (see
  /// `_replaceLocalSetTemplates`), and nothing on the device ever folded them
  /// back: the builder read the twins, saved them as pending, and the push
  /// then sent both copies to the server.
  ///
  /// The survivor is the row the server has, else the oldest. When an
  /// exercise loses a row its remaining templates are re-queued, so
  /// `_syncWorkoutExercises` pushes the clean list — the endpoint
  /// replaces the prescription, which also clears any twins the server was
  /// sent. Logged sets are keyed on the scheduled exercise and the set number,
  /// never on a template's id, so no history is touched.
  Future<void> _deduplicateSetTemplates() async {
    try {
      final rows =
          await (_db.select(_db.workoutSetTemplateTable)
                ..orderBy([(t) => OrderingTerm.asc(t.id)]))
              .get();
      final survivors = <(int, int), WorkoutSetTemplateData>{};
      final losers = <WorkoutSetTemplateData>[];
      for (final row in rows) {
        final key = (row.workoutExerciseId, row.setNumber);
        final kept = survivors[key];
        if (kept == null) {
          survivors[key] = row;
        } else if (!_onServer(kept.syncStatus) && _onServer(row.syncStatus)) {
          losers.add(kept);
          survivors[key] = row;
        } else {
          losers.add(row);
        }
      }
      if (losers.isEmpty) return;

      final affected = losers.map((r) => r.workoutExerciseId).toSet();
      await _db.transaction(() async {
        await (_db.delete(_db.workoutSetTemplateTable)
              ..where((t) => t.id.isIn(losers.map((r) => r.id))))
            .go();

        // A pendingDelete or retired exercise is never pushed a prescription
        // again, so there is nothing to re-send for it.
        final live =
            await (_db.select(_db.workoutExerciseTable)..where(
                  (we) =>
                      we.id.isIn(affected) &
                      we.syncStatus.isNotValue(3) &
                      we.syncStatus.isNotValue(4),
                ))
                .get();
        await (_db.update(_db.workoutSetTemplateTable)..where(
              (t) => t.workoutExerciseId.isIn(live.map((we) => we.id)),
            ))
            .write(const WorkoutSetTemplateTableCompanion(syncStatus: Value(0)));
      });
      _logger.i(
        'Dedup: removed ${losers.length} duplicate set template(s) across '
        '${affected.length} exercise(s)',
      );
    } catch (e) {
      _logger.w('_deduplicateSetTemplates failed: $e');
    }
  }

  /// Folds logged sets that share `(scheduledWorkoutExerciseId, setNumber)`.
  ///
  /// Two sources put them there: a save made while the exercise had twin set
  /// templates wrote each set twice, and the pull used to copy every stale
  /// server copy onto the device (see `_reconcileLoggedSets`). The survivor is
  /// the lowest id. A save deletes and rewrites the whole exercise, so any
  /// pulled copy was inserted after the rows the device wrote itself; the
  /// oldest row is this device's own record.
  ///
  /// As with set templates, an exercise that lost a row is re-queued whole,
  /// and the replace push clears the same copies from the server.
  Future<void> _deduplicateLoggedSets() async {
    try {
      final rows =
          await (_db.select(_db.workoutSetTable)
                ..where((t) => t.syncStatus.isNotValue(3))
                ..orderBy([(t) => OrderingTerm.asc(t.id)]))
              .get();
      final seen = <(int, int)>{};
      final losers = <int>[];
      final affected = <int>{};
      for (final row in rows) {
        if (seen.add((row.scheduledWorkoutExerciseId, row.setNumber))) continue;
        losers.add(row.id);
        affected.add(row.scheduledWorkoutExerciseId);
      }
      if (losers.isEmpty) return;

      await _db.transaction(() async {
        await (_db.delete(_db.workoutSetTable)
              ..where((t) => t.id.isIn(losers)))
            .go();
        await (_db.update(_db.workoutSetTable)..where(
              (t) =>
                  t.scheduledWorkoutExerciseId.isIn(affected) &
                  t.syncStatus.isNotValue(3),
            ))
            .write(const WorkoutSetTableCompanion(syncStatus: Value(0)));
      });
      _logger.i(
        'Dedup: removed ${losers.length} duplicate logged set(s) across '
        '${affected.length} exercise(s)',
      );
    } catch (e) {
      _logger.w('_deduplicateLoggedSets failed: $e');
    }
  }

  /// Whether the server has a row: every row has a server id from the moment
  /// it is inserted, so it is the status that says so.
  static bool _onServer(int syncStatus) =>
      SyncStatus.fromDb(syncStatus) != SyncStatus.pending;

  Future<bool> _hasLoggedSets(int scheduledWorkoutId) async {
    final exercises = await _db.scheduledWorkoutExerciseDao
        .getAllForScheduledWorkout(scheduledWorkoutId);
    for (final ex in exercises) {
      final sets = await _db.workoutDao.getSetsForScheduledExercise(ex.id);
      if (sets.isNotEmpty) return true;
    }
    return false;
  }

  /// Re-points a duplicate scheduled exercise's logged sets at the row that
  /// survives de-duplication.
  ///
  /// Sets are what the user actually lifted. The previous pass deleted them
  /// outright along with the duplicate row, so de-duplicating could silently
  /// cost someone a session. A set number the winner already has is a genuine
  /// collision — both rows recorded set 2 — and only then is the loser's copy
  /// dropped.
  Future<void> _moveLoggedSets({required int from, required int to}) async {
    final taken =
        (await _db.workoutDao.getSetsForScheduledExercise(
          to,
        )).map((s) => s.setNumber).toSet();

    for (final s in await _db.workoutDao.getSetsForScheduledExercise(from)) {
      if (taken.add(s.setNumber)) {
        await (_db.update(_db.workoutSetTable)
          ..where((t) => t.id.equals(s.id))).write(
          WorkoutSetTableCompanion(scheduledWorkoutExerciseId: Value(to)),
        );
      } else {
        await (_db.delete(_db.workoutSetTable)
          ..where((t) => t.id.equals(s.id))).go();
      }
    }
  }

  Future<void> _deduplicateMealsByContent() async {
    try {
      await _db.mealDao.deduplicateMeals();
    } catch (e) {
      _logger.w('_deduplicateMealsByContent failed: $e');
    }
  }

  /// Folds duplicates earlier sync bugs left on the device. Runs as the sync
  /// engine: folding is not the user deleting anything, and must not reach the
  /// server as a DELETE.
  ///
  /// Every fold moves what hangs on the row it removes onto the row it keeps —
  /// sessions, logged sets, a workout's exercises, a meal's foods — before
  /// removing it. Foreign keys aren't enforced here, so a fold that just
  /// deleted the duplicate left those rows pointing at nothing, and every
  /// screen that joins through the duplicate stopped showing them.
  ///
  /// There used to be a fold of workouts *by name*, which merged any two
  /// workouts that happened to share one — a trainer's "Upper A" and the
  /// client's own — deleting one of them on this device only, for the next
  /// pull to bring back. It is gone: a name is not an identity.
  ///
  /// Since this device mints every row's id (`newSyncId`), none of these
  /// folds is how new data stays single any more: a retried create is
  /// answered with the row it already made, and pulls no longer overlap.
  /// What they fold is what earlier builds left behind — on this device, and
  /// on the server, where a full pull on a new device still finds the twins
  /// those builds created. Two also guard local races that have nothing to do
  /// with sync (a session's exercise inserted twice by overlapping saves).
  /// They stay until that data is gone; nothing here should be added to them.
  Future<void> _deduplicateAll() => _db.untracked(() async {
    // Content-based dedup for scheduled workouts: two rows for the same
    // workout+date are always duplicates regardless of their serverIds.
    await _deduplicateScheduledWorkoutsByContent();

    // Content-based dedup for scheduled workout exercises: two rows with the
    // same (scheduledWorkoutId, workoutExerciseId) are always duplicates,
    // caused by concurrent debounce saves both inserting before either updates
    // the in-memory scheduledExerciseId.
    await _deduplicateScheduledExercisesByContent();

    await _deduplicateSetTemplates();
    await _deduplicateLoggedSets();

    // Rows sharing a server id: the same server row, stored twice.
    await _deduplicateByServerId<ScheduledWorkoutTableData>(
      what: 'sessions',
      rows:
          () =>
              (_db.select(_db.scheduledWorkoutTable)
                    ..where((t) => t.serverId.isNotNull())
                    ..orderBy([(t) => OrderingTerm.asc(t.id)]))
                  .get(),
      serverIdOf: (r) => r.serverId!,
      idOf: (r) => r.id,
      merge: _mergeScheduledWorkout,
    );
    await _deduplicateByServerId<WorkoutTableData>(
      what: 'workouts',
      rows:
          () =>
              (_db.select(_db.workoutTable)
                    ..where((t) => t.serverId.isNotNull())
                    ..orderBy([(t) => OrderingTerm.asc(t.id)]))
                  .get(),
      serverIdOf: (r) => r.serverId!,
      idOf: (r) => r.id,
      merge: _mergeWorkout,
    );
    await _deduplicateByServerId<ExerciseTableData>(
      what: 'exercises',
      rows:
          () =>
              (_db.select(_db.exerciseTable)
                    ..where((t) => t.serverId.isNotNull())
                    ..orderBy([(t) => OrderingTerm.asc(t.id)]))
                  .get(),
      serverIdOf: (r) => r.serverId!,
      idOf: (r) => r.id,
      merge: (keep, drop) async {
        await (_db.update(_db.workoutExerciseTable)
          ..where((t) => t.exerciseId.equals(drop))).write(
          WorkoutExerciseTableCompanion(exerciseId: Value(keep)),
        );
        await (_db.delete(_db.exerciseTable)
          ..where((t) => t.id.equals(drop))).go();
      },
    );
    await _deduplicateByServerId<WorkoutExerciseTableData>(
      what: 'workout exercises',
      rows:
          () =>
              (_db.select(_db.workoutExerciseTable)
                    ..where((t) => t.serverId.isNotNull())
                    ..orderBy([(t) => OrderingTerm.asc(t.id)]))
                  .get(),
      serverIdOf: (r) => r.serverId!,
      idOf: (r) => r.id,
      merge: _mergeWorkoutExercise,
    );
    await _deduplicateByServerId<FoodItemData>(
      what: 'food items',
      rows:
          () =>
              (_db.select(_db.foodItem)
                    ..where((t) => t.serverId.isNotNull())
                    ..orderBy([(t) => OrderingTerm.asc(t.id)]))
                  .get(),
      serverIdOf: (r) => r.serverId!,
      idOf: (r) => r.id,
      merge: (keep, drop) async {
        await (_db.update(_db.mealFoodTable)
          ..where((t) => t.foodEntryId.equals(drop))).write(
          MealFoodTableCompanion(foodEntryId: Value(keep)),
        );
        await (_db.update(_db.mealTable)
          ..where((t) => t.foodItemId.equals(drop))).write(
          MealTableCompanion(foodItemId: Value(keep)),
        );
        await (_db.delete(_db.foodItem)..where((t) => t.id.equals(drop))).go();
      },
    );
    await _deduplicateByServerId<MealTableData>(
      what: 'meals',
      rows:
          () =>
              (_db.select(_db.mealTable)
                    ..where((t) => t.serverId.isNotNull())
                    ..orderBy([(t) => OrderingTerm.asc(t.id)]))
                  .get(),
      serverIdOf: (r) => r.serverId!,
      idOf: (r) => r.id,
      merge: (keep, drop) async {
        final moved = await (_db.update(_db.mealFoodTable)
          ..where((t) => t.mealId.equals(drop))).write(
          MealFoodTableCompanion(mealId: Value(keep)),
        );
        await (_db.delete(_db.mealTable)..where((t) => t.id.equals(drop))).go();
        // The kept meal's list is sent whole now; it has changed.
        if (moved > 0) await _dirtyIfClean(_db.mealTable, keep);
      },
    );
    await _deduplicateByServerId<WeightRecordData>(
      what: 'weights',
      rows:
          () =>
              (_db.select(_db.weightRecord)
                    ..where((t) => t.serverId.isNotNull())
                    ..orderBy([(t) => OrderingTerm.asc(t.id)]))
                  .get(),
      serverIdOf: (r) => r.serverId!,
      idOf: (r) => r.id,
      merge:
          (keep, drop) =>
              (_db.delete(_db.weightRecord)
                ..where((t) => t.id.equals(drop))).go(),
    );
  });

  /// Folds rows that share a server id into the one with the lowest local id.
  /// [merge] moves whatever hangs on the dropped row to the kept one, then
  /// removes it.
  Future<void> _deduplicateByServerId<T>({
    required String what,
    required Future<List<T>> Function() rows,
    required String Function(T row) serverIdOf,
    required int Function(T row) idOf,
    required Future<void> Function(int keep, int drop) merge,
  }) async {
    try {
      final kept = <String, int>{};
      for (final row in await rows()) {
        final sid = serverIdOf(row);
        final keep = kept[sid];
        if (keep == null) {
          kept[sid] = idOf(row);
          continue;
        }
        await _db.transaction(() => merge(keep, idOf(row)));
        _logger.i('Dedup $what: folded local ${idOf(row)} into $keep ($sid)');
      }
    } catch (e) {
      _logger.w('Dedup $what failed: $e');
    }
  }

  /// A session stored twice: its exercises move to the kept copy — merged into
  /// the kept copy's entry for the same workout exercise, sets and all, where
  /// it has one.
  Future<void> _mergeScheduledWorkout(int keep, int drop) async {
    final kept = await _db.scheduledWorkoutExerciseDao.getAllForScheduledWorkout(
      keep,
    );
    for (final ex in await _db.scheduledWorkoutExerciseDao
        .getAllForScheduledWorkout(drop)) {
      final twin =
          kept.where((k) => k.workoutExerciseId == ex.workoutExerciseId).firstOrNull;
      if (twin == null) {
        await (_db.update(_db.scheduledWorkoutExerciseTable)
          ..where((t) => t.id.equals(ex.id))).write(
          ScheduledWorkoutExerciseTableCompanion(scheduledWorkoutId: Value(keep)),
        );
      } else {
        await _moveLoggedSets(from: ex.id, to: twin.id);
        await (_db.delete(_db.scheduledWorkoutExerciseTable)
          ..where((t) => t.id.equals(ex.id))).go();
      }
    }
    await (_db.delete(_db.scheduledWorkoutTable)
      ..where((t) => t.id.equals(drop))).go();
  }

  /// A workout stored twice: its sessions and plan links move to the kept
  /// copy, and each of its exercise entries is merged into the kept copy's
  /// matching one — or moved across whole when there is none.
  Future<void> _mergeWorkout(int keep, int drop) async {
    await (_db.update(_db.scheduledWorkoutTable)
      ..where((t) => t.workoutId.equals(drop))).write(
      ScheduledWorkoutTableCompanion(workoutId: Value(keep)),
    );
    await (_db.update(_db.scheduledWorkoutTable)
      ..where((t) => t.templateWorkoutId.equals(drop))).write(
      ScheduledWorkoutTableCompanion(templateWorkoutId: Value(keep)),
    );
    await (_db.update(_db.workoutPlanWorkoutTable)
      ..where((t) => t.workoutId.equals(drop))).write(
      WorkoutPlanWorkoutTableCompanion(workoutId: Value(keep)),
    );
    final kept = await _db.workoutDao.getExercisesForWorkoutRaw(keep);
    for (final ex in await _db.workoutDao.getExercisesForWorkoutRaw(drop)) {
      final twin =
          kept
              .where(
                (k) =>
                    (ex.serverId != null && k.serverId == ex.serverId) ||
                    (k.exerciseId == ex.exerciseId &&
                        k.orderPosition == ex.orderPosition),
              )
              .firstOrNull;
      if (twin == null) {
        await (_db.update(_db.workoutExerciseTable)
          ..where((t) => t.id.equals(ex.id))).write(
          WorkoutExerciseTableCompanion(workoutId: Value(keep)),
        );
      } else {
        await _mergeWorkoutExercise(twin.id, ex.id);
      }
    }
    await (_db.delete(_db.workoutTable)..where((t) => t.id.equals(drop))).go();
  }

  /// A workout exercise stored twice: the sessions that performed it follow
  /// the kept copy; its prescription goes with it.
  Future<void> _mergeWorkoutExercise(int keep, int drop) async {
    await (_db.update(_db.scheduledWorkoutExerciseTable)
      ..where((t) => t.workoutExerciseId.equals(drop))).write(
      ScheduledWorkoutExerciseTableCompanion(workoutExerciseId: Value(keep)),
    );
    await _db.workoutDao.deleteWorkoutExercise(drop);
  }
}
