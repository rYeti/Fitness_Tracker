import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/network/api_client.dart';
import 'package:logger/logger.dart';

class WeightSyncService {
  final AppDatabase _db;
  final ApiClient _apiClient;
  final Logger _logger = Logger();

  WeightSyncService({required AppDatabase db, required ApiClient apiClient})
      : _db = db,
        _apiClient = apiClient;

  /// Fetches all unsynced local weight records and pushes them to the API.
  ///
  /// - [WeightSyncStatus.pending]       → POST /api/WeightTracking/TrackWeight
  /// - [WeightSyncStatus.pendingUpdate] → PUT  (not yet on API — skipped)
  /// - [WeightSyncStatus.pendingDelete] → DELETE (not yet on API — skipped)
  ///
  /// Failures for individual records are logged and skipped so one bad
  /// record doesn't block the rest of the batch.
  Future<void> syncWeightLogs() async {
    final unsynced = await _db.weightRecordDao.getUnsyncedRecords();
    if (unsynced.isEmpty) return;

    for (final record in unsynced) {
      try {
        switch (WeightSyncStatus.values[record.syncStatus]) {
          case WeightSyncStatus.pending:
            await _syncNew(record);
          case WeightSyncStatus.pendingUpdate:
            await _syncUpdate(record);
          case WeightSyncStatus.pendingDelete:
            await _syncDelete(record);
          case WeightSyncStatus.synced:
            break; // shouldn't appear — getUnsyncedRecords filters these out
        }
      } catch (e) {
        _logger.w('Sync failed for local record ${record.id}: $e');
        // Continue — partial sync is acceptable.
      }
    }
  }

  /// Marks a local record as [WeightSyncStatus.synced] and stores the
  /// UUID returned by the API.
  Future<void> markAsSynced(int localId, String serverId) =>
      _db.weightRecordDao.markSynced(localId: localId, serverId: serverId);

  // ── Private helpers ──────────────────────────────────────────────────────

  Future<void> _syncNew(WeightRecordData record) async {
    final response = await _apiClient.post(
      '/api/WeightTracking/TrackWeight',
      data: {
        'date': record.date.toIso8601String(),
        'weight': record.weight,
        'note': record.note,
      },
    );
    final serverId = response.data['id'] as String;
    await markAsSynced(record.id, serverId);
    _logger.i('Synced new record ${record.id} → server $serverId');
  }

  Future<void> _syncUpdate(WeightRecordData record) async {
    if (record.serverId == null) {
      // Edited before the first sync ever completed — treat as new.
      await _syncNew(record);
      return;
    }
    // TODO: wire up once PUT /api/WeightTracking/TrackWeight/{id} exists.
    _logger.w(
      'PUT not yet available on API — skipping pendingUpdate for local record ${record.id}',
    );
  }

  Future<void> _syncDelete(WeightRecordData record) async {
    if (record.serverId == null) {
      // Never reached the server — safe to remove the local row immediately.
      await _db.weightRecordDao.deleteWeightRecord(record.id);
      return;
    }
    // TODO: wire up once DELETE /api/WeightTracking/TrackWeight/{id} exists.
    _logger.w(
      'DELETE not yet available on API — skipping pendingDelete for local record ${record.id}',
    );
  }
}
