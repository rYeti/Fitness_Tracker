import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/providers/access_provider.dart';
import 'package:ForgeForm/core/providers/user_goals_provider.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:ForgeForm/feature/onboarding/profile_setup_prefs.dart';
import 'package:ForgeForm/main.dart';

/// Profile setup is a personal-fitness questionnaire. Showing it to a trainer
/// is the bug this gate exists to prevent, so each branch is pinned here.
Future<void> _pump(
  WidgetTester tester, {
  required String? userId,
  required AccessProvider access,
}) async {
  // ProfileSetupScreen reads the database and goals provider, and is
  // localised — the gate has to be able to actually build it.
  final db = AppDatabase();
  addTearDown(db.close);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AccessProvider>.value(value: access),
        Provider<AppDatabase>.value(value: db),
        ChangeNotifierProvider(create: (_) => UserGoalsProvider(db)),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: ProfileSetupGate(
          userId: userId,
          onDone: (_) => const Scaffold(body: Text('destination')),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ProfileSetupPrefs', () {
    test('is per account, not per device', () async {
      await ProfileSetupPrefs.markComplete('alice');

      expect(await ProfileSetupPrefs.isComplete('alice'), isTrue);
      expect(await ProfileSetupPrefs.isComplete('bob'), isFalse);
    });

    test('honours the legacy device flag so existing users are not re-asked',
        () async {
      SharedPreferences.setMockInitialValues({'onboarding_complete': true});

      expect(await ProfileSetupPrefs.isComplete('alice'), isTrue);
    });

    test('adopts the legacy flag so the answer stops depending on it',
        () async {
      SharedPreferences.setMockInitialValues({'onboarding_complete': true});
      await ProfileSetupPrefs.isComplete('alice');

      // Legacy key gone; the per-account answer must survive.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('onboarding_complete');
      expect(await ProfileSetupPrefs.isComplete('alice'), isTrue);
    });
  });

  group('ProfileSetupGate', () {
    testWidgets('a trainer is never shown the trainee questionnaire', (
      tester,
    ) async {
      await _pump(
        tester,
        userId: 'coach',
        access: AccessProvider.withState(isTrainer: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('destination'), findsOneWidget);
    });

    testWidgets('waits rather than guessing while the role is unresolved', (
      tester,
    ) async {
      await _pump(
        tester,
        userId: 'coach',
        // The state a trainer is in on a first sign-in: no cached role yet.
        access: AccessProvider.withState(isTrainer: false, roleResolved: false),
      );
      await tester.pumpAndSettle();

      // Falls through to the app rather than showing setup on a guess.
      expect(find.text('destination'), findsOneWidget);
    });

    testWidgets('a new trainee is sent through setup', (tester) async {
      await _pump(
        tester,
        userId: 'alice',
        access: AccessProvider.withState(isTrainer: false),
      );
      await tester.pumpAndSettle();

      expect(find.text('destination'), findsNothing);
      expect(find.text('Set up later'), findsOneWidget);
    });

    testWidgets('a trainee who already finished goes straight through', (
      tester,
    ) async {
      await ProfileSetupPrefs.markComplete('alice');

      await _pump(
        tester,
        userId: 'alice',
        access: AccessProvider.withState(isTrainer: false),
      );
      await tester.pumpAndSettle();

      expect(find.text('destination'), findsOneWidget);
    });

    testWidgets('no signed-in user falls through', (tester) async {
      await _pump(
        tester,
        userId: null,
        access: AccessProvider.withState(isTrainer: false),
      );
      await tester.pumpAndSettle();

      expect(find.text('destination'), findsOneWidget);
    });

    testWidgets('"Set up later" records completion so it stops asking', (
      tester,
    ) async {
      await _pump(
        tester,
        userId: 'alice',
        access: AccessProvider.withState(isTrainer: false),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set up later'));
      await tester.pumpAndSettle();

      expect(find.text('destination'), findsOneWidget);
      expect(await ProfileSetupPrefs.isComplete('alice'), isTrue);
    });
  });
}
