import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/widgets/client_avatar.dart';
import 'package:ForgeForm/feature/dashboard/widgets/greeting_card.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// The greeting card put its avatar in a `Positioned` hanging off the top edge
/// of the card, inside a `Stack`. A Stack's whole job is to let its children
/// occupy the same space, so nothing in the layout system objected — and
/// nothing could, because "these two children overlap" is the feature. The
/// only place it showed was the screen, and only once the name was long enough
/// to run under the circle: "Good evening, Robert!" rendered with its first
/// letters behind the avatar.
///
/// That is the shape of bug worth testing here. Not "does the greeting
/// render" — it always rendered.
void main() {
  Future<void> pump(
    WidgetTester tester,
    String name, {
    int todayCalories = 2837,
    double calorieGoal = 2900,
    Size size = const Size(420, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: GreetingCard(
              name: name,
              todayCalories: todayCalories,
              calorieGoal: calorieGoal,
              weekCompleted: 1,
              weekTotal: 15,
              allTimeCompleted: 59,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the avatar does not overlap the greeting', (tester) async {
    await pump(tester, 'Robert');

    final avatar = tester.getRect(find.byType(ClientAvatar));
    final greeting = tester.getRect(find.textContaining('Robert'));

    // Before the fix the avatar spanned x 24-78 while the text began at x 16,
    // so the greeting's first ~62px rendered underneath the circle.
    expect(
      avatar.right,
      lessThanOrEqualTo(greeting.left),
      reason: 'the greeting begins where the avatar ends',
    );
  });

  testWidgets('a long name stays inside the card', (tester) async {
    await pump(tester, 'Alexandra Schleifmann');

    final avatar = tester.getRect(find.byType(ClientAvatar));
    final greeting = tester.getRect(find.textContaining('Alexandra'));

    expect(avatar.right, lessThanOrEqualTo(greeting.left));
    expect(greeting.right, lessThanOrEqualTo(420 - 16));
  });

  testWidgets('renders before the profile has loaded', (tester) async {
    // The dashboard builds before UserGoalsProvider has read the database, so
    // an empty name is a first-frame state rather than an edge case.
    await pump(tester, '');

    expect(find.byType(ClientAvatar), findsOneWidget);
    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('a calorie goal of zero does not render NaN', (tester) async {
    await pump(tester, 'Robert', todayCalories: 500, calorieGoal: 0);

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.0);
  });

  group('greeting', () {
    late AppLocalizations l10n;

    setUp(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('folds the name into the greeting, keeping the exclamation last', () {
      final text = GreetingCard.greeting(
        l10n,
        'Robert',
        now: DateTime(2026, 8, 26, 23, 46),
      );
      expect(text, 'Good evening, Robert!');
    });

    test('an unset name leaves the greeting alone', () {
      final text = GreetingCard.greeting(
        l10n,
        '   ',
        now: DateTime(2026, 8, 26, 9, 0),
      );
      expect(text, l10n.goodMorning);
      expect(text, isNot(contains(',')));
    });
  });

  group('ClientAvatar.initialsFor', () {
    test('takes the first and last word', () {
      expect(ClientAvatar.initialsFor('Robert Meyer'), 'RM');
      expect(ClientAvatar.initialsFor('Ana Lucia Silva'), 'AS');
    });

    test('one word gives one letter', () {
      expect(ClientAvatar.initialsFor('Robert'), 'R');
    });

    test('an unset name is a placeholder, not a crash', () {
      expect(ClientAvatar.initialsFor(''), '?');
      expect(ClientAvatar.initialsFor('   '), '?');
    });
  });
}
