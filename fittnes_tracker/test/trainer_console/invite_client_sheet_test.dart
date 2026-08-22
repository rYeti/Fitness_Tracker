import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_licence.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/trainer_licence_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/invite_client_sheet.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

import 'licence_fakes.dart';

/// The mechanism a trainer uses to add a client. Before this existed the
/// endpoint had no caller at all — there was no way to get a code out of the
/// app.
void main() {
  Future<TrainerLicenceProvider> pump(
    WidgetTester tester,
    FakeTrainerLicenceRepository repo,
  ) async {
    final provider = TrainerLicenceProvider(repository: repo);
    await provider.load();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangeNotifierProvider<TrainerLicenceProvider>.value(
          value: provider,
          child: const Scaffold(body: InviteClientSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return provider;
  }

  group('minting', () {
    testWidgets('creates a code and shows it', (tester) async {
      final repo = FakeTrainerLicenceRepository(
        current: licence(seatsUsed: 2, seatLimit: 10),
      );
      await pump(tester, repo);

      await tester.tap(find.text('Create invite code'));
      await tester.pumpAndSettle();

      expect(repo.createInviteCalls, 1);
      expect(find.text('A3F2B891C7E4'), findsAtLeastNWidgets(1));
      expect(find.text('Copy code'), findsOneWidget);
    });

    testWidgets('the new code immediately consumes a seat', (tester) async {
      // A code that's out in the world is a committed seat; showing 2/10 after
      // minting a third would understate how full the plan is.
      final repo = FakeTrainerLicenceRepository(
        current: licence(seatsUsed: 2, seatLimit: 10),
      );
      await pump(tester, repo);
      expect(find.text('2 of 10 clients'), findsOneWidget);

      await tester.tap(find.text('Create invite code'));
      await tester.pumpAndSettle();

      expect(find.text('3 of 10 clients'), findsOneWidget);
    });

    testWidgets('disables the action at the seat limit and says why',
        (tester) async {
      final repo = FakeTrainerLicenceRepository(
        current: licence(seatsUsed: 10, seatLimit: 10),
      );
      await pump(tester, repo);

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Create invite code'),
      );
      expect(button.onPressed, isNull);
      // Disabled without explanation is worse than not offering it at all.
      expect(
        find.text('All 10 seats are in use. Withdraw an invite or upgrade.'),
        findsOneWidget,
      );
    });

    testWidgets('disables the action once the licence has lapsed',
        (tester) async {
      final repo = FakeTrainerLicenceRepository(
        current: licence(
          status: LicenceStatus.canceled,
          graceEndsAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );
      await pump(tester, repo);

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Create invite code'),
      );
      expect(button.onPressed, isNull);
      expect(find.text('Renew your licence to invite clients.'), findsOneWidget);
    });

    testWidgets('surfaces the server refusal in the reader\'s language',
        (tester) async {
      final repo = FakeTrainerLicenceRepository(
        // The provider lets the tap through; the server refuses. This is the
        // race the redemption-time check exists for.
        current: licence(seatsUsed: 2, seatLimit: 10),
        // The server also sends an English sentence. It must not be what the
        // trainer reads — the seat *numbers* carry the specificity, so the
        // localized string is just as precise in any language.
        inviteFailure: const InviteException(
          InviteFailure.seatLimitReached,
          'Your plan covers 10 clients and all of them are in use.',
          10,
          10,
        ),
      );
      await pump(tester, repo);

      await tester.tap(find.text('Create invite code'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Your plan covers 10 clients and all 10 are in use. '
          'Upgrade or free up a seat.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Your plan covers 10 clients and all of them are in use.'),
        findsNothing,
        reason: 'the API sentence is diagnostic, never shown',
      );
    });
  });

  group('outstanding invites', () {
    testWidgets('lists them with their expiry', (tester) async {
      await pump(
        tester,
        FakeTrainerLicenceRepository(
          current: licence(seatsUsed: 1, seatLimit: 10),
          invites: [pendingInvite(code: 'BB11CC22DD33', expiresInDays: 6)],
        ),
      );

      expect(find.text('Outstanding invites'), findsOneWidget);
      expect(find.text('BB11CC22DD33'), findsOneWidget);
      expect(find.text('Expires in 6 days'), findsOneWidget);
    });

    testWidgets('explains that each one holds a seat', (tester) async {
      await pump(
        tester,
        FakeTrainerLicenceRepository(
          current: licence(seatsUsed: 1, seatLimit: 10),
          invites: [pendingInvite()],
        ),
      );

      expect(
        find.text('Each of these holds a seat until it is used or withdrawn.'),
        findsOneWidget,
      );
    });

    testWidgets('withdrawing takes a confirmation first', (tester) async {
      final repo = FakeTrainerLicenceRepository(
        current: licence(seatsUsed: 1, seatLimit: 10),
        invites: [pendingInvite(id: 'invite-7')],
      );
      await pump(tester, repo);

      await tester.tap(find.byTooltip('Withdraw A3F2B891C7E4'));
      await tester.pumpAndSettle();

      expect(find.text('Withdraw this invite?'), findsOneWidget);
      // Backing out must not revoke anything.
      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(repo.revokedInviteIds, isEmpty);
    });

    testWidgets('confirming withdraws it and frees the seat', (tester) async {
      final repo = FakeTrainerLicenceRepository(
        current: licence(seatsUsed: 3, seatLimit: 10),
        invites: [pendingInvite(id: 'invite-7')],
      );
      await pump(tester, repo);

      await tester.tap(find.byTooltip('Withdraw A3F2B891C7E4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Withdraw'));
      await tester.pumpAndSettle();

      expect(repo.revokedInviteIds, ['invite-7']);
      expect(find.text('2 of 10 clients'), findsOneWidget);
    });

    testWidgets('says nothing about invites when there are none',
        (tester) async {
      await pump(
        tester,
        FakeTrainerLicenceRepository(current: licence(seatsUsed: 0)),
      );

      expect(find.text('Outstanding invites'), findsNothing);
    });
  });
}
