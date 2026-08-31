import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/database/daos/workout_plan_dao.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/providers/workout_provider.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout_plan.dart';

/// `loadCompletePlans` used to wrap its work in `try { … } finally { … }`.
/// A `finally` restores the loading flag and lets the exception keep going, so
/// a throw left `plans` empty, `loading` false, and no record that anything had
/// gone wrong. The list view read that as the empty case and rendered "No
/// workouts found" with a Create-your-first-workout button — telling a trainee
/// their training history was gone when the truth was that nobody had been
/// able to read it.
///
/// Nothing about that is visible in the type system: both paths end with an
/// empty list, which is a perfectly good value. The distinction has to be
/// carried deliberately, which is what `error` is for. Same defect and same
/// fix as weight_provider_states_test.dart pins for WeightProvider.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.test(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('a successful empty load is not an error', () async {
    final provider = WorkoutProvider(
      dao: db.workoutDao,
      planDao: db.workoutPlanDao,
    );
    await provider.loadCompletePlans();

    expect(provider.plans, isEmpty);
    expect(
      provider.error,
      isNull,
      reason: 'no plans yet is a real answer, not a failure',
    );
    expect(provider.loading, isFalse);
  });

  test('a failed load is distinguishable from an empty one', () async {
    final provider = WorkoutProvider(
      dao: db.workoutDao,
      planDao: _FailingPlanDao(db),
    );

    await provider.loadCompletePlans();

    expect(provider.plans, isEmpty, reason: 'still empty, as before');
    expect(
      provider.error,
      isNotNull,
      reason: 'but now the screen can tell the two apart',
    );
    expect(
      provider.loading,
      isFalse,
      reason: 'and the spinner still stops — the finally did that much right',
    );
  });

  test('a retry clears the previous error', () async {
    final failing = _FailingPlanDao(db);
    final provider = WorkoutProvider(dao: db.workoutDao, planDao: failing);

    await provider.loadCompletePlans();
    expect(provider.error, isNotNull);

    failing.shouldFail = false;
    await provider.loadCompletePlans();

    expect(
      provider.error,
      isNull,
      reason: 'a stale error would keep the retry button on screen forever',
    );
  });
}

/// Fails on demand, so the recovery path is reachable too.
class _FailingPlanDao extends WorkoutPlanDao {
  bool shouldFail = true;

  _FailingPlanDao(super.db);

  @override
  Future<List<WorkoutPlanTableData>> getAllPlans() async {
    if (shouldFail) throw StateError('database unavailable');
    return super.getAllPlans();
  }
}
