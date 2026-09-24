import 'dart:async';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/dao/meal_template_dao.dart';
import 'package:ForgeForm/core/network/services/sync_service.dart';
import 'package:drift/drift.dart';
import 'package:logger/logger.dart';

/// Decides when this device sends its changes to the server.
///
/// Pushing used to happen only as part of the launch/resume sync, which was
/// throttled as a whole to once every six hours because the pull that came
/// with it downloaded the account's entire history. So a workout logged at the
/// gym reached the server — and the client's trainer — up to six hours later,
/// or the next day. A push only sends rows that changed, so it can run far
/// more often than a pull; this runs it:
///
/// - **after an edit** — once the synced tables have been quiet for
///   [debounce], so a set logged mid-workout is on the server within seconds
///   of the last keystroke rather than once per keystroke;
/// - **when the app goes to the background** — the moment a trainee finishes
///   and locks their phone;
/// - **on launch and resume**, from `HomeScreen`;
/// - **again after a failure**, backing off from [retryBase] to ten minutes,
///   while the app is in the foreground.
///
/// The pull keeps its own, much longer throttle in `main.dart`.
class SyncScheduler {
  SyncScheduler({
    required AppDatabase db,
    required Future<SyncService?> Function() service,
    this.debounce = const Duration(seconds: 10),
    this.retryBase = const Duration(seconds: 30),
  }) : _db = db,
       _service = service;

  final AppDatabase _db;

  /// A service to push with, or null when nobody is signed in.
  final Future<SyncService?> Function() _service;

  final Duration debounce;
  final Duration retryBase;

  static const _retryCap = Duration(minutes: 10);

  final Logger _logger = Logger();
  StreamSubscription<Set<TableUpdate>>? _edits;
  Timer? _timer;
  int _failures = 0;
  bool _foreground = true;

  /// Settings have no sync status to ask about — the endpoint is an upsert and
  /// the push sends them whole — so an edit to them is remembered here.
  bool _settingsChanged = false;

  /// Starts pushing after local edits.
  void start() {
    _edits ??= _db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            _db.exerciseTable,
            _db.workoutTable,
            _db.workoutExerciseTable,
            _db.workoutSetTemplateTable,
            _db.workoutPlanTable,
            _db.workoutPlanWorkoutTable,
            _db.scheduledWorkoutTable,
            _db.scheduledWorkoutExerciseTable,
            _db.workoutSetTable,
            _db.foodItem,
            _db.mealTable,
            _db.mealFoodTable,
            _db.weightRecord,
            _db.syncDeletionTable,
            _db.userSettings,
          ]),
        )
        .listen((updates) {
          if (updates.any((u) => u.table == _db.userSettings.actualTableName)) {
            _settingsChanged = true;
          }
          _schedule(debounce);
        });
  }

  void stop() {
    _edits?.cancel();
    _edits = null;
    _timer?.cancel();
    _timer = null;
  }

  /// The app came to the foreground: push now, whatever the pending check
  /// says, and retry failures again. The full push also sends what the check
  /// can't see, such as settings changed before this process started.
  Future<void> onResumed() {
    _foreground = true;
    return pushNow(force: true);
  }

  /// The app is going to the background: push now, while the OS still lets
  /// it run, and stop retrying until it's back.
  Future<void> onBackgrounded() {
    _foreground = false;
    return pushNow();
  }

  /// Pushes whatever is pending, now.
  ///
  /// Every write the push makes (marking rows synced) is itself a table
  /// update, so a push schedules the next one — which finds nothing pending
  /// and does nothing. That is why the check below exists, and why it is one
  /// query rather than a push.
  Future<void> pushNow({bool force = false}) async {
    _timer?.cancel();
    _timer = null;
    try {
      if (!force && !_settingsChanged && !await _pending()) {
        _failures = 0;
        return;
      }
      final service = await _service();
      if (service == null) return;
      _settingsChanged = false;
      await service.syncAll();
      // The push logs and skips a row it couldn't send rather than throwing
      // (offline is the ordinary case), so "it returned" is not "it worked".
      if (!await _pending()) {
        _failures = 0;
        return;
      }
      _retryLater('rows are still pending');
    } catch (e) {
      _retryLater(e);
    }
  }

  void _retryLater(Object why) {
    _failures++;
    _logger.w('Push incomplete (attempt $_failures), will retry: $why');
    if (_foreground) _schedule(_backoff());
  }

  Future<bool> _pending() async =>
      await _db.countUnsyncedChanges(includeChat: false) > 0 ||
      await MealTemplateDao.hasPendingSync();

  Duration _backoff() {
    final factor = 1 << (_failures - 1).clamp(0, 10);
    final wait = retryBase * factor;
    return wait > _retryCap ? _retryCap : wait;
  }

  void _schedule(Duration after) {
    _timer?.cancel();
    _timer = Timer(after, pushNow);
  }
}
