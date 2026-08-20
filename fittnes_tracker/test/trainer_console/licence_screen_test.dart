import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_licence.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/trainer_licence_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/licence_screen.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/seat_meter.dart';

import 'licence_fakes.dart';

void main() {
  Future<TrainerLicenceProvider> pump(
    WidgetTester tester,
    FakeTrainerLicenceRepository repo,
  ) async {
    final provider = TrainerLicenceProvider(repository: repo);
    await tester.pumpWidget(
      MaterialApp(home: LicenceScreen(provider: provider)),
    );
    return provider;
  }

  group('states', () {
    testWidgets('shows a skeleton while loading', (tester) async {
      final gate = Completer<void>();
      await pump(tester, FakeTrainerLicenceRepository(gate: gate));
      await tester.pump();

      expect(find.bySemanticsLabel('Loading your plan'), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('shows a retryable error', (tester) async {
      await pump(tester, FakeTrainerLicenceRepository(throwOnLoad: true));
      await tester.pumpAndSettle();

      expect(find.text('Could not load your plan.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('renders the plan once loaded', (tester) async {
      await pump(
        tester,
        FakeTrainerLicenceRepository(
          current: licence(tier: LicenceTier.pro, seatsUsed: 7, seatLimit: 30),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pro plan'), findsOneWidget);
      expect(find.text('7 of 30 clients'), findsOneWidget);
      expect(find.text('23 seats left'), findsOneWidget);
    });
  });

  group('what the plan includes', () {
    testWidgets('a paid plan says Pro is covered', (tester) async {
      await pump(
        tester,
        FakeTrainerLicenceRepository(current: licence(tier: LicenceTier.solo)),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Pro included for you and every client'),
        findsOneWidget,
      );
    });

    testWidgets('the free plan says Pro is not covered', (tester) async {
      // The free tier is deliberately not a Pro dispenser; the screen has to
      // say so plainly or the upgrade makes no sense.
      await pump(tester, FakeTrainerLicenceRepository(current: freeLicence()));
      await tester.pumpAndSettle();

      expect(find.text('Free plan'), findsOneWidget);
      expect(
        find.text('Pro not included — upgrade to cover your clients'),
        findsOneWidget,
      );
    });

    testWidgets('hides Manage billing when there is nothing to manage',
        (tester) async {
      await pump(tester, FakeTrainerLicenceRepository(current: freeLicence()));
      await tester.pumpAndSettle();

      expect(find.text('Manage billing'), findsNothing);
    });

    testWidgets('offers Manage billing once a subscription exists',
        (tester) async {
      await pump(
        tester,
        FakeTrainerLicenceRepository(current: licence(tier: LicenceTier.pro)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Manage billing'), findsOneWidget);
    });
  });

  group('banners', () {
    testWidgets('warns during grace and names the date', (tester) async {
      await pump(
        tester,
        FakeTrainerLicenceRepository(
          current: licence(
            status: LicenceStatus.pastDue,
            graceEndsAt: DateTime(2026, 9, 3),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Payment failed'), findsWidgets);
      expect(find.textContaining('3 Sep'), findsOneWidget);
      expect(find.text('Fix payment'), findsOneWidget);
    });

    testWidgets('says the console is read-only once grace has elapsed',
        (tester) async {
      await pump(
        tester,
        FakeTrainerLicenceRepository(
          current: licence(
            status: LicenceStatus.canceled,
            graceEndsAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Your licence has lapsed'), findsOneWidget);
      expect(find.text('Renew'), findsOneWidget);
    });

    testWidgets('explains being over the limit without threatening removal',
        (tester) async {
      // The rule is "block new invites, never revoke". The copy has to make
      // that explicit or a trainer will assume clients are about to be cut.
      await pump(
        tester,
        FakeTrainerLicenceRepository(
          current: licence(tier: LicenceTier.free, seatsUsed: 12, seatLimit: 3),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Nobody is removed'), findsOneWidget);
      expect(find.text('12 of 3 clients'), findsOneWidget);
    });

    testWidgets('stays quiet on a healthy plan with room', (tester) async {
      await pump(
        tester,
        FakeTrainerLicenceRepository(
          current: licence(seatsUsed: 2, seatLimit: 10),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('lapsed'), findsNothing);
      expect(find.text('Upgrade'), findsNothing);
    });
  });

  group('changing plan', () {
    testWidgets('lists the purchasable tiers and marks the current one',
        (tester) async {
      await pump(
        tester,
        FakeTrainerLicenceRepository(current: licence(tier: LicenceTier.solo)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Up to 10 clients, Pro included'), findsOneWidget);
      expect(find.text('Up to 30 clients, Pro included'), findsOneWidget);
      expect(find.text('Up to 100 clients, Pro included'), findsOneWidget);
      expect(find.text('Current'), findsOneWidget);
    });

    testWidgets('starts checkout for the chosen tier', (tester) async {
      final repo = FakeTrainerLicenceRepository(
        current: licence(tier: LicenceTier.solo),
      );
      await pump(tester, repo);
      await tester.pumpAndSettle();

      final proRow = find.text('Up to 30 clients, Pro included');
      await tester.ensureVisible(proRow);
      await tester.pumpAndSettle();
      await tester.tap(proRow);
      await tester.pumpAndSettle();

      expect(repo.checkoutTiers, [LicenceTier.pro]);
    });
  });

  testWidgets('an over-limit meter shows no seats left, never a negative count',
      (tester) async {
    await pump(
      tester,
      FakeTrainerLicenceRepository(
        current: licence(seatsUsed: 15, seatLimit: 10),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SeatMeter), findsOneWidget);
    expect(find.text('15 of 10 clients'), findsOneWidget);
    // "-5 seats left" would be the bug.
    expect(find.textContaining('seats left'), findsNothing);
    expect(find.textContaining("can't add more"), findsWidgets);
  });
}
