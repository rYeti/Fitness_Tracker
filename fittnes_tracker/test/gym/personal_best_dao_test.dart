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
    int? swappedFor,
    int? underWorkout,
    int? underPlan,
    required List<({double? weight, int? reps, SetType type})> sets,
  }) async {
    final onWorkoutId = underWorkout ?? workoutId;
    final workoutExerciseId = await db
        .into(db.workoutExerciseTable)
        .insert(
          WorkoutExerciseTableCompanion.insert(
            workoutId: onWorkoutId,
            exerciseId: exerciseId,
            orderPosition: 0,
          ),
        );
    final scheduledId = await db
        .into(db.scheduledWorkoutTable)
        .insert(
          ScheduledWorkoutTableCompanion.insert(
            workoutId: onWorkoutId,
            scheduledDate: date,
            isCompleted: Value(completed),
            workoutPlanId: Value(underPlan),
          ),
        );
    final scheduledExerciseId = await db
        .into(db.scheduledWorkoutExerciseTable)
        .insert(
          ScheduledWorkoutExerciseTableCompanion.insert(
            scheduledWorkoutId: scheduledId,
            workoutExerciseId: workoutExerciseId,
            // The plan said [exerciseId]; on the day it was swapped for this.
            overrideExerciseId: Value(swappedFor),
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

  Future<int> addWorkout(String name) => db
      .into(db.workoutTable)
      .insert(WorkoutTableCompanion.insert(name: name, difficulty: 2));

  Future<int> addPlan(String name) => db
      .into(db.workoutPlanTable)
      .insert(
        WorkoutPlanTableCompanion.insert(
          name: name,
          startDate: DateTime(2026, 1, 1),
          cyclePatternJson: '[]',
        ),
      );

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

  test('a swapped-out exercise credits the one actually performed', () async {
    final bench = await addExercise('Bench Press');
    final dumbbell = await addExercise('Dumbbell Press');
    await logSession(
      exerciseId: bench,
      date: DateTime(2026, 8, 1),
      swappedFor: dumbbell,
      sets: [set(40, 8)],
    );

    // The plan said Bench Press; the trainee did Dumbbell Press. 40 kg is not
    // a bench PB, and Bench must not inherit it.
    final bests = await db.workoutDao.getAllTimeBestSets();
    expect(bests[dumbbell], (weight: 40.0, reps: 8));
    expect(bests.containsKey(bench), isFalse);
  });

  test('a set logged without reps is not a personal best', () async {
    final squat = await addExercise('Back Squat');
    await logSession(
      exerciseId: squat,
      date: DateTime(2026, 8, 1),
      sets: [set(180, null), set(120, 5)],
    );

    // 180 kg for an unrecorded number of reps is a half-filled row, not a
    // lift — otherwise it renders as "180 kg × 0 reps".
    expect((await db.workoutDao.getAllTimeBestSets())[squat], (
      weight: 120.0,
      reps: 5,
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

  /// The plan-scoped best is the one a trainee means by "my best on this
  /// programme": wider than the day they are standing in, narrower than their
  /// whole training history. Both boundaries are invisible to the type system
  /// — all three numbers are the same record type — so they are pinned here.
  group('plan-scoped bests', () {
    test('span every workout of the plan, not just the one being performed',
        () async {
      final bench = await addExercise('Bench Press');
      final plan = await addPlan('Upper/Lower');
      final upperA = await addWorkout('Upper A');
      final upperB = await addWorkout('Upper B');

      await logSession(
        exerciseId: bench,
        date: DateTime(2026, 8, 3),
        underWorkout: upperA,
        underPlan: plan,
        sets: [set(95, 5)],
      );
      await logSession(
        exerciseId: bench,
        date: DateTime(2026, 8, 6),
        underWorkout: upperB,
        underPlan: plan,
        sets: [set(105, 3)],
      );

      // Standing in Upper A, the best on the programme is the Upper B set.
      // Scoping this to the workout on screen is the bug this exists to stop.
      final bests = await db.workoutDao.getPlanBestSets(
        planId: plan,
        workoutId: upperA,
        exerciseIds: [bench],
      );
      expect(bests[bench], (weight: 105.0, reps: 3));
    });

    test('stop at the plan boundary while the all-time best does not',
        () async {
      final bench = await addExercise('Bench Press');
      final oldPlan = await addPlan('Last Block');
      final plan = await addPlan('This Block');
      final upperA = await addWorkout('Upper A');

      await logSession(
        exerciseId: bench,
        date: DateTime(2026, 2, 1),
        underWorkout: upperA,
        underPlan: oldPlan,
        sets: [set(120, 1)],
      );
      await logSession(
        exerciseId: bench,
        date: DateTime(2026, 8, 3),
        underWorkout: upperA,
        underPlan: plan,
        sets: [set(100, 5)],
      );

      // Same exercise, same workout row, two programmes. The peak from the
      // last block is still the all-time PB and is still not this block's.
      expect(
        (await db.workoutDao.getPlanBestSets(
          planId: plan,
          workoutId: upperA,
          exerciseIds: [bench],
        ))[bench],
        (weight: 100.0, reps: 5),
      );
      expect((await db.workoutDao.getAllTimeBestSets())[bench], (
        weight: 120.0,
        reps: 1,
      ));
    });

    test('fall back to the workout when the session belongs to no plan',
        () async {
      final bench = await addExercise('Bench Press');
      final upperA = await addWorkout('Upper A');
      final upperB = await addWorkout('Upper B');

      await logSession(
        exerciseId: bench,
        date: DateTime(2026, 8, 3),
        underWorkout: upperA,
        sets: [set(100, 5)],
      );
      await logSession(
        exerciseId: bench,
        date: DateTime(2026, 8, 6),
        underWorkout: upperB,
        sets: [set(110, 2)],
      );

      // A null plan id must not read as "no filter at all", which would make
      // the plan best silently equal to the all-time best.
      final bests = await db.workoutDao.getPlanBestSets(
        planId: null,
        workoutId: upperA,
        exerciseIds: [bench],
      );
      expect(bests[bench], (weight: 100.0, reps: 5));
    });

    test('apply every rule the all-time best applies', () async {
      final squat = await addExercise('Back Squat');
      final plan = await addPlan('This Block');
      final legs = await addWorkout('Legs');

      await logSession(
        exerciseId: squat,
        date: DateTime(2026, 8, 1),
        underWorkout: legs,
        underPlan: plan,
        sets: [set(200, 1, type: SetType.warmup), set(180, null)],
      );
      await logSession(
        exerciseId: squat,
        date: DateTime(2026, 8, 4),
        underWorkout: legs,
        underPlan: plan,
        completed: false,
        sets: [set(190, 3)],
      );
      await logSession(
        exerciseId: squat,
        date: DateTime(2026, 8, 8),
        underWorkout: legs,
        underPlan: plan,
        sets: [set(140, 5), set(140, 8)],
      );

      // A warmup, a repless row and an abandoned session are not personal
      // bests here either — the two queries share a body precisely so this
      // list cannot drift apart from the all-time one.
      expect(
        (await db.workoutDao.getPlanBestSets(
          planId: plan,
          workoutId: legs,
          exerciseIds: [squat],
        ))[squat],
        (weight: 140.0, reps: 8),
      );
    });

    test('credit a swapped-out exercise to the one actually performed',
        () async {
      final bench = await addExercise('Bench Press');
      final dumbbell = await addExercise('Dumbbell Press');
      final plan = await addPlan('This Block');
      final upperA = await addWorkout('Upper A');

      await logSession(
        exerciseId: bench,
        date: DateTime(2026, 8, 3),
        underWorkout: upperA,
        underPlan: plan,
        swappedFor: dumbbell,
        sets: [set(40, 8)],
      );

      final bests = await db.workoutDao.getPlanBestSets(
        planId: plan,
        workoutId: upperA,
      );
      expect(bests[dumbbell], (weight: 40.0, reps: 8));
      expect(bests.containsKey(bench), isFalse);
    });

    test('an empty id list still asks for nothing', () async {
      final bench = await addExercise('Bench Press');
      final plan = await addPlan('This Block');
      final upperA = await addWorkout('Upper A');
      await logSession(
        exerciseId: bench,
        date: DateTime(2026, 8, 3),
        underWorkout: upperA,
        underPlan: plan,
        sets: [set(100, 3)],
      );

      expect(
        await db.workoutDao.getPlanBestSets(
          planId: plan,
          workoutId: upperA,
          exerciseIds: [],
        ),
        isEmpty,
      );
    });
  });

  /// The same ordering the SQL spells as `ORDER BY weight DESC, reps DESC`,
  /// in the form the widget layer uses it — once to pick the best of the sets
  /// being typed, once to merge that with what the database already holds.
  group('the comparison itself', () {
    test('heavier always wins, however few the reps', () {
      expect(
        beatsPersonalBest((weight: 105.0, reps: 1), (weight: 100.0, reps: 10)),
        isTrue,
      );
      expect(
        beatsPersonalBest((weight: 100.0, reps: 10), (weight: 105.0, reps: 1)),
        isFalse,
      );
    });

    test('reps break a tie on weight and nothing else', () {
      expect(
        beatsPersonalBest((weight: 100.0, reps: 6), (weight: 100.0, reps: 5)),
        isTrue,
      );
      expect(
        beatsPersonalBest((weight: 100.0, reps: 5), (weight: 100.0, reps: 5)),
        isFalse,
      );
    });

    test('bestOf carries an absent side through instead of losing the other',
        () {
      const pb = (weight: 100.0, reps: 5);
      expect(bestOf(null, pb), pb);
      expect(bestOf(pb, null), pb);
      expect(bestOf(null, null), isNull);
      expect(bestOf(pb, (weight: 102.5, reps: 3)), (weight: 102.5, reps: 3));
    });
  });
}
