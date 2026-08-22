import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/seed_exercises.dart';
import 'package:ForgeForm/core/seed_exercises_data.dart';

/// The seeder used to do two full table scans and a per-row write loop on every
/// launch, on the awaited startup path. It's now gated on kExerciseSeedVersion
/// and batched — these pin the behaviour that gate has to preserve.
void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.test(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<int> exerciseCount() async =>
      (await db.exerciseDao.getAllExercises()).length;

  test('seeds every bundled exercise into an empty database', () async {
    await seedExercisesIfEmpty(db);

    expect(await exerciseCount(), kSeedExercises.length);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('exercise_seed_version'), kExerciseSeedVersion);
  });

  test('a second launch on the same version does no work', () async {
    await seedExercisesIfEmpty(db);
    await db.delete(db.exerciseTable).go();

    // The gate must short-circuit before touching the database at all — if it
    // re-seeded here, every launch would still be paying for the seed.
    await seedExercisesIfEmpty(db);
    expect(await exerciseCount(), 0);
  });

  test('backfills translations and inserts newly bundled exercises', () async {
    final seed = kSeedExercises.first;
    // A row as an older build left it: no German name, no description.
    await db
        .into(db.exerciseTable)
        .insert(
          ExerciseTableCompanion.insert(
            name: seed.name,
            type: seed.type.index,
            targetMuscleGroups: seed.targetMuscleGroups
                .map((mg) => mg.index.toString())
                .join(','),
          ),
        );
    // And one the user made themselves, which must never be rewritten.
    await db
        .into(db.exerciseTable)
        .insert(
          ExerciseTableCompanion.insert(
            name: 'Yeti Curl',
            type: seed.type.index,
            targetMuscleGroups: '0',
            isCustom: const Value(true),
          ),
        );

    await seedExercisesIfEmpty(db);

    final all = await db.exerciseDao.getAllExercises();
    // The pre-existing row was updated in place, not duplicated, and the rest
    // of the bundle was added alongside the custom exercise.
    expect(all.where((e) => e.name == seed.name), hasLength(1));
    expect(all, hasLength(kSeedExercises.length + 1));

    final backfilled = all.firstWhere((e) => e.name == seed.name);
    expect(backfilled.nameDe, seed.nameDe);
    expect(backfilled.description, seed.description);

    final custom = all.firstWhere((e) => e.name == 'Yeti Curl');
    expect(custom.isCustom, isTrue);
    expect(custom.nameDe, null);
  });
}
