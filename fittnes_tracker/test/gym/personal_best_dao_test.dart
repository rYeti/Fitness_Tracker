import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout_set.dart'
    show SetType;

/// A personal best is one set that actually happened, and every filter that
/// decides which sets count lives in SQL where no widget test would ever reach
/// it. These pin the boundaries: a warmup is not a PB, an abandoned session is
/// not a PB, and the reps travel with the weight they were lifted at rather
/// than being maxed separately.
void main() {
  late AppDatabase db;
  late int workoutId;

  setUp(() async {
    db = AppDatabase.test(NativeDatabase.memory());
    workoutId = await db
        .into(db.workoutTable)
        .insert(WorkoutTableCompanion.insert(name: 'Push A', difficulty: 2));
  });
  tearDown(() => db.close());

  Future<int> addExercise(String name) => db
      .into(db.exerciseTable)
      .insert(
        ExerciseTableCompanion.insert(
          name: name,
          type: 0,
          targetMuscleGroups: 'Chest',
        ),
      );

  /// Puts one session of [sets] on the calendar for [exerciseId] and returns
  /// the exercise id, so a test reads as a training history rather than as
  /// five inserts.
  Future<void> logSession({
    required int exerciseId,
    required DateTime date,
    bool completed = true,
    required List<({double? weight, int? reps, SetType type})> sets,
  }) async {
    final workoutExerciseId = await db
        .into(db.workoutExerciseTable)
        .insert(
          WorkoutExerciseTableCompanion.insert(
            workoutId: workoutId,
            exerciseId: exerciseId,
            orderPosition: 0,
          ),
        );
    final scheduledId = await db
        .into(db.scheduledWorkoutTable)
        .insert(
          ScheduledWorkoutTableCompanion.insert(
            workoutId: workoutId,
            scheduledDate: date,
            isCompleted: Value(completed),
          ),
        );
    final scheduledExerciseId = await db
        .into(db.scheduledWorkoutExerciseTable)
        .insert(
          ScheduledWorkoutExerciseTableCompanion.insert(
            scheduledWorkoutId: scheduledId,
            workoutExerciseId: workoutExerciseId,
          ),
        );
    for (var i = 0; i < sets.length; i++) {
      await db
          .into(db.workoutSetTable)
          .insert(
            WorkoutSetTableCompanion.insert(
              scheduledWorkoutExerciseId: scheduledExerciseId,
              setNumber: i + 1,
              weight: Value(sets[i].weight),
              reps: Value(sets[i].reps),
              setType: Value(sets[i].type.index),
            ),
          );
    }
  }

  ({double? weight, int? reps, SetType type}) set(
    double? weight,
    int? reps, {
    SetType type = SetType.normal,
  }) => (weight: weight, reps: reps, type: type);

  test('returns the heaviest set, with the reps it was lifted at', () async {
    final bench = await addExercise('Bench Press');
    await logSession(
      exerciseId: bench,
      date: DateTime(2026, 8, 1),
      sets: [set(80, 10), set(100, 3), set(90, 6)],
    );

    final bests = await db.workoutDao.getAllTimeBestSets();

    // 3 reps, not the 10 from the lighter set: a PB is one set, never a best
    // weight welded to a best rep count from a different one.
    expect(bests[bench], (weight: 100.0, reps: 3));
  });

  test('spans every session and workout the exercise appears in', () async {
    final bench = await addExercise('Bench Press');
    await logSession(
      exerciseId: bench,
      date: DateTime(2024, 1, 5),
      sets: [set(110, 2)],
    );
    await logSession(
      exerciseId: bench,
      date: DateTime(2026, 8, 1),
      sets: [set(95, 5)],
    );

    // The heaviest ever, not the most recent — and reached through a second
    // WorkoutExercise row, which is what any trainer edit leaves behind.
    expect((await db.workoutDao.getAllTimeBestSets())[bench], (
      weight: 110.0,
      reps: 2,
    ));
  });

  test('excludes warmup sets', () async {
    final squat = await addExercise('Back Squat');
    await logSession(
      exerciseId: squat,
      date: DateTime(2026, 8, 1),
      sets: [set(140, 1, type: SetType.warmup), set(100, 5)],
    );

    expect((await db.workoutDao.getAllTimeBestSets())[squat], (
      weight: 100.0,
      reps: 5,
    ));
  });

  test('excludes sessions that were never completed', () async {
    final squat = await addExercise('Back Squat');
    await logSession(
      exerciseId: squat,
      date: DateTime(2026, 8, 1),
      completed: false,
      sets: [set(200, 1)],
    );
    await logSession(
      exerciseId: squat,
      date: DateTime(2026, 8, 8),
      sets: [set(120, 5)],
    );

    expect((await db.workoutDao.getAllTimeBestSets())[squat], (
      weight: 120.0,
      reps: 5,
    ));
  });

  test('breaks a tie on weight with the higher rep count', () async {
    final row = await addExercise('Barbell Row');
    await logSession(
      exerciseId: row,
      date: DateTime(2026, 8, 1),
      sets: [set(70, 8), set(70, 12), set(70, 5)],
    );

    expect((await db.workoutDao.getAllTimeBestSets())[row], (
      weight: 70.0,
      reps: 12,
    ));
  });

  test('an exercise with no weighted set is absent, not zero', () async {
    final pullUp = await addExercise('Pull-Up');
    await logSession(
      exerciseId: pullUp,
      date: DateTime(2026, 8, 1),
      sets: [set(null, 12)],
    );

    // "No PB yet" and "a PB of 0 kg" render differently, so they must not
    // collapse into the same map entry here.
    expect(
      (await db.workoutDao.getAllTimeBestSets()).containsKey(pullUp),
      isFalse,
    );
  });

  test('one call answers for several exercises, and only those asked for',
      () async {
    final bench = await addExercise('Bench Press');
    final squat = await addExercise('Back Squat');
    final row = await addExercise('Barbell Row');
    await logSession(
      exerciseId: bench,
      date: DateTime(2026, 8, 1),
      sets: [set(100, 3)],
    );
    await logSession(
      exerciseId: squat,
      date: DateTime(2026, 8, 2),
      sets: [set(150, 5)],
    );
    await logSession(
      exerciseId: row,
      date: DateTime(2026, 8, 3),
      sets: [set(70, 10)],
    );

    final bests = await db.workoutDao.getAllTimeBestSets(
      exerciseIds: [bench, squat],
    );

    expect(bests.keys.toSet(), {bench, squat});
    expect(bests[bench], (weight: 100.0, reps: 3));
    expect(bests[squat], (weight: 150.0, reps: 5));
  });

  test('an empty id list asks for nothing rather than for everything',
      () async {
    final bench = await addExercise('Bench Press');
    await logSession(
      exerciseId: bench,
      date: DateTime(2026, 8, 1),
      sets: [set(100, 3)],
    );

    // The difference between "no exercises" and "all exercises" is one `?`
    // placeholder list that would otherwise be empty and match everything.
    expect(await db.workoutDao.getAllTimeBestSets(exerciseIds: []), isEmpty);
    expect(await db.workoutDao.getAllTimeBestSets(), isNotEmpty);
  });
}
