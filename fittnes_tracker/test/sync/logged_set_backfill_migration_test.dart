import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/app_database.dart';

/// The one-off backfill in `onUpgrade`'s `if (from < 40)` branch.
///
/// RPE, set type and side were stored on logged sets from schema 35 but never
/// pushed, so a set that synced before 40 is marked synced while holding values
/// the server has never seen. Nothing on the pull side can notice — it skips a
/// set it already holds — so the upgrade re-queues exactly those rows.
///
/// Uses a file for the same reason as `chat_outbox_migration_test.dart`: an
/// in-memory database always takes `onCreate`, and `onUpgrade` never runs.
void main() {
  late Directory tempDir;
  late File file;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('forgeform_set_backfill');
    file = File('${tempDir.path}/app.sqlite');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  /// A version-39 install holding one logged set per row in [sets], each given
  /// as `(serverId, syncStatus, rpe, setType, side)`.
  Future<void> givenAnInstallAt39(
    List<(String?, int, int?, int, int)> sets,
  ) async {
    final old = AppDatabase.test(NativeDatabase(file));
    await old.customStatement('SELECT 1');
    var setNumber = 1;
    for (final (serverId, syncStatus, rpe, setType, side) in sets) {
      await old.customStatement(
        'INSERT INTO workout_set_table '
        '(scheduled_workout_exercise_id, set_number, is_completed, server_id, '
        'sync_status, rpe, set_type, side) VALUES (1, ?, 1, ?, ?, ?, ?, ?)',
        [setNumber++, serverId, syncStatus, rpe, setType, side],
      );
    }
    await old.customStatement('PRAGMA user_version = 39');
    await old.close();
  }

  Future<Map<int, int>> syncStatusBySetNumber(AppDatabase db) async {
    final rows = await db.select(db.workoutSetTable).get();
    return {for (final r in rows) r.setNumber: r.syncStatus};
  }

  test(
    'a synced set carrying an RPE, set type or side is queued for pushing',
    () async {
      await givenAnInstallAt39([
        ('s1', 1, 8, 0, 0), // RPE
        ('s2', 1, null, 1, 0), // warm-up
        ('s3', 1, null, 0, 2), // right side
        ('s4', 1, null, 0, 0), // nothing to send
      ]);

      final db = AppDatabase.test(NativeDatabase(file));
      addTearDown(db.close);

      expect(await syncStatusBySetNumber(db), {1: 2, 2: 2, 3: 2, 4: 1});
    },
  );

  test(
    'a set that never synced, or is being deleted, is left as it was',
    () async {
      await givenAnInstallAt39([
        // Not on the server yet: the create push will carry the values anyway,
        // and turning it into an update would send a PUT with no server id.
        (null, 0, 8, 1, 0),
        // Queued for deletion: re-flagging it as an edit would bring it back.
        ('s2', 3, 8, 1, 0),
      ]);

      final db = AppDatabase.test(NativeDatabase(file));
      addTearDown(db.close);

      expect(await syncStatusBySetNumber(db), {1: 0, 2: 3});
    },
  );

  test(
    'schemaVersion stays ahead of the last version without the backfill',
    () async {
      final db = AppDatabase.test(NativeDatabase.memory());
      addTearDown(db.close);

      expect(db.schemaVersion, greaterThan(39));
    },
  );
}
