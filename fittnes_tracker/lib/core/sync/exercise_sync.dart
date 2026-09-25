part of 'sync_service.dart';

/// Custom exercises, and linking the built-in ones to the server's ids.
extension ExerciseSync on SyncService {
  Future<void> syncCustomExercises() async {
    final unsynced = await _db.exerciseDao.getUnsyncedCustomExercises();
    if (unsynced.isEmpty) return;

    for (final exercise in unsynced) {
      try {
        switch (SyncStatus.fromDb(exercise.syncStatus)) {
          case SyncStatus.pending:
            await _syncNewExercise(exercise);
          case SyncStatus.pendingUpdate:
            await _syncUpdateExercise(exercise);
          case SyncStatus.pendingDelete:
            await _syncDeleteExercise(exercise);
          case SyncStatus.synced || SyncStatus.retired:
            break;
        }
      } catch (e) {
        _logger.w('Exercise sync failed for local ${exercise.id}: $e');
      }
    }
  }

  Future<void> _syncNewExercise(ExerciseTableData e) async {
    final response = await _create(
      'api/Exercise/UserExercise',
      {'id': e.serverId, ..._exerciseBody(e)},
      _db.exerciseTable,
      [e.id],
    );
    if (response == null) return;
    final serverId = response.data['id'] as String;
    await _markSent(_db.exerciseTable, e.id, serverId, e.localRev);
    _logger.i('Synced new exercise ${e.id} → server $serverId');
  }

  Map<String, dynamic> _exerciseBody(ExerciseTableData e) => {
    'name': e.name,
    'description': e.description ?? '',
    'type': e.type,
    'targetMuscleGroups': e.targetMuscleGroups,
    'imageUrl': e.imageUrl ?? '',
    'isCustom': true,
    'nameDe': e.nameDe ?? '',
    'descriptionDe': e.descriptionDe ?? '',
  };

  Future<void> _syncUpdateExercise(ExerciseTableData e) async {
    if (e.serverId == null) {
      await _syncNewExercise(e);
      return;
    }
    await _apiClient.put(
      'api/Exercise/UserExercise/${e.serverId}',
      data: _exerciseBody(e),
    );
    await _markSent(_db.exerciseTable, e.id, e.serverId!, e.localRev);
    _logger.i('Updated exercise ${e.id} on server ${e.serverId}');
  }

  Future<void> _syncDeleteExercise(ExerciseTableData e) async {
    // Sent even if this exercise never reached the server: a pending delete no
    // longer says whether it did (every row has an id), and a 404 is the
    // answer that it didn't.
    if (e.serverId != null) {
      try {
        await _apiClient.delete('api/Exercise/UserExercise/${e.serverId}');
      } on DioException catch (err) {
        if (err.response?.statusCode != 404) rethrow;
      }
    }
    await _db.untracked(() => _db.exerciseDao.deleteExercise(e.id));
    if (e.serverId == null) return;
    _logger.i('Deleted exercise ${e.id} from server ${e.serverId}');
  }

