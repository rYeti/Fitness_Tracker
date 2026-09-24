part of 'sync_service.dart';

/// User settings and weight records.
extension BodySync on SyncService {
  Future<void> syncUserSettings() async {
    final settings = await _db.userSettingsDao.getSettings();
    if (settings == null) return;
    final sent = settings.toJsonString();
    if (sent == SyncService._lastSentSettings) return;

    try {
      await _apiClient.put(
        'api/UserSettings',
        data: {
          'dailyCalorieGoal': settings.dailyCalorieGoal,
          'themeMode': settings.themeMode,
          'name': settings.name,
          'age': settings.age,
          'heightCm': settings.heightCm,
          'sex': settings.sex,
          'activityLevel': settings.activityLevel,
          'goalType': settings.goalType,
          'startingWeight': settings.startingWeight,
          'goalWeight': settings.goalWeight,
        },
      );
      SyncService._lastSentSettings = sent;
      _logger.i('Synced user settings');
    } catch (e) {
      _logger.w('User settings sync failed: $e');
    }
  }

  Future<void> syncWeightLogs() async {
    final unsynced = await _db.weightRecordDao.getUnsyncedRecords();
    if (unsynced.isEmpty) return;

    for (final record in unsynced) {
      try {
        switch (SyncStatus.fromDb(record.syncStatus)) {
          case SyncStatus.pending:
            await _syncNewWeight(record);
          case SyncStatus.pendingUpdate:
            await _syncUpdateWeight(record);
          case SyncStatus.pendingDelete:
            await _syncDeleteWeight(record);
          case SyncStatus.synced || SyncStatus.retired:
            break;
        }
      } catch (e) {
        _logger.w('Weight sync failed for local ${record.id}: $e');
      }
    }
  }

  Future<void> _syncNewWeight(WeightRecordData record) async {
    final response = await _create(
      'api/WeightTracking/TrackWeight',
      {
        'id': record.serverId,
        'date': record.date.toIso8601String(),
        'weight': record.weight,
        'note': record.note,
      },
      _db.weightRecord,
      [record.id],
    );
    if (response == null) return;
    final serverId = response.data['id'] as String;
    await _markSent(_db.weightRecord, record.id, serverId, record.localRev);
    _logger.i('Synced new weight record ${record.id} → server $serverId');
  }

  Future<void> _syncUpdateWeight(WeightRecordData record) async {
    if (record.serverId == null) {
      await _syncNewWeight(record);
      return;
    }
    await _apiClient.put(
      'api/WeightTracking/TrackWeight/${record.serverId}',
      data: {
        'date': record.date.toIso8601String(),
        'weight': record.weight,
        'note': record.note,
      },
    );
    await _markSent(
      _db.weightRecord,
      record.id,
      record.serverId!,
      record.localRev,
    );
    _logger.i(
      'Updated weight record ${record.id} on server ${record.serverId}',
    );
  }

  Future<void> _syncDeleteWeight(WeightRecordData record) async {
    if (record.serverId != null) {
      try {
        await _apiClient.delete(
          'api/WeightTracking/TrackWeight/${record.serverId}',
        );
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) rethrow;
      }
    }
    await _db.untracked(
      () => _db.weightRecordDao.deleteWeightRecord(record.id),
    );
    if (record.serverId == null) return;
    _logger.i(
      'Deleted weight record ${record.id} from server ${record.serverId}',
    );
  }

  Future<void> _pullUserSettings() async {
    try {
      final response = await _apiClient.get('api/UserSettings');
      final data = response.data as Map<String, dynamic>?;
      if (data == null) return;
      final existing = await _db.userSettingsDao.getSettings();
      if (existing != null)
        return; // already populated, let syncUserSettings handle updates
      await _db.userSettingsDao.updateProfile(
        name: data['name'] as String?,
        age: data['age'] as int?,
        heightCm: data['heightCm'] as int?,
        sex: data['sex'] as String?,
        activityLevel: data['activityLevel'] as int?,
        goalType: data['goalType'] as int?,
        startingWeight: (data['startingWeight'] as num?)?.toDouble(),
        goalWeight: (data['goalWeight'] as num?)?.toDouble(),
      );
      final calorieGoal = data['dailyCalorieGoal'] as int?;
      if (calorieGoal != null) {
        await _db.userSettingsDao.setCalorieGoal(calorieGoal);
      }
      _logger.i('Pulled user settings from server');
    } catch (e) {
      _logger.w('_pullUserSettings failed: $e');
    }
  }

  Future<void> _pullWeightLogs() async {
    final response = await _apiClient.get('api/WeightTracking/TrackWeight');
    final list = (response.data as List).cast<Map<String, dynamic>>();
    await _applyEach('weights', list, (w) async {
      final serverId = w['id'] as String;
      if (await _db.weightRecordDao.getByServerId(serverId) != null) return;
      await _db.weightRecordDao.addWeightRecord(
        WeightRecordCompanion(
          date: Value(DateTime.parse(w['date'] as String)),
          weight: Value((w['weight'] as num).toDouble()),
          note: Value(w['note'] as String?),
          syncStatus: Value(SyncStatus.synced.index),
          serverId: Value(serverId),
        ),
      );
    });

    await _removeDeletedElsewhere<WeightRecordData>(
      what: 'weights',
      serverIds: {for (final w in list) w['id'] as String},
      locals:
          await (_db.select(_db.weightRecord)..where(
                (t) =>
                    t.serverId.isNotNull() &
                    t.syncStatus.isNotValue(SyncStatus.pending.index),
              ))
              .get(),
      serverIdOf: (r) => r.serverId!,
      syncStatusOf: (r) => r.syncStatus,
      delete: (r) async {
        await _db.weightRecordDao.deleteWeightRecord(r.id);
        return true;
      },
    );
    _logger.i('Pulled ${list.length} weight records');
  }
}
