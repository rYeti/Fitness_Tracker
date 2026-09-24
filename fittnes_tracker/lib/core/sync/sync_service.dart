import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/dao/meal_template_dao.dart';
import 'package:ForgeForm/core/network/api_client.dart';
import 'package:ForgeForm/core/sync/sync_lease.dart';
import 'package:ForgeForm/core/sync/sync_triggers.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout_set.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:logger/logger.dart';

part 'exercise_sync.dart';
part 'workout_sync.dart';
part 'plan_sync.dart';
part 'session_sync.dart';
part 'nutrition_sync.dart';
part 'body_sync.dart';
part 'sync_dedup.dart';

/// Thrown by [SyncService.pullAll] when one or more of its steps failed.
///
/// Every step still ran — one failing no longer stops the rest — but a caller
/// must not record the pull as done, or the steps that failed would not be
/// retried until the throttle next let a pull through.
class SyncIncompleteException implements Exception {
  SyncIncompleteException(this.failedSteps);

  final List<String> failedSteps;

  @override
  String toString() => 'Sync incomplete: ${failedSteps.join(', ')} failed';
}

class SyncService {
  final AppDatabase _db;

  final ApiClient _apiClient;

  final MealTemplateDao _mealTemplateDao;

  final Logger _logger = Logger();

  SyncService({
    required AppDatabase db,
    required ApiClient apiClient,
    required MealTemplateDao mealTemplateDao,
    this.leaseWait = const Duration(seconds: 30),
  }) : _db = db,
       _apiClient = apiClient,
       _mealTemplateDao = mealTemplateDao;

  /// How long [syncAll] / [pullAll] wait for another run to finish before
  /// giving up with [SyncBusyException].
  final Duration leaseWait;

  /// Runs [body] holding the sync lease, or throws [SyncBusyException] if
  /// another run held it for all of [leaseWait].
  Future<void> _leased(Future<void> Function(SyncLease lease) body) async {
    final ran = await SyncLease.run(_db, (lease) async {
      await body(lease);
      return true;
    }, wait: leaseWait);
    if (ran == null) throw const SyncBusyException();
  }

  // The run already in progress, if any. Static because no caller holds on to
  // a SyncService — main.dart, Settings and sign-out each build a fresh one —
  // so an instance field would guard nothing. See
  // docs/sync-concurrent-runs.md: `_runInitialSync` fires on launch *and* on
  // every resume, and two pulls interleaving their delete-then-insert of the
  // same set templates is what left users with every set listed twice.
  //
  // These only see this isolate. [SyncLease] is what keeps a run here from
  // overlapping one in the WorkManager isolate, and a push from overlapping a
  // pull.
  static Future<void>? _syncInFlight;

  static Future<void>? _pullInFlight;

  /// Forgets the per-process state below — throttles and in-flight runs — so
  /// each test starts from a process that has never synced.
  @visibleForTesting
  static void resetForTesting() {
    _syncInFlight = null;
    _pullInFlight = null;
    _lastDedup = null;
    _lastSentSettings = null;
  }

  /// Completes once no push or pull started from this isolate is running.
  static Future<void> whenIdle() async {
    await _syncInFlight?.catchError((_) {});
    await _pullInFlight?.catchError((_) {});
  }

  /// Sends every local change to the server, in dependency order: deletions,
  /// then exercises, food, settings and weights, then workouts, plans, meals
  /// and meal templates, then scheduled workouts and what was logged in them.
  ///
  /// A push only talks to the server about rows that changed. Finding out
  /// what changed *elsewhere* — including what was deleted — is the pull's
  /// job; it used to happen here too, as seven full-list GETs on every push,
  /// which is what made pushing often too expensive to do.
  ///
  /// A call made while a push is already running joins that run rather than
  /// starting a second one alongside it.
  ///
  /// Throws [SyncBusyException] if another run (the background task, or a pull)
  /// held the database for the whole of [leaseWait] — so a caller never takes
  /// a push that didn't happen for one that did.
  Future<void> syncAll() =>
      _syncInFlight ??= _leased(_syncAll).whenComplete(
        () => _syncInFlight = null,
      );

