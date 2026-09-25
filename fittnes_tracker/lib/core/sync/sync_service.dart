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
/// Every step still ran — one failing no longer stops the rest — but the
/// answer did not apply whole, so its cursor was not stored: the next pull asks
/// for the same changes again. A caller must not record the pull as done
/// either, or it would wait out its interval before trying again.
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
  /// one no longer means the server has the row; [SyncStatus.isOnServer]
  /// does. Sending a reference to a row the server doesn't hold would, for
  /// most of these, be refused (a session's workout is a foreign key) or
  /// quietly point at nothing until the row arrived.
  ///
  /// A null here is never sent in the reference's place: the row that refers
  /// waits instead, dirty, for a push after its target's (see
  /// `_scheduledWorkoutBody`, `_putPlanWorkouts`). Sending null *says*
  /// something — "this session belongs to no plan" — and the server believes
  /// it.
  static String? _serverIdIfPushed(String? serverId, int syncStatus) =>
      serverId != null && SyncStatus.fromDb(syncStatus).isOnServer
          ? serverId
          : null;

  /// Whether a request failed because the server refused the id it was sent:
  /// 409 from a create means the id names a row that belongs to someone else.
  static bool _isIdConflict(Object error) =>
      error is DioException && error.response?.statusCode == 409;

  /// The id a 409 refused, which the server names in its answer
  /// (`{ "error": "id_in_use", "id": … }`) — for a batch, where only that one
  /// row needs a new id.
  static String? _refusedId(Object error) {
    if (!_isIdConflict(error)) return null;
    final body = (error as DioException).response?.data;
    return body is Map ? body['id'] as String? : null;
  }

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
  /// the response, or null if the server refused the id:
  ///
  /// - 409: the id names a row that is someone else's. The rows in [localIds]
  ///   of [table] get fresh ones and try again next push.
  /// - 410: the id names a row this account deleted — on another device, or
  ///   by a trainer — that this device hasn't heard about yet. It is handled
  ///   exactly as the deletion would have been had the pull brought it first
  ///   ([_goneElsewhere]): the row goes, or, when history on this device hangs
  ///   on it, takes a fresh id and is created again.
  Future<Response?> _create(
    String path,
    Object data,
    TableInfo table,
    Iterable<int> localIds,
  ) async {
    try {
      return await _apiClient.post(path, data: data);
    } catch (e) {
      final type = _tombstoneTypeOf(table);
      final gone = _goneId(e, data);
      if (gone != null && type != null) {
        _logger.w('POST $path: $gone was deleted elsewhere (410)');
        await _goneElsewhere(type, gone);
        return null;
      }
      if (!_isIdConflict(e)) rethrow;
      await _mintNewIds(table, localIds);
      return null;
    }
  }

  /// The id a 410 refused, which the server names in its answer
  /// (`{ "error": "id_deleted", "id": … }`) — for a batch, the one entry that
  /// was deleted — falling back to the id a single create was sent with.
  static String? _goneId(Object error, [Object? sent]) {
    if (error is! DioException || error.response?.statusCode != 410) {
      return null;
    }
    final body = error.response?.data;
    final named = body is Map ? body['id'] as String? : null;
    return named ?? (sent is Map ? sent['id'] as String? : null);
  }

  /// Every id a 410 refused. A batch carrying deleted ids applies nothing and
  /// names all of them in `ids`, so they can be dropped in one pass instead of
  /// one retry each; an answer without `ids` falls back to [_goneId].
  static List<String> _goneIds(Object error) {
    final one = _goneId(error);
    if (one == null) return const [];
    final body = (error as DioException).response?.data;
    final ids = body is Map ? body['ids'] : null;
    return ids is List ? ids.whereType<String>().toList() : [one];
  }

  /// The changes feed's name for what a row of [table] is, for the tables
  /// whose rows the server records a deletion of (a tombstone). A table not
  /// listed has none, and so no create of it is ever answered 410.
  static String? _tombstoneTypeOf(TableInfo table) =>
      switch (table.actualTableName) {
        'exercise_table' => 'exercise',
        'workout_table' => 'workout',
        'workout_plan_table' => 'workoutPlan',
        'scheduled_workout_table' => 'scheduledWorkout',
        'meal_table' => 'meal',
        'food_item' => 'foodItem',
        'weight_record' => 'weight',
        _ => null,
      };

  /// Gives one row a fresh id and makes it `pending`, so the push creates it
  /// again: for a row the server deleted (its id is refused for good, with
  /// 410) that this device still needs on the server, because history here
  /// hangs on it. Unlike [_mintNewIds] it touches a row whatever its status —
  /// a row the server *had* is exactly the case.
  Future<void> _giveFreshId(TableInfo table, int localId) => _db.customUpdate(
    'UPDATE ${table.actualTableName} SET server_id = ?, sync_status = 0 '
    'WHERE id = ?',
    variables: [Variable.withString(newSyncId()), Variable.withInt(localId)],
    updates: {table},
  );

  /// A row deleted elsewhere — named by a tombstone in the changes feed, or
  /// by a 410 answering a create — brought to the same end here.
  ///
  /// The row is deleted, with what hangs only on it, under
  /// [AppDatabase.untracked]: the server already deleted it, so recording a
  /// DELETE would only be answered 404. Deletion wins over an edit this
  /// device hasn't sent — the edit could never land: a PUT of the row finds
  /// nothing, and a create of its id is refused.
  ///
  /// Except where history on this device hangs on the row. Then it stays,
  /// and each type says how: a workout with logged sessions, or a session
  /// holding sets the server never got, takes a fresh id and is created
  /// again, because that history needs it on the server; a custom exercise a
  /// workout uses, or a food a meal logged, stays as it is, because the rows
  /// that name it name it only here (see each `_…Gone`). These are the
  /// protections the old absence-inferred sweep had, now applied to a fact
  /// rather than to a guess.
  Future<void> _goneElsewhere(String entityType, String serverId) =>
      _db.untracked(() async {
        switch (entityType) {
          case 'mealFood':
            await _mealFoodGone(serverId);
          case 'meal':
            await _mealGone(serverId);
          case 'scheduledWorkout':
            await _sessionGone(serverId);
          case 'workoutPlan':
            await _planGone(serverId);
          case 'workout':
            await _workoutGone(serverId);
          case 'exercise':
            await _exerciseGone(serverId);
          case 'foodItem':
            await _foodItemGone(serverId);
          case 'weight':
            await (_db.delete(_db.weightRecord)
              ..where((t) => t.serverId.equals(serverId))).go();
          case 'mealTemplate':
            await _mealTemplateDao.removeDeletedElsewhere(serverId);
          default:
            // Recorded by a newer server; nothing here knows what it was.
            _logger.w('Unknown deletion type "$entityType"; ignored');
        }
      });

  /// Sends the DELETEs the database recorded in `sync_deletion_table` — every
  /// row with an id deleted locally outside the sync engine, pushed or not.
  ///
  /// A 404 or 410 means the row is already gone; there is nothing left to
  /// send. A 409 or 403 is the server refusing — a workout that sessions with
  /// logged sets still hang on, or one a trainer assigned — which retrying
  /// would not change; the server's answer is that the row stays, and this
  /// device, which already deleted it, has to get it back. The full pull used
  /// to do that by listing it again. A pull that asks only for what changed
  /// never will — the row hasn't changed — so the cursor is dropped, and the
  /// next pull asks for everything. Anything else is kept for next time.
  Future<void> _pushDeletions() async {
    final pending = await _db.select(_db.syncDeletionTable).get();
    for (final d in pending) {
      final path = _deletionPath(d);
      if (path != null) {
        try {
          await _apiClient.delete(path);
        } on DioException catch (e) {
          final code = e.response?.statusCode;
          if (code == 409 || code == 403) {
            _logger.w(
              'DELETE $path refused by the server ($code); dropping, and the '
              'next pull fetches everything so the row comes back',
            );
            await _db.delete(_db.syncMeta).go();
          } else if (code != 404 && code != 410) {
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
        // By the entry's own id, which tells two portions of one food apart.
        // An entry an older build queued names the entry too; the food item
        // it also recorded is what that build sent, and is no longer needed.
        return 'api/Meal/${d.parentServerId}/foods/${d.serverId}';
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

  /// Brings this device in line with the server: asks the changes feed
  /// (`GET api/Sync/changes`) for everything that changed since this device
  /// last asked, applies it, and applies what was deleted. Safe to run on a
  /// fresh install or after switching devices, whose first pull asks for
  /// everything.
  ///
  /// A deletion is only ever known from the server saying so — a tombstone in
  /// the answer, or a 410 answering a create. Nothing is inferred from a row
  /// being absent: an answer lists only what changed, so every unchanged row
  /// is absent from it. The pull used to download every list in full and
  /// treat a row missing from one as deleted elsewhere, which was a guess,
  /// and the reason the pull could only run every six hours.
  ///
  /// Each step runs even when an earlier one failed, and within a step each
  /// record is applied on its own, so one record the device can't take costs
  /// that record, not the rest. If anything failed, this throws
  /// [SyncIncompleteException] once every step has run — and the cursor is
  /// not moved, so the next pull asks for the same changes again.
  ///
  /// A call made while a pull is already running joins that run: a second
  /// pull straight after the first would fetch the same data, and running the
  /// two side by side is how set templates came to be duplicated.
  ///
  /// [everything] asks for everything whatever the cursor says — Settings'
  /// "Restore from server", which is for when this device's copy looks wrong
  /// and the user wants the server's back. A call that joins a pull already
  /// running gets that pull, whatever it asked for.
  ///
  /// Like [syncAll], throws [SyncBusyException] when it couldn't start.
  Future<void> pullAll({bool everything = false}) =>
      _pullInFlight ??= _leased(
        (lease) => _pullAll(lease, everything: everything),
      ).whenComplete(() => _pullInFlight = null);

  /// Server ids this device deleted and has not yet told the server about.
  /// The pull must not bring them back in the meantime.
  Set<String> _deletedHere = const {};

  /// Plan links removed here and not yet removed on the server, as
  /// `planServerId|workoutServerId`. The link pull only ever adds, so one it
  /// re-added in the meantime would outlive the DELETE.
  Set<String> _linksRemovedHere = const {};

  /// How many server copies this pull did not apply because this device's
  /// copy held a change the server hadn't seen ([_holdBack]).
  int _heldBack = 0;

  /// Records that the pull skipped the server's copy of a row because this
  /// device's copy is dirty — the push's to send, and not the pull's to
  /// overwrite.
  ///
  /// Skipping it is the old rule. What is new is its cost: the answer's
  /// cursor is not stored when anything was held back, and the next pull asks
  /// for the same changes again. The obvious assumption — the push will send
  /// this device's copy, and the server's answer to it comes back in the next
  /// answer anyway — fails whenever the push changes nothing on the server.
  /// The server stamps a row only when a value actually changes, so a push
  /// that writes back what the server already holds leaves no trace in the
  /// feed, and the server's version skipped here — a food another device
  /// added to the same meal, say — would never be sent again
  /// (`docs/sync-architecture.md` §37).
  void _holdBack(String what, Object? serverId) {
    _heldBack++;
    _logger.i(
      'Pull $what: $serverId holds a change not sent yet; left for the push, '
      'and the cursor stays where it was',
    );
  }

  /// The cursor of the last changes-feed answer applied whole, or null if
  /// there is none — a fresh install, an upgrade, a sign-out, or a refused
  /// DELETE ([_pushDeletions]).
  Future<String?> _changesCursor() async =>
      (await (_db.select(_db.syncMeta)
            ..where((m) => m.id.equals(1))).getSingleOrNull())
          ?.changesCursor;

  Future<void> _pullAll(SyncLease lease, {required bool everything}) async {
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
    _heldBack = 0;
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

    final since = everything ? null : await _changesCursor();
    final Map<String, dynamic> changes;
    try {
      // No cursor — a fresh install, an install upgraded from a build that
      // pulled full lists, a sign-out, or a refused DELETE — asks for
      // everything, deletions included. Only the first holds nothing a
      // deletion could remove; the second holds rows other devices may have
      // deleted since that build last pulled, and the answer's deletions are
      // applied like any other answer's.
      changes = await _apiClient.getChanges(since);
    } catch (e) {
      _logger.w('Pull: the changes feed failed: $e');
      throw SyncIncompleteException([...failed, 'changes']);
    }
    await lease.renew();
    List<Map<String, dynamic>> listOf(String key) =>
        ((changes[key] as List?) ?? const []).cast<Map<String, dynamic>>();

    // Built-in exercises linked to the server's ids before anything that
    // names one is applied. They are the server's catalogue, not the
    // account's data, so they are not in the feed — and the catalogue is
    // hundreds of exercises, which a pull on every resume can't download each
    // time. It is fetched only when something needs it (_needsCatalogue).
    if (since == null ||
        await _needsCatalogue(listOf('workouts'), listOf('exercises'))) {
      await step('exercise ids', _syncSystemExerciseIds);
    }

    // Each aggregate after the ones it refers to: exercises before the
    // workouts that use them, workouts before plans and sessions, food before
    // meals.
    await step(
      'settings',
      () => _pullUserSettings(changes['settings'] as Map<String, dynamic>?),
    );
    await step(
      'custom exercises',
      () => _pullCustomExercises(listOf('exercises')),
    );
    await step('workouts', () => _pullWorkouts(listOf('workouts')));
    await step('plans', () => _pullWorkoutPlans(listOf('workoutPlans')));
    await step(
      'sessions',
      () => _pullScheduledWorkouts(listOf('scheduledWorkouts')),
    );
    await step('food items', () => _pullFoodItems(listOf('foodItems')));
    await step('meals', () => _pullMeals(listOf('meals')));
    await step('weights', () => _pullWeightLogs(listOf('weights')));
    await step(
      'meal templates',
      () => _pullMealTemplates(listOf('mealTemplates')),
    );
    // What was deleted, after everything else in the same answer.
    await step('deletions', () => _applyTombstones(listOf('deleted')));
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
    final cursor = changes['cursor'] as String?;
    if (_heldBack > 0 || cursor == null) {
      _logger.i(
        'Pull: $_heldBack row(s) held back; the next pull asks for the same '
        'changes again',
      );
      return;
    }
    await _db
        .into(_db.syncMeta)
        .insertOnConflictUpdate(
          SyncMetaCompanion(id: const Value(1), changesCursor: Value(cursor)),
        );
  }

  /// Whether the pull has to fetch the built-in exercise catalogue to link
  /// this device's built-ins to the server's ids: when an answer's workout
  /// names an exercise this device holds under no id — a built-in the server
  /// added since this device last linked, say, in a workout a trainer
  /// assigned — or when a workout here uses a built-in not linked yet, whose
  /// entry waits, unsent, for the link (`_exerciseServerId`). A pull without
  /// a cursor always fetches it.
  ///
  /// The full pull used to fetch the catalogue every time, which was one of
  /// the reasons it could only run every six hours.
  Future<bool> _needsCatalogue(
    List<Map<String, dynamic>> workouts,
    List<Map<String, dynamic>> customExercises,
  ) async {
    final custom = {for (final e in customExercises) e['id']};
    for (final w in workouts) {
      for (final entry in (w['exercises'] as List? ?? const [])) {
        final id = (entry as Map)['exerciseId'] as String?;
        if (id == null || custom.contains(id)) continue;
        if (await _db.exerciseDao.getExerciseByServerId(id) == null) {
          return true;
        }
      }
    }
    final waiting =
        await _db
            .customSelect(
              'SELECT 1 FROM workout_exercise_table we '
              'JOIN exercise_table e ON e.id = we.exercise_id '
              'WHERE e.is_custom = 0 AND e.server_id IS NULL LIMIT 1',
            )
            .getSingleOrNull();
    return waiting != null;
  }

  /// Applies the deletions a changes answer lists, each as
  /// [_goneElsewhere] — after the answer's aggregates, never before.
  ///
  /// An answer is not a snapshot: its lists are read one after another, so a
  /// row deleted while the answer was being put together can be listed as
  /// changed *and* as deleted. Applied in the other order, the deletion would
  /// remove it and the aggregate would then put it straight back — and with
  /// the cursor past both, nothing would ever take it out again.
  ///
  /// Within the answer, rows go before the rows they hang on — a meal's foods
  /// before the meal, a session before its workout — so that deciding whether
  /// history still hangs on a workout sees its sessions as the server left
  /// them, not as they were a moment before.
  Future<void> _applyTombstones(List<Map<String, dynamic>> deleted) {
    const order = [
      'mealFood',
      'meal',
      'scheduledWorkout',
      'workoutPlan',
      'workout',
      'exercise',
      'foodItem',
      'weight',
      'mealTemplate',
    ];
    int rank(Map<String, dynamic> t) {
      final i = order.indexOf(t['entityType'] as String? ?? '');
      return i < 0 ? order.length : i;
    }

    final ordered = [...deleted]..sort((a, b) => rank(a) - rank(b));
    return _applyEach(
      'deletions',
      ordered,
      (t) => _goneElsewhere(t['entityType'] as String, t['entityId'] as String),
    );
  }

  /// Applies each server record in [items] as the sync engine
  /// ([AppDatabase.untracked]) and in its own savepoint, so one record that
  /// fails leaves nothing half-written and doesn't stop the rest.
  ///
  /// A record that fails still fails the step: this throws once the rest are
  /// applied. With the whole history downloaded on every pull, a record
  /// skipped here was simply tried again next time. With a cursor, the next
  /// pull only asks for what changed after this one, so a record skipped and
  /// forgotten would be gone for good — the step's failure is what keeps the
  /// cursor where it was ([pullAll]).
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
    var failures = 0;
    for (var i = 0; i < items.length; i += chunk) {
      final end = i + chunk < items.length ? i + chunk : items.length;
      await _db.untracked(() async {
        for (final item in items.sublist(i, end)) {
          if (item is Map && _deletedHere.contains(item['id'])) continue;
          try {
            await _db.transaction(() => apply(item));
          } catch (e) {
            failures++;
            _logger.w('Pull $what: could not apply one record, skipped: $e');
          }
        }
      });
      // One step can take minutes on a first pull of years of history; this
      // is where a run that lost the lease meanwhile finds out and stops,
      // rather than at the end of the step.
      await SyncLease.current?.renew();
    }
    if (failures > 0) {
      throw StateError('$failures $what record(s) could not be applied');
    }
  }

  @Deprecated('Use syncWeightLogs() or syncAll()')
  Future<void> syncWeightLogsLegacy() => syncWeightLogs();

  @Deprecated('Use syncAll()')
  Future<void> markWeightRecordAsSynced(int localId, String serverId) =>
      _db.weightRecordDao.markSynced(localId: localId, serverId: serverId);
}
