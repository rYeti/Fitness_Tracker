import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/providers/user_goals_provider.dart';
import 'package:ForgeForm/feature/weight_tracking/presentation/providers/weight_provider.dart';

/// A load failure used to be logged and then dropped, leaving the record list
/// empty — so the screen rendered its *empty state* and told the user they had
/// never logged a weight. The failure and the genuinely-empty case were
/// indistinguishable downstream, which is the property these tests pin.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.test(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<WeightProvider> settled() async {
    final provider = WeightProvider(db, userGoalsProvider: UserGoalsProvider(db));
    // The constructor kicks off a load; let it finish before asserting.
    await Future<void>.delayed(Duration.zero);
    return provider;
  }

  test('a successful empty load is not an error', () async {
    final provider = await settled();

    expect(provider.weightRecords, isEmpty);
    expect(
      provider.hasError,
      isFalse,
      reason: 'no records is a legitimate state, not a failure — the screen '
          'shows its empty state for this and only this',
    );
  });

  test('records load into the list', () async {
    final provider = await settled();
    await provider.addWeightRecord(date: DateTime(2026, 8, 1), weight: 82.4);

    expect(provider.weightRecords, hasLength(1));
    expect(provider.hasError, isFalse);
  });

  test('the failure and empty states are distinguishable', () async {
    final provider = await settled();

    // The screen branches on these three in order: loading, error, empty.
    // If hasError could never be true, the error branch is unreachable and
    // a failed load falls through to "no records yet" — the original bug.
    expect(provider.isLoading, isFalse);
    expect(provider.hasError, isFalse);
    expect(provider.weightRecords, isEmpty);

    // retry() is what the error state's action calls; it has to exist and be
    // safe to invoke from a settled state.
    await provider.retry();
    expect(provider.hasError, isFalse);
    expect(provider.isLoading, isFalse);
  });
}
