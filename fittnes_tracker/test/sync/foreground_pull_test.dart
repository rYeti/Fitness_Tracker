import 'dart:async';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/dao/meal_template_dao.dart';
import 'package:ForgeForm/core/sync/foreground_pull.dart';
import 'package:ForgeForm/core/sync/sync_service.dart';
import 'package:ForgeForm/feature/auth/presentation/providers/auth_provider.dart'
    show lastPullPrefsKey;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

/// Part four of the sync rework, the phone's half: a `sync_requested` push
/// received in the foreground pulls now, skipping the interval a launch or
/// resume keeps, but not the lease or the in-flight join. See
/// `docs/sync-architecture.md`, part four.
///
/// Each test was run with the one rule it pins taken out, and failed there.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeApiClient api;
  late ForegroundPull pull;

  setUp(() {
    SyncService.resetForTesting();
    db = AppDatabase.test(NativeDatabase.memory());
    api = FakeApiClient()..stubEmptyPull();
    pull = ForegroundPull(
      service: () async => SyncService(
        db: db,
        apiClient: api,
        mealTemplateDao: MealTemplateDao(db),
      ),
    );
  });

  tearDown(() => db.close());

  /// A pull finished a moment ago, as if the app had just been resumed.
  void pulledJustNow() => SharedPreferences.setMockInitialValues({
    lastPullPrefsKey: DateTime.now().millisecondsSinceEpoch,
  });

  test('a resume inside the interval does not pull', () async {
    pulledJustNow();

    expect(await pull.run(), isFalse);
    expect(api.changesSince, isEmpty);
  });

  test('a sync_requested pulls even inside the interval', () async {
    pulledJustNow();

    expect(await pull.run(requested: true), isTrue);
    expect(api.changesSince, hasLength(1));
  });

  test(
    'a sync_requested during a pull already running waits for it, then pulls '
    'again',
    () async {
      SharedPreferences.setMockInitialValues({});

      // A resume's pull, whose request reached the server before the trainer
      // saved — its answer is still on the way back.
      api.holdChanges = Completer<void>();
      final resume = pull.run();
      while (api.changesSince.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }

      // The trainer's edit lands, and the server says so.
      api.changes['weights'] = [
        {
          'id': 'weight-from-trainer',
          'date': '2026-01-05T00:00:00Z',
          'weight': 81.5,
          'note': null,
        },
      ];
      final requested = pull.run(requested: true);
      await Future<void>.delayed(Duration.zero);
      api.holdChanges!.complete();
      await Future.wait([resume, requested]);

      // Joining the resume's pull would have answered the request with an
      // answer from before the edit.
      expect(api.changesSince, hasLength(2));
      final weights = await db.select(db.weightRecord).get();
      expect(weights.map((w) => w.serverId), ['weight-from-trainer']);
    },
  );
}