  /// When the folds in [_deduplicateAll] last ran in this process. They scan
  /// whole tables, and the push now runs after every edit; they heal legacy
  /// data, so a few minutes between runs costs nothing.
  static DateTime? _lastDedup;

  Future<void> _syncAll(SyncLease lease) async {
    // Phase 0: fold duplicate rows left behind by earlier sync bugs.
    final lastDedup = _lastDedup;
    if (lastDedup == null ||
        DateTime.now().difference(lastDedup) > const Duration(minutes: 10)) {
      await _deduplicateAll();
      _lastDedup = DateTime.now();
    }

    // Phase 1: deletions first, so a row removed and re-added locally reaches
    // the server as a delete followed by an add, never the other way round.
    await _pushDeletions();
    await lease.renew();

    // Phase 2: independent pushes in parallel.
    await Future.wait([
      syncCustomExercises(),
      syncFoodItems(),
      syncUserSettings(),
      syncWeightLogs(),
    ]);
    await lease.renew();

    // Phase 3: workouts depend on exercises being synced.
    await syncWorkoutTemplates();
    await _syncWorkoutExercises();
    await lease.renew();

    // Phase 4: plans depend on workouts; meals depend on food items — run in parallel.
    await Future.wait([syncWorkoutPlans(), syncMeals(), syncMealTemplates()]);
    await lease.renew();

    // Phase 5: scheduled workouts depend on plans and workouts.
    await syncScheduledWorkouts();
    await _syncSessionExercises();
    _logger.i('syncAll: complete');
  }

  /// Records that the server now has what was sent for one row — unless the
  /// row changed while the request was in flight.
  ///
  /// [sentRev] is the row's `local_rev` as read before the request. The
  /// database bumps it on every local change (`sync_triggers.dart`), so a
  /// mismatch means the user edited the row mid-request and what the server
  /// holds is already out of date: the row stays `pendingUpdate`, and the next
  /// push sends the edit. Marking it synced regardless, as every push used to,
  /// threw that edit away — and the next pull's reconcile then put the server's
  /// older copy back over it.
  ///
  /// A row that went `pendingDelete` while in flight stays `pendingDelete`. A
  /// create that was edited in flight becomes `pendingUpdate`, now with a
  /// server id, rather than staying `pending` and being POSTed a second time.
  Future<void> _markSent(
    TableInfo table,
    int localId,
    String serverId,
    int sentRev,
  ) => _db.customUpdate(
    'UPDATE ${table.actualTableName} SET server_id = ?, sync_status = CASE '
    'WHEN sync_status IN (0, 2) AND local_rev = ? THEN 1 '
    'WHEN sync_status = 0 THEN 2 '
    'ELSE sync_status END '
    'WHERE id = ?',
    variables: [
      Variable.withString(serverId),
      Variable.withInt(sentRev),
      Variable.withInt(localId),
    ],
    updates: {table},
  );

  /// The server id of a row another row refers to — a workout exercise's
  /// exercise, a session's workout, a meal's food — if the server has that row
  /// yet, else null.
  ///
  /// Every row has a server id from the moment it is inserted, so a non-null
  /// one no longer means the server has the row; `pending` means it hasn't.
  /// Sending a reference to a row the server doesn't hold would, for most of
  /// these, be refused (a session's workout is a foreign key) or quietly point
  /// at nothing until the row arrived.
  static String? _serverIdIfPushed(String? serverId, int syncStatus) =>
      serverId != null && SyncStatus.fromDb(syncStatus) != SyncStatus.pending
          ? serverId
          : null;

  /// Whether a request failed because the server refused the id it was sent:
  /// 409 from a create means the id names a row that belongs to someone else.
  static bool _isIdConflict(Object error) =>
      error is DioException && error.response?.statusCode == 409;