  /// Fetches all system (non-custom) exercises from the server and stores their
  /// server Guid as `serverId` on the matching local exercise. This is
  /// required before pulling workouts, since workout exercises reference
  /// exercises by their server Guid — and before pushing one, which waits for
  /// its exercise to be linked (`_exerciseServerId`).
  ///
  /// A local built-in matches a server one by its name, exactly, ignoring
  /// case: the English name, else the server's German name. Nothing looser.
  /// The seed and the server's catalogue come from one list, so the names
  /// agree; a "last resort" that took the only unlinked exercise a substring
  /// search turned up could link "Squat" to "Front Squat", and every workout
  /// using it would then have gone up as the wrong lift.
  Future<void> _syncSystemExerciseIds() async {
    final response = await _apiClient.get('api/Exercise/AllExercises');
    final list = (response.data as List).cast<Map<String, dynamic>>();
    // Unlinked built-ins by lower-cased name, each claimed at most once.
    final unlinked = <String, List<ExerciseTableData>>{};
    for (final l in await _db.exerciseDao.getAllExercises()) {
      if (l.serverId != null || l.isCustom) continue;
      unlinked.putIfAbsent(l.name.toLowerCase(), () => []).add(l);
    }
    ExerciseTableData? claim(String? name) {
      if (name == null || name.isEmpty) return null;
      final candidates = unlinked[name.toLowerCase()];
      if (candidates == null || candidates.isEmpty) return null;
      return candidates.removeAt(0);
    }

    for (final e in list) {
      if (e['isCustom'] == true) continue;
      final serverId = e['id'] as String;
      final name = e['name'] as String;

      // Already in local DB with serverId — nothing to do.
      if (await _db.exerciseDao.getExerciseByServerId(serverId) != null) {
        continue;
      }

      final nameDe = e['nameDe'] as String?;
      var match = claim(name);
      if (match == null) {
        match = claim(nameDe);
        if (match != null) {
          _logger.i(
            '_syncSystemExerciseIds: matched "${match.name}" to server "$name" '
            'via nameDe',
          );
        }
      }

      if (match != null) {
        await _db.exerciseDao.markExerciseSynced(match.id, serverId);
      } else {
        // No local match (e.g. fresh install, seed hasn't run yet) — create
        // from server data so workout exercise links can be resolved immediately.
        await _db.exerciseDao.saveExercise(
          ExerciseTableCompanion(
            name: Value(name),
            description: Value(e['description'] as String?),
            nameDe: Value(e['nameDe'] as String?),
            descriptionDe: Value(e['descriptionDe'] as String?),
            type: Value(e['type'] as int? ?? 0),
            targetMuscleGroups: Value(e['targetMuscleGroups'] as String? ?? ''),
            imageUrl: Value(e['imageUrl'] as String?),
            isCustom: const Value(false),
            serverId: Value(serverId),
            syncStatus: const Value(1),
          ),
        );
      }
    }
  }

  Future<void> _pullCustomExercises() async {
    final response = await _apiClient.get('api/Exercise/UserExercise');
    final list = (response.data as List).cast<Map<String, dynamic>>();
    await _applyEach('custom exercises', list, (e) async {
      final serverId = e['id'] as String;
      if (await _db.exerciseDao.getExerciseByServerId(serverId) != null) {
        return;
      }
      await _db.exerciseDao.saveExercise(
        ExerciseTableCompanion(
          name: Value(e['name'] as String),
          description: Value(e['description'] as String?),
          nameDe: Value(e['nameDe'] as String?),
          descriptionDe: Value(e['descriptionDe'] as String?),
          type: Value(e['type'] as int),
          targetMuscleGroups: Value(e['targetMuscleGroups'] as String? ?? ''),
          imageUrl: Value(e['imageUrl'] as String?),
          isCustom: const Value(true),
          serverId: Value(serverId),
          syncStatus: const Value(1),
        ),
      );
      _logger.i('Pulled exercise $serverId');
    });

    await _removeDeletedElsewhere<ExerciseTableData>(
      what: 'custom exercises',
      serverIds: {for (final e in list) e['id'] as String},
      locals:
          await (_db.select(_db.exerciseTable)..where(
                (t) =>
                    t.serverId.isNotNull() &
                    t.isCustom.equals(true) &
                    t.syncStatus.isNotValue(SyncStatus.pending.index),
              ))
              .get(),
      serverIdOf: (r) => r.serverId!,
      syncStatusOf: (r) => r.syncStatus,
      delete: (r) async {
        // A workout still using it would lose the exercise from under it.
        final inUse =
            await (_db.select(_db.workoutExerciseTable)
                  ..where((we) => we.exerciseId.equals(r.id))
                  ..limit(1))
                .getSingleOrNull();
        if (inUse != null) return false;
        await _db.exerciseDao.deleteExercise(r.id);
        return true;
      },
    );
  }
}
