import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' show Database;

LazyDatabase connect() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'fittracker.sqlite'));
    return NativeDatabase.createInBackground(file, setup: _setup);
  });
}

/// The WorkManager task opens a second connection to this same file from its
/// own isolate. SQLite lets only one connection write at a time, and its
/// default is to fail a write that finds the file locked rather than wait —
/// so a save made while the background sync held a transaction threw
/// "database is locked". Waiting up to five seconds covers any transaction
/// this app runs.
void _setup(Database rawDb) {
  rawDb.execute('PRAGMA busy_timeout = 5000;');
}
