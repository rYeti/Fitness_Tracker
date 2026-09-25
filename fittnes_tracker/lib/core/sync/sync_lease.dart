import 'dart:async';
import 'dart:math';

import 'package:ForgeForm/core/app_database.dart';
import 'package:drift/drift.dart';

/// Thrown by `SyncService.syncAll` / `pullAll` when another run held the lease
/// for the whole wait, so this one never started.
///
/// A distinct exception rather than a quiet return, because the callers act on
/// "it finished": `main.dart` records the pull time (and so skips the next
/// pull), and Settings reports success. A run that didn't happen must not look
/// like one that did.
class SyncBusyException implements Exception {
  const SyncBusyException();

  @override
  String toString() => 'Another sync is already running';
}

/// Thrown from [SyncLease.renew] when the lease was taken by another run while
/// this one still thought it held it — it expired because nothing could renew
/// it (the OS suspended the app mid-sync). Carrying on would put two runs on
/// the database at once, which is what the lease exists to prevent, so the run
/// stops; everything it hadn't finished is still pending and is retried.
class SyncLeaseLostException implements Exception {
  const SyncLeaseLostException();

  @override
  String toString() => 'Sync lease lost to another run';
}

/// Ownership of the database for one sync run, shared by every isolate.
///
/// `SyncService` joins a caller to a run already in flight, but only within
/// one isolate: the WorkManager task runs in another, with its own
/// `SyncService` and its own connection to the same file. Two pushes at once
/// POST the same pending rows twice, and most creates on the server have no
/// way to tell a retry from a new row. The lease is a row in the database, so
/// both isolates see the same one. It also keeps a push and a pull in the same
/// isolate from running side by side. See `docs/sync-architecture.md` §8.
class SyncLease {
  SyncLease._(this._db) : _token = _newToken();

  final AppDatabase _db;

  /// Identifies this run, not this isolate: two runs in one isolate must not
  /// be able to take the lease from each other either.
  final String _token;

  /// Set when a heartbeat found the lease gone; [renew] then throws.
  bool _lost = false;

  static final _random = Random();
  static String _newToken() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';

  static final _zoneKey = Object();

  /// The lease held by the run this code is part of, if any — so code deep in
  /// a step (a loop over thousands of pulled records) can [renew] without the
  /// lease being passed down to it.
  static SyncLease? get current => Zone.current[_zoneKey] as SyncLease?;

  /// How long the lease lasts without renewal. A heartbeat renews it every
  /// [heartbeat] while the run is alive, however long any one step takes; it
  /// only runs out when the process can't run at all — killed, or suspended in
  /// the background — so a run that died stops blocking the next within
  /// minutes.
  static const ttl = Duration(minutes: 5);
  static const heartbeat = Duration(seconds: 30);

  /// Runs [body] while holding the lease, and returns its result.
  ///
  /// When another run holds it, keeps trying for [wait], then gives up and
  /// returns null without running [body]: a sync that didn't run is retried on
  /// the next trigger, and a sync that ran alongside another is how duplicates
  /// got onto the server.
  static Future<T?> run<T>(
    AppDatabase db,
    Future<T> Function(SyncLease lease) body, {
    Duration wait = const Duration(seconds: 30),
  }) async {
    final lease = SyncLease._(db);
    final deadline = DateTime.now().add(wait);
    while (!await lease._tryAcquire()) {
      if (DateTime.now().isAfter(deadline)) return null;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    final beat = Timer.periodic(heartbeat, (_) async {
      try {
        if (!lease._lost && !await lease._tryAcquire()) lease._lost = true;
      } catch (_) {
        // A beat still in flight when the run ends can find the database
        // closed (the background isolate closes it right after). Nothing
        // awaits a timer callback, so an error here would be unhandled; the
        // next [renew] checks the lease properly anyway.
      }
    });
    try {
      return await runZoned(() => body(lease), zoneValues: {_zoneKey: lease});
    } finally {
      beat.cancel();
      await lease._release();
    }
  }

  /// Extends the lease, or throws [SyncLeaseLostException] if another run has
  /// taken it. Called between the steps of a run and within long ones, which
  /// is where a run that lost the lease finds out and stops.
  Future<void> renew() async {
    if (_lost || !await _tryAcquire()) {
      _lost = true;
      throw const SyncLeaseLostException();
    }
  }

  Future<bool> _tryAcquire() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final taken = await _db.customUpdate(
      'UPDATE sync_lease_table SET holder = ?, expires_at = ? '
      'WHERE id = 1 AND (holder IS NULL OR holder = ? OR expires_at < ?)',
      variables: [
        Variable.withString(_token),
        Variable.withInt(now + ttl.inMilliseconds),
        Variable.withString(_token),
        Variable.withInt(now),
      ],
      updates: {_db.syncLeaseTable},
    );
    return taken == 1;
  }

  Future<void> _release() => _db.customUpdate(
    'UPDATE sync_lease_table SET holder = NULL, expires_at = 0 '
    'WHERE id = 1 AND holder = ?',
    variables: [Variable.withString(_token)],
    updates: {_db.syncLeaseTable},
  );
}
