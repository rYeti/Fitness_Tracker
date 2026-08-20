import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ForgeForm/core/providers/access_provider.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_licence.dart';
import 'package:ForgeForm/feature/trainer/presentation/view/join_trainer_screen.dart';

import 'licence_fakes.dart';

/// Redeeming an invite code. Until now `_submit` was an empty method body and
/// nothing in the app navigated here, so none of this existed.
void main() {
  Future<void> pump(WidgetTester tester, FakeTrainerLicenceRepository repo) {
    return tester.pumpWidget(
      ChangeNotifierProvider<AccessProvider>(
        create: (_) => AccessProvider.withState(),
        child: MaterialApp(
          home: JoinTrainerScreen(
            repository: repo,
            // The real one re-checks entitlements over the network.
            onJoined: (_) async {},
          ),
        ),
      ),
    );
  }

  Future<void> enter(WidgetTester tester, String code) async {
    await tester.enterText(find.byType(TextField), code);
    await tester.pump();
  }

  group('validation', () {
    testWidgets('refuses an empty code without calling the server',
        (tester) async {
      final repo = FakeTrainerLicenceRepository();
      await pump(tester, repo);

      await tester.tap(find.text('Join Trainer'));
      await tester.pump();

      expect(
        find.text('Enter the 12-character code from your trainer.'),
        findsOneWidget,
      );
      expect(repo.joinedCodes, isEmpty);
    });

    testWidgets('refuses a short code locally', (tester) async {
      final repo = FakeTrainerLicenceRepository();
      await pump(tester, repo);
      await enter(tester, 'A3F2');

      await tester.tap(find.text('Join Trainer'));
      await tester.pump();

      expect(
        find.text('Codes are 12 characters, digits and letters A–F.'),
        findsOneWidget,
      );
      expect(repo.joinedCodes, isEmpty);
    });

    testWidgets('upper-cases what the user types', (tester) async {
      // Codes are hex from the server and always shown upper-case; forcing the
      // user to match that would be needless friction.
      final repo = FakeTrainerLicenceRepository();
      await pump(tester, repo);
      await enter(tester, 'a3f2b891c7e4');

      await tester.tap(find.text('Join Trainer'));
      await tester.pumpAndSettle();

      expect(repo.joinedCodes, ['A3F2B891C7E4']);
    });

    testWidgets('drops characters that cannot appear in a code',
        (tester) async {
      final repo = FakeTrainerLicenceRepository();
      await pump(tester, repo);
      await enter(tester, 'A3F2-B891 C7E4!');

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'A3F2B891C7E4');
    });
  });

  group('failures', () {
    Future<void> submitWith(
      WidgetTester tester,
      InviteException failure,
    ) async {
      await pump(tester, FakeTrainerLicenceRepository(joinFailure: failure));
      await enter(tester, 'A3F2B891C7E4');
      await tester.tap(find.text('Join Trainer'));
      await tester.pumpAndSettle();
    }

    testWidgets('a full trainer is named as such, not as a bad code',
        (tester) async {
      // The whole reason AcceptInviteStatus exists. Telling this trainee their
      // code is invalid sends them hunting for the wrong problem entirely.
      await submitWith(
        tester,
        const InviteException(
          InviteFailure.trainerAtSeatLimit,
          "Your trainer's plan is full. Ask them to free up a seat.",
        ),
      );

      expect(
        find.text("Your trainer's plan is full. Ask them to free up a seat."),
        findsOneWidget,
      );
    });

    testWidgets('a lapsed trainer is named as such', (tester) async {
      await submitWith(
        tester,
        const InviteException(
          InviteFailure.trainerNotEntitled,
          "Your trainer's plan isn't active. Ask them to renew it.",
        ),
      );

      expect(
        find.text("Your trainer's plan isn't active. Ask them to renew it."),
        findsOneWidget,
      );
    });

    testWidgets('an expired code is distinguished from an unknown one',
        (tester) async {
      await submitWith(
        tester,
        const InviteException(
          InviteFailure.expiredCode,
          'That invite has expired. Ask your trainer for a new code.',
        ),
      );

      expect(
        find.text('That invite has expired. Ask your trainer for a new code.'),
        findsOneWidget,
      );
    });

    testWidgets('a network failure does not read as a rejected code',
        (tester) async {
      await submitWith(
        tester,
        const InviteException(
          InviteFailure.network,
          "Couldn't reach ForgeForm. Check your connection and try again.",
        ),
      );

      expect(
        find.text("Couldn't reach ForgeForm. Check your connection and try again."),
        findsOneWidget,
      );
    });

    testWidgets('stays on the screen so the code can be corrected',
        (tester) async {
      await submitWith(
        tester,
        const InviteException(InviteFailure.invalidCode, 'Bad code.'),
      );

      expect(find.byType(JoinTrainerScreen), findsOneWidget);
      expect(find.text('Join Trainer'), findsOneWidget);
    });
  });

  group('success', () {
    testWidgets('submits the code and confirms', (tester) async {
      final repo = FakeTrainerLicenceRepository();
      await pump(tester, repo);
      await enter(tester, 'A3F2B891C7E4');

      await tester.tap(find.text('Join Trainer'));
      await tester.pumpAndSettle();

      expect(repo.joinedCodes, ['A3F2B891C7E4']);
    });
  });

  testWidgets('says up front what the trainer will be able to see',
      (tester) async {
    // Joining hands someone visibility of your food and training logs. That
    // should be stated before the tap, not discovered afterwards.
    await pump(tester, FakeTrainerLicenceRepository());

    expect(
      find.textContaining('will be able to see your workouts'),
      findsOneWidget,
    );
  });
}