  /// Gives never-pushed rows fresh ids after the server refused theirs (409).
  ///
  /// A v4 UUID colliding with another account's is not something that happens
  /// by chance, but if it ever did the row would be refused on every push for
  /// good. A new id costs nothing: nothing the server holds refers to one it
  /// never accepted. Only `pending` rows are touched — an id the server already
  /// holds for this row is never the one it refused.
  Future<void> _mintNewIds(TableInfo table, Iterable<int> localIds) async {
    for (final id in localIds) {
      await _db.customUpdate(
        'UPDATE ${table.actualTableName} SET server_id = ? '
        'WHERE id = ? AND sync_status = 0',
        variables: [Variable.withString(newSyncId()), Variable.withInt(id)],
        updates: {table},
      );
    }
    _logger.w(
      'Server refused the id of ${localIds.length} ${table.actualTableName} '
      'row(s) (409); minted new ones for the next push',
    );
  }

  /// Marks a clean row changed, for the sync engine's own writes that change
  /// what its push would send — a fold that moves a meal's foods onto the meal
  /// it keeps, say. The database tracks no write inside
  /// [AppDatabase.untracked], so without this the moved foods would sit on a
  /// row that looks sent, and the next pull, which makes a clean meal's list
  /// match the server's, would take them out.
  Future<void> _dirtyIfClean(TableInfo table, int localId) => _db.customUpdate(
    'UPDATE ${table.actualTableName} SET sync_status = 2 '
    'WHERE id = ? AND sync_status = 1',
    variables: [Variable.withInt(localId)],
    updates: {table},
  );

  /// Sends a create — a POST carrying the id this device minted — and returns
  /// the response, or null if the server refused the id (409), in which case
  /// the rows in [localIds] of [table] get fresh ones and try again next push.
  Future<Response?> _create(
    String path,
    Object data,
    TableInfo table,
    Iterable<int> localIds,
  ) async {
    try {
      return await _apiClient.post(path, data: data);
    } catch (e) {
      if (!_isIdConflict(e)) rethrow;
      await _mintNewIds(table, localIds);
      return null;
    }
  }

  /// Sends the DELETEs the database recorded in `sync_deletion_table` — every
  /// synced row deleted locally outside the sync engine.
  ///
  /// A 404 or 410 means the row is already gone, and a 403 that it was never
  /// this account's to delete; either way there is nothing left to send. A 409
  /// is the server refusing — a workout that sessions with logged sets still
  /// hang on — which retrying would not change; the next pull brings the row
  /// back, which is the server's answer. Anything else is kept for next time.
  Future<void> _pushDeletions() async {
    final pending = await _db.select(_db.syncDeletionTable).get();
    for (final d in pending) {
      final path = _deletionPath(d);
      if (path != null) {
        try {
          await _apiClient.delete(path);
        } on DioException catch (e) {
          final code = e.response?.statusCode;
          if (code == 409) {
            _logger.w('DELETE $path refused by the server (409); dropping');
          } else if (code != 403 && code != 404 && code != 410) {
            _logger.w('DELETE $path failed, will retry: $e');
            continue;
          }
        } catch (e) {
          _logger.w('DELETE $path failed, will retry: $e');
          continue;
        }
      }
      await (_db.delete(_db.syncDeletionTable)
        ..where((t) => t.id.equals(d.id))).go();
    }
  }

