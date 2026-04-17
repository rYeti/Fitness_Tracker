import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/network/api_client.dart';
import 'package:logger/logger.dart';

class SyncService {
  final AppDatabase _db;
  final ApiClient _apiClient;
  final Logger _logger = Logger();

  SyncService({required AppDatabase db, required ApiClient apiClient})
    : _db = db,
      _apiClient = apiClient;

  /// Fetches all unsynced local weight records and pushes them to the API.
  ///
  /// - [WeightSyncStatus.pending]       → POST /api/WeightTracking/TrackWeight
  /// - [WeightSyncStatus.pendingUpdate] → PUT
  /// - [WeightSyncStatus.pendingDelete] → DELETE
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

  Future<void> syncAll() async {
    syncWeightLogs();
  }

  /// Marks a local record as [WeightSyncStatus.synced] and stores the
  /// UUID returned by the API.
  Future<void> markWeightRecordAsSynced(int localId, String serverId) =>
      _db.weightRecordDao.markSynced(localId: localId, serverId: serverId);

  // ── Private helpers ──────────────────────────────────────────────────────

  Future<void> _syncNew(WeightRecordData record) async {
    final response = await _apiClient.post(
      'api/WeightTracking/TrackWeight',
      data: {
        'date': record.date.toIso8601String(),
        'weight': record.weight,
        'note': record.note,
      },
    );
    final serverId = response.data['id'] as String;
    await markWeightRecordAsSynced(record.id, serverId);
    _logger.i('Synced new record ${record.id} → server $serverId');
  }

  Future<void> _syncUpdate(WeightRecordData record) async {
    if (record.serverId == null) {
      // Edited before first sync — treat as a new record.
      await _syncNew(record);
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
    // serverId doesn't change on an update — re-use the existing one.
    await markWeightRecordAsSynced(record.id, record.serverId!);
    _logger.i('Updated record ${record.id} on server ${record.serverId}');
  }

  Future<void> _syncDelete(WeightRecordData record) async {
    if (record.serverId == null) {
      // Never reached the server — safe to remove the local row immediately.
      await _db.weightRecordDao.deleteWeightRecord(record.id);
      return;
    }
    await _apiClient.delete(
      'api/WeightTracking/TrackWeight/${record.serverId}',
    );
    // Server record is gone — now remove the local row too.
    await _db.weightRecordDao.deleteWeightRecord(record.id);
    _logger.i('Deleted record ${record.id} from server ${record.serverId}');
  }

  /// Fetches all unsynced local weight records and pushes them to the API.
  ///
  /// - [WeightSyncStatus.pending]       → POST /api/WeightTracking/TrackWeight
  /// - [WeightSyncStatus.pendingUpdate] → PUT
  /// - [WeightSyncStatus.pendingDelete] → DELETE
  ///
  /// Failures for individual records are logged and skipped so one bad
  /// record doesn't block the rest of the batch.
}
