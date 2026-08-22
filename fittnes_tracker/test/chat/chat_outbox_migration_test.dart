import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/app_database.dart';

const _otherParty = '22222222-2222-2222-2222-222222222222';

/// The upgrade path, which every other test in this suite skips.
///
/// `newTestDatabase()` builds a fresh `NativeDatabase.memory()` per test, so it
/// always takes drift's `onCreate` branch — and `onCreate` calls `createAll()`,
/// which creates whatever tables are currently declared. That makes a missing
/// `schemaVersion` bump structurally invisible: every test passes, every fresh
/// install works, and every device that already had the app is broken.
///
/// `chat_out_box_table` shipped exactly that way. `onUpgrade` only runs when the
/// stored `user_version` is behind `schemaVersion`, so on an install that
/// predated the table nothing ever created it, `insertMessagePending` threw
/// before the message reached the network, and chat was dead in both directions
/// with nothing on screen to say why.
///
/// So these tests use a **file**, not memory: `user_version` is a property of a
/// database that persists across opens, and standing in for "a device that has
/// had this app installed for months" needs one that survives being closed.
void main() {
  late Directory tempDir;
  late File file;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('forgeform_migration');
    file = File('${tempDir.path}/app.sqlite');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  /// Leaves [file] in the state a long-lived install was in before this fix:
  /// every other table present and populated, no chat outbox, and a
  /// `user_version` from before the outbox was added.
  ///
  /// [seed] runs against the "old" database, so a test can put rows in the
  /// tables the upgrade must not disturb.
  Future<void> givenAnInstallFromBeforeTheOutbox({
    Future<void> Function(AppDatabase db)? seed,
  }) async {
    final old = AppDatabase.test(NativeDatabase(file));
    // Nothing is opened or built until a statement actually runs.
    await old.customStatement('SELECT 1');
    if (seed != null) await seed(old);

    await old.customStatement('DROP TABLE IF EXISTS chat_out_box_table');
    await old.customStatement('PRAGMA user_version = 36');
    await old.close();
  }

  test('an install that predates the chat outbox gets the table on upgrade',
      () async {
    await givenAnInstallFromBeforeTheOutbox();

    final db = AppDatabase.test(NativeDatabase(file));
    addTearDown(db.close);

    // The assertion is the whole point: this is the exact call that threw
    // "no such table: chat_out_box_table" on every send from an upgraded app,
    // before onQueued fired and before anything touched the network.
    await db.chatoutboxDao.insertMessagePending(
      ChatOutBoxTableCompanion.insert(
        messageId: 'after-upgrade',
        otherPartyId: _otherParty,
        body: 'did the migration run?',
        createdAt: DateTime.utc(2026, 8, 22),
        chatMessageStatus: Value(ChatMessageStatus.pending.index),
      ),
    );

    final pending = await db.chatoutboxDao.getPendingMessages(_otherParty);
    expect(pending.single.body, 'did the migration run?');
  });

  test('the upgrade leaves rows in the other tables alone', () async {
    await givenAnInstallFromBeforeTheOutbox(
      seed: (old) => old.into(old.weightRecord).insert(
            WeightRecordCompanion.insert(
              date: DateTime.utc(2026, 8, 1),
              weight: 82.5,
            ),
          ),
    );

    final db = AppDatabase.test(NativeDatabase(file));
    addTearDown(db.close);

    // createAll() in onUpgrade emits CREATE TABLE IF NOT EXISTS, so it adds what
    // is missing without touching what is already there. That property is what
    // makes the one-line version bump a complete fix rather than a data loss.
    final weights = await db.select(db.weightRecord).get();
    expect(weights.single.weight, 82.5);
  });

  test('schemaVersion stays ahead of the version the outbox shipped without',
      () async {
    // A guard on the fix itself. 36 is the version that shipped without the
    // outbox; dropping back to it — or to anything at or below it — silently
    // reintroduces the bug for every install that already exists, while leaving
    // fresh installs and this entire test suite green.
    final db = AppDatabase.test(NativeDatabase.memory());
    addTearDown(db.close);

    expect(db.schemaVersion, greaterThan(36));
  });
}