  String? _deletionPath(SyncDeletionData d) {
    final kind = SyncDeletionKind.values.asNameMap()[d.kind];
    switch (kind) {
      case SyncDeletionKind.exercise:
        return 'api/Exercise/UserExercise/${d.serverId}';
      case SyncDeletionKind.workout:
        return 'api/Workout/${d.serverId}';
      case SyncDeletionKind.workoutExercise:
        return 'api/Workout/exercises/${d.serverId}';
      case SyncDeletionKind.scheduledWorkout:
        return 'api/ScheduledWorkout/${d.serverId}';
      case SyncDeletionKind.workoutPlan:
        return 'api/WorkoutPlan/${d.serverId}';
      case SyncDeletionKind.planWorkout:
        return 'api/WorkoutPlan/${d.parentServerId}/workouts/${d.serverId}';
      case SyncDeletionKind.foodItem:
        return 'api/FoodItem/${d.serverId}';
      case SyncDeletionKind.meal:
        return 'api/Meal/${d.serverId}';
      case SyncDeletionKind.mealFood:
        return 'api/Meal/${d.parentServerId}/foods/${d.extraServerId}';
      case SyncDeletionKind.weight:
        return 'api/WeightTracking/TrackWeight/${d.serverId}';
      case null:
        // Recorded by a newer build's trigger; nothing here knows where it goes.
        _logger.w('Unknown deletion kind "${d.kind}"; dropping');
        return null;
    }
  }

  /// The settings this process last sent. The table has no sync status (the
  /// endpoint is an upsert), and the push now runs after every edit, so this
  /// is what keeps it from re-sending unchanged settings each time.
  static String? _lastSentSettings;

  /// Downloads the server's data, brings this device in line with it, and
  /// removes what was deleted elsewhere. Safe to run on a fresh install or
  /// after switching devices.
  ///
  /// Each step runs even when an earlier one failed — the workouts step used
  /// to throw on one bad row, and everything after it (plans, sessions, food,
  /// meals, weights) was then never pulled again. Within a step, each server
  /// record is applied on its own, so one record the device can't take costs
  /// that record, not the step. If any step failed, this throws
  /// [SyncIncompleteException] once all of them have run, so the caller does
  /// not record the pull as done.
  ///
  /// A call made while a pull is already running joins that run: a second
  /// pull straight after the first would fetch the same data, and running the
  /// two side by side is how set templates came to be duplicated.
  ///
  /// Like [syncAll], throws [SyncBusyException] when it couldn't start.
  Future<void> pullAll() =>
      _pullInFlight ??= _leased(_pullAll).whenComplete(
        () => _pullInFlight = null,
      );

  /// Server ids this device deleted and has not yet told the server about.
  /// The pull must not bring them back in the meantime.
  Set<String> _deletedHere = const {};

  /// Plan links removed here and not yet removed on the server, as
  /// `planServerId|workoutServerId`. The link pull only ever adds, so one it
  /// re-added in the meantime would outlive the DELETE.
  Set<String> _linksRemovedHere = const {};

  Future<void> _pullAll(SyncLease lease) async {
    final pendingDeletions = await _db.select(_db.syncDeletionTable).get();
    _deletedHere = {
      for (final d in pendingDeletions)
        // A plan link is recorded under its *workout's* id — skipping that
        // would hide the whole workout, not the link.
        if (d.kind != SyncDeletionKind.planWorkout.name) d.serverId,
    };
    _linksRemovedHere = {
      for (final d in pendingDeletions)
        if (d.kind == SyncDeletionKind.planWorkout.name)
          '${d.parentServerId}|${d.serverId}',
    };
    final failed = <String>[];
    Future<void> step(String name, Future<void> Function() body) async {
      try {
        await body();
      } catch (e) {
        failed.add(name);
        _logger.w('Pull step "$name" failed: $e');
      }
      await lease.renew();
    }

    // System exercise ids first, so workout exercise lookups resolve.
    await step('exercise ids', _syncSystemExerciseIds);
    await step('settings', _pullUserSettings);
    await step('custom exercises', _pullCustomExercises);
    await step('workouts', _pullWorkouts);
    await step('plans', _pullWorkoutPlans);
    await step('sessions', _pullScheduledWorkouts);
    await step('food items', _pullFoodItems);
    await step('meals', _pullMeals); // food items must exist before meals
    await step('weights', _pullWeightLogs);
    await step('meal templates', _pullMealTemplates);
    // Fold the twins a pull brings down from a server that earlier builds
    // wrote them to: two sessions of one workout on one day, two meals of
    // one category on one day. New ones aren't made (see _deduplicateAll).
    await step(
      'dedup',
      () => _db.untracked(() async {
        await _deduplicateScheduledWorkoutsByContent();
        await _deduplicateMealsByContent();
      }),
    );

    if (failed.isNotEmpty) throw SyncIncompleteException(failed);
  }

