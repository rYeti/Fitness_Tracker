import 'package:drift/drift.dart';
import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/seed_exercises_data.dart';
import 'package:ForgeForm/core/utils/app_logger.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/exercise.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kSeedVersionKey = 'exercise_seed_version';

/// Populates the exercise table from the bundled seed data, and repairs rows
/// that predate a translation/description pass.
///
/// Gated on [kExerciseSeedVersion]: once a version has been applied this
/// returns after a single prefs read, without querying the database or even
/// materialising [kSeedExercises]. Previously every launch paid two full
/// 873-row table scans plus a per-row write loop, on the awaited startup path.
///
/// Still awaited in `main()`: with the gate the steady-state cost is
/// negligible, and it guarantees the table is populated before SyncService
/// starts matching server exercises against local ones by name.
Future<void> seedExercisesIfEmpty(AppDatabase db) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getInt(_kSeedVersionKey) ?? 0) >= kExerciseSeedVersion) return;

    // Cheap existence check — hydrating every row just to ask "any?" was the
    // first of the two scans.
    final count =
        await (db.selectOnly(db.exerciseTable)
              ..addColumns([db.exerciseTable.id.count()]))
            .map((row) => row.read(db.exerciseTable.id.count()) ?? 0)
            .getSingle();

    if (count == 0) {
      await _insertAll(db);
    } else {
      final existing = await db.exerciseDao.getAllExercises();
      await _backfillTranslations(db, existing);
      await _insertMissing(db, existing.map((e) => e.name).toSet());
    }

    await prefs.setInt(_kSeedVersionKey, kExerciseSeedVersion);
    AppLogger.i('Exercise seed applied (v$kExerciseSeedVersion)');
  } catch (e, st) {
    AppLogger.e('Exercise seed failed', e, st);
  }
}

Future<void> _insertAll(AppDatabase db) => _insert(db, kSeedExercises);

/// Inserts any seed exercise that is not yet present in the local DB.
/// Runs after the backfill so new exercises also get their German name.
Future<void> _insertMissing(AppDatabase db, Set<String> existingNames) {
  final missing =
      kSeedExercises.where((e) => !existingNames.contains(e.name)).toList();
  if (missing.isEmpty) return Future.value();
  return _insert(db, missing);
}

/// One batch rather than a write per exercise — 873 individual inserts each
/// took their own implicit transaction.
///
/// Built-in exercises are the server's rows, not this device's: each one's id
/// is the server's, stamped when `SyncService` matches it by name. So they are
/// inserted without one, where every other row gets a fresh id of its own.
Future<void> _insert(AppDatabase db, List<Exercise> exercises) {
  return db.batch((batch) {
    batch.insertAll(
      db.exerciseTable,
      [
        for (final e in exercises)
          db.exerciseDao.modelToEntity(e).copyWith(serverId: const Value(null)),
      ],
      mode: InsertMode.insertOrReplace,
    );
  });
}

/// Updates any pre-existing exercise that is missing translations or
/// description, matched by English name. Custom exercises are never touched.
///
/// Takes the rows the caller already fetched — re-querying them here was the
/// second full table scan.
Future<void> _backfillTranslations(
  AppDatabase db,
  List<ExerciseTableData> all,
) async {
  final needsUpdate =
      all
          .where(
            (e) =>
                (e.nameDe == null ||
                    e.descriptionDe == null ||
                    e.description == null) &&
                !e.isCustom,
          )
          .toList();
  if (needsUpdate.isEmpty) return;

  final translationMap = {
    for (final ex in kSeedExercises)
      ex.name: (
        nameDe: ex.nameDe,
        descriptionDe: ex.descriptionDe,
        description: ex.description,
      ),
  };

  await db.batch((batch) {
    for (final row in needsUpdate) {
      final t = translationMap[row.name];
      if (t == null) continue;
      batch.update(
        db.exerciseTable,
        ExerciseTableCompanion(
          nameDe: Value(t.nameDe),
          descriptionDe: Value(t.descriptionDe),
          description: Value(t.description),
        ),
        where: (e) => e.id.equals(row.id),
      );
    }
  });
}
