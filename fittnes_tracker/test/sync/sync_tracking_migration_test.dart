import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/app_database.dart';

/// Schema 41: `local_rev` on every synced table, the sync bookkeeping tables,
/// and the triggers installed from code on open — on a real upgrade, not only
/// on a fresh install, which is the one path every other test takes.
///
/// Uses a file for the same reason as `logged_set_backfill_migration_test.dart`:
/// an in-memory database always takes `onCreate`, and `onUpgrade` never runs.
void main() {
  late Directory tempDir;
  late File file;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('forgeform_sync_tracking');
    file = File('${tempDir.path}/app.sqlite');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  const trackedTables = [
    'exercise_table',
    'workout_table',
    'workout_exercise_table',
    'scheduled_workout_exercise_table',
    'scheduled_workout_table',
    'workout_plan_table',
    'food_item',
    'meal_table',
    'weight_record',
  ];

  /// A version-40 install: today's schema with everything 41 added taken out,
  /// holding one synced workout.
  Future<void> givenAnInstallAt40() async {
    final old = AppDatabase.test(NativeDatabase(file));
    await old.customStatement('SELECT 1');
    final triggers =
        await old
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'trigger'",
            )
            .get();
    for (final t in triggers) {
      await old.customStatement('DROP TRIGGER ${t.read<String>('name')}');
    }
    for (final table in [
      'sync_deletion_table',
      'sync_apply_guard_table',
      'sync_lease_table',
    ]) {
      await old.customStatement('DROP TABLE $table');
    }
    for (final table in trackedTables) {
      await old.customStatement('ALTER TABLE $table DROP COLUMN local_rev');
    }
    await old.customStatement(
      "INSERT INTO workout_table (name, difficulty, server_id, sync_status) "
      "VALUES ('Push Day', 0, 'server-w1', 1)",
    );
    await old.customStatement('PRAGMA user_version = 40');
    await old.close();
  }

  test('adds the columns and tables, and installs the triggers', () async {
    await givenAnInstallAt40();

    final db = AppDatabase.test(NativeDatabase(file));
    addTearDown(db.close);

    for (final table in trackedTables) {
      final columns = await db.customSelect('PRAGMA table_info($table)').get();
      expect(
        columns.map((c) => c.read<String>('name')),
        contains('local_rev'),
        reason: table,
      );
    }
    expect(await db.select(db.syncDeletionTable).get(), isEmpty);
    expect(await db.select(db.syncLeaseTable).get(), hasLength(1));

    // The existing synced workout is now tracked like any other.
    await db.customStatement(
      "UPDATE workout_table SET name = 'Push Day A' WHERE server_id = 'server-w1'",
    );
    final row = await db.select(db.workoutTable).getSingle();
    expect(row.syncStatus, SyncStatus.pendingUpdate.index);
    expect(row.localRev, 1);
  });

  test('opening again leaves the triggers as they are', () async {
    final first = AppDatabase.test(NativeDatabase(file));
    Future<List<String>> triggerSql(AppDatabase db) async => [
      for (final r
          in await db
              .customSelect(
                "SELECT sql FROM sqlite_master WHERE type = 'trigger' "
                'ORDER BY name',
              )
              .get())
        r.read<String>('sql'),
    ];
    final before = await triggerSql(first);
    await first.close();

    final second = AppDatabase.test(NativeDatabase(file));
    addTearDown(second.close);
    expect(await triggerSql(second), before);
    expect(before, isNotEmpty);
  });
}