  /// Applies each server record in [items] as the sync engine
  /// ([AppDatabase.untracked]) and in its own savepoint, so one record that
  /// fails leaves nothing half-written and doesn't stop the rest.
  ///
  /// Records are applied a few dozen to a transaction: one transaction for
  /// the lot would hold the database's write lock — and so every save in the
  /// app — for the length of the pull, and one per record would pay for a disk
  /// sync per record on a first pull of years of history.
  Future<void> _applyEach<T>(
    String what,
    List<T> items,
    Future<void> Function(T item) apply,
  ) async {
    const chunk = 40;
    for (var i = 0; i < items.length; i += chunk) {
      final end = i + chunk < items.length ? i + chunk : items.length;
      await _db.untracked(() async {
        for (final item in items.sublist(i, end)) {
          if (item is Map && _deletedHere.contains(item['id'])) continue;
          try {
            await _db.transaction(() => apply(item));
          } catch (e) {
            _logger.w('Pull $what: could not apply one record, skipped: $e');
          }
        }
      });
      // One step can take minutes on a first pull of years of history; this
      // is where a run that lost the lease meanwhile finds out and stops,
      // rather than at the end of the step.
      await SyncLease.current?.renew();
    }
  }

  /// Deletes clean local rows the server no longer lists: something deleted
  /// them elsewhere — another device, or a trainer.
  ///
  /// This replaces a reconcile that handled the same rows by resetting them to
  /// `pending` and pushing them again, on the theory that only a database wipe
  /// could make a row disappear. Once another device or a trainer could delete,
  /// that theory put back everything they deleted. Now:
  ///
  /// - a row with unsent local changes is left for the push;
  /// - [delete] may keep a row that local history still hangs on, and says so
  ///   by returning false;
  /// - a list that comes back empty while this device holds synced rows for it
  ///   deletes nothing — an empty answer is far likelier to be a server fault
  ///   than a user who deleted everything, and this is not an operation to get
  ///   wrong on a guess.
  Future<void> _removeDeletedElsewhere<T>({
    required String what,
    required Set<String> serverIds,
    required List<T> locals,
    required String Function(T row) serverIdOf,
    required int Function(T row) syncStatusOf,
    required Future<bool> Function(T row) delete,
  }) async {
    if (serverIds.isEmpty && locals.isNotEmpty) {
      _logger.w(
        'Pull $what: server listed none of ${locals.length} synced rows; '
        'deleting nothing this run',
      );
      return;
    }
    for (final row in locals) {
      if (serverIds.contains(serverIdOf(row))) continue;
      if (SyncStatus.fromDb(syncStatusOf(row)) != SyncStatus.synced) continue;
      try {
        final deleted = await _db.untracked(() => delete(row));
        _logger.i(
          deleted
              ? 'Pull $what: deleted ${serverIdOf(row)}, gone from the server'
              : 'Pull $what: kept ${serverIdOf(row)}, gone from the server but '
                  'history on this device refers to it',
        );
      } catch (e) {
        _logger.w('Pull $what: could not remove ${serverIdOf(row)}: $e');
      }
    }
  }

  @Deprecated('Use syncWeightLogs() or syncAll()')
  Future<void> syncWeightLogsLegacy() => syncWeightLogs();

  @Deprecated('Use syncAll()')
  Future<void> markWeightRecordAsSynced(int localId, String serverId) =>
      _db.weightRecordDao.markSynced(localId: localId, serverId: serverId);
}
