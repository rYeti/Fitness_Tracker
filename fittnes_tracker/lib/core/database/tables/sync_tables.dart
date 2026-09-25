import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// A new row's global id: the `server_id` every synced table gives a row the
/// moment it is inserted on this device.
///
/// The server used to mint every id, and the device learned it only from the
/// response to its POST — so a response lost on the way back, a retry, or two
/// sync runs at once each created the row on the server again. With the id
/// minted here, before the first attempt, every attempt carries the same one
/// and the server can answer a repeat with the row it already made. A row
/// pulled from the server still takes the server's id. See
/// `docs/sync-architecture.md`, part two.
///
/// Having an id no longer means the server has the row: "not pushed yet" is
/// `sync_status = 0` (`SyncStatus.pending`), and nothing else.
String newSyncId() => const Uuid().v4();

/// Tables the sync engine keeps for itself. None of them holds user data; see
/// `lib/core/sync/sync_triggers.dart` and `docs/sync-architecture.md` §3.

/// A row this device has deleted that the server may still have.
///
/// Written only by the database, by an `AFTER DELETE` trigger on each synced
/// table, whenever a row that has a `server_id` is deleted outside
/// `AppDatabase.untracked`. The push reads it, sends the DELETE, and removes
/// the entry. Before this table existed, every screen that deleted a synced
/// row had to remember to leave a `pendingDelete` marker instead — seven
/// didn't, and the server kept (and the next pull restored) what they deleted.
@DataClassName('SyncDeletionData')
class SyncDeletionTable extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Which endpoint the DELETE goes to — see `SyncDeletionKind`.
  TextColumn get kind => text()();

  /// The deleted row's own server id.
  TextColumn get serverId => text()();

  /// The server id of the row the DELETE route is nested under, for kinds that
  /// have one (a meal's food entry is removed through its meal).
  TextColumn get parentServerId => text().nullable()();

  /// A second route id. Only entries an older build queued carry one (a meal
  /// food's food item, which its DELETE was addressed by); nothing reads it
  /// now that a meal's food is removed by its own id.
  TextColumn get extraServerId => text().nullable()();
}

/// One row, `active` set to 1 only inside `AppDatabase.untracked`.
///
/// Every sync trigger checks it and does nothing while it is set, so the sync
/// engine can write server data, mark rows synced and delete rows the server
/// already removed without any of that being mistaken for a local edit. It is
/// a table rather than something in Dart because the triggers live in SQLite
/// and can only read SQLite.
class SyncApplyGuardTable extends Table {
  IntColumn get id => integer()();
  IntColumn get active => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One row naming which sync run currently owns the database.
///
/// The in-flight futures on `SyncService` only see one isolate. The
/// WorkManager task runs in another, with its own connection to the same file,
/// and a push running in both at once POSTs the same pending rows twice. A row
/// in the database is the one thing both can see. [expiresAt] (epoch millis)
/// lets a run that crashed without releasing it stop blocking anyone.
class SyncLeaseTable extends Table {
  IntColumn get id => integer()();
  TextColumn get holder => text().nullable()();
  IntColumn get expiresAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// What the sync engine remembers between pulls: where the changes feed
/// (`GET api/Sync/changes`) left off.
///
/// One row (id 1), or none before the first pull has applied a whole answer.
/// It lives in the database, beside the data it describes, so that the one
/// call that empties the data — `AppDatabase.clearAllUserData`, at sign-out —
/// empties it too. A cursor that outlived its data would tell the next pull
/// that this device already holds everything up to it, and the next account
/// to sign in would start from someone else's position in someone else's
/// history. See `docs/sync-architecture.md`, part three.
class SyncMeta extends Table {
  IntColumn get id => integer()();

  /// The `cursor` of the last changes-feed answer this device applied whole,
  /// exactly as the server sent it; the next pull sends it back as `since`.
  TextColumn get changesCursor => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
