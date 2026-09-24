import 'dart:math';

import 'package:ForgeForm/core/app_database.dart';
import 'package:drift/drift.dart';

/// Ownership of the database for one sync run, shared by every isolate.
///
/// `SyncService` joins a caller to a run already in flight, but only within
/// one isolate: the WorkManager task runs in another, with its own
/// `SyncService` and its own connection to the same file. Two pushes at once
/// POST the same pending rows twice, and most creates on the server have no
/// way to tell a retry from a new row. The lease is a row in the database, so
/// both isolates see the same one. It also keeps a push and a pull in the same
/// isolate from running side by side. See `docs/sync-architecture.md` §5.
class SyncLease {
  SyncLease._(this._db) : _token = _newToken();

  final AppDatabase _db;

  /// Identifies this run, not this isolate: two runs in one isolate must not
  /// be able to take the lease from each other either.
  final String _token;

  static final _random = Random();
  static String _newToken() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';

  /// How long a run can hold the lease without renewing it. Long enough for a
  /// slow step between two [renew] calls, short enough that a run killed
  /// mid-sync stops blocking the next one within minutes.
  static const ttl = Duration(minutes: 5);

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
    try {
      return await body(lease);
    } finally {
      await lease._release();
    }
  }

  /// Extends the lease. Called between the steps of a run.
  Future<void> renew() => _tryAcquire();

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
