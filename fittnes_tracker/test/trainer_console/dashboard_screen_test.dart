import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_licence.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/active_client_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/trainer_licence_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/trainer_dashboard_screen.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

import 'fakes.dart';
import 'licence_fakes.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeTrainerConsoleRepository repository, {
  Size size = const Size(1400, 1000),
  ValueChanged<TrainerRosterEntry>? onClientSelected,
  // The Dashboard reads a licence for its seat chip and invite action. Always
  // injected, or the widget would build a real repository and hit the network.
  TrainerLicence? plan,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // The roster lives in the shared client-switcher state, which the console shell owns —
  // so a Dashboard pumped on its own needs one above it, fed by the same fake.
  final activeClient = ActiveClientProvider(repository: repository);
  unawaited(activeClient.loadClients());
  addTearDown(activeClient.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider<ActiveClientProvider>.value(
      value: activeClient,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TrainerDashboardScreen(
          repository: repository,
          licenceProvider: TrainerLicenceProvider(
            repository: FakeTrainerLicenceRepository(
              current: plan ?? licence(seatsUsed: 1, seatLimit: 10),
            ),
          ),
          onClientSelected: onClientSelected,
        ),
      ),
    ),
  );
}

void main() {
  group('seats', _seatTests);

  testWidgets('each section shows its own skeleton while it loads', (
    tester,
  ) async {
    // Both sections held by one completer, but through their own gates: the roster and
    // the KPIs are separate fetches now, and the fake keeps them separable so a test can
    // hold either alone.
    final gate = Completer<void>();
    await _pump(
      tester,
      FakeTrainerConsoleRepository(rosterGate: gate, kpiGate: gate),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('Loading clients'), findsOneWidget);
    expect(find.bySemanticsLabel('Loading summary'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('the roster renders while the KPIs are still loading', (
    tester,
  ) async {
    // The whole point of splitting the gate. The roster is what the trainer came for;
    // it used to be held back until the slower KPI query landed too.
    final kpiGate = Completer<void>();
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        rosterWithStats: [fakeRosterEntry()],
        kpiGate: kpiGate,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Robert Meyer'), findsOneWidget);
    expect(find.bySemanticsLabel('Loading summary'), findsOneWidget);

    kpiGate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a failing KPI load leaves the roster visible', (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        rosterWithStats: [fakeRosterEntry()],
        throwOnDashboard: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Robert Meyer'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('a failing roster load shows an inline error with retry', (
    tester,
  ) async {
    await _pump(tester, FakeTrainerConsoleRepository(throwOnRoster: true));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsWidgets);
  });

  testWidgets('the invite action is reachable while data is still loading', (
    tester,
  ) async {
    // Page chrome used to sit behind the same gate as the data, so a trainer waiting on
    // a slow roster could not do the one thing an empty console is for.
    final gate = Completer<void>();
    await _pump(
      tester,
      FakeTrainerConsoleRepository(rosterGate: gate, kpiGate: gate),
    );
    await tester.pump();

    expect(find.widgetWithText(OutlinedButton, 'Invite'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('no clients shows the empty state', (tester) async {
    await _pump(tester, FakeTrainerConsoleRepository());
    await tester.pumpAndSettle();

    expect(find.text('No clients yet'), findsOneWidget);
  });

  testWidgets('KPI row renders values but omits the always-zero alerts tile', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        rosterWithStats: [fakeRosterEntry()],
        kpis: const TrainerDashboardKpis(
          activeClientCount: 7,
          avgAdherencePercent: 82.4,
          sessionsThisWeek: 19,
          alertCount: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('7'), findsOneWidget);
    expect(find.text('82%'), findsOneWidget);
    expect(find.text('19'), findsOneWidget);
    // AlertCount is never populated server-side, so no tile claims it.
    expect(find.text('Alerts'), findsNothing);
  });

  testWidgets('roster card shows program and banded adherence', (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        rosterWithStats: [
          fakeRosterEntry(adherence: 91),
          fakeRosterEntry(id: 'c2', name: 'Ana Silva', adherence: 42),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Robert Meyer'), findsOneWidget);
    expect(find.text('Push / Pull / Legs'), findsNWidgets(2));
    expect(find.text('91%'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
  });

  testWidgets('a client with nothing scheduled reads as No data, not 0%', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        rosterWithStats: [fakeRosterEntry(adherence: null)],
        // Non-zero KPI adherence, so a stray "0%" can only have come from the
        // roster card under test rather than the KPI tile above it.
        kpis: const TrainerDashboardKpis(
          activeClientCount: 1,
          avgAdherencePercent: 73,
          sessionsThisWeek: 4,
          alertCount: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No data'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
  });

  testWidgets('tapping a roster card reports the client', (tester) async {
    TrainerRosterEntry? selected;
    await _pump(
      tester,
      FakeTrainerConsoleRepository(rosterWithStats: [fakeRosterEntry()]),
      onClientSelected: (entry) => selected = entry,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Robert Meyer'));
    await tester.pumpAndSettle();

    expect(selected?.clientId, 'client-1');
  });

  testWidgets('table layout renders column headers once toggled', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(rosterWithStats: [fakeRosterEntry()]),
    );
    await tester.pumpAndSettle();

    expect(find.text('CLIENT'), findsNothing);

    await tester.tap(find.byIcon(Icons.table_rows_rounded));
    await tester.pumpAndSettle();

    expect(find.text('CLIENT'), findsOneWidget);
    // The window is part of the header: this column is a trailing 28 days,
    // while the KPI tile above averages the current week. They disagreed on
    // screen while both were labelled just "adherence".
    expect(find.text('ADHERENCE (28D)'), findsOneWidget);
  });

  testWidgets('narrow viewport keeps cards even in table mode', (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(rosterWithStats: [fakeRosterEntry()]),
      size: const Size(420, 900),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.table_rows_rounded));
    await tester.pumpAndSettle();

    // The dense table needs desktop width; below it the grid stands in.
    expect(find.text('CLIENT'), findsNothing);
    expect(find.text('Robert Meyer'), findsOneWidget);
  });
}

/// Seat affordances on the Dashboard: how full the plan is, and whether a new
/// client can be taken on.
void _seatTests() {
  testWidgets('shows the seat chip', (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(),
      plan: licence(tier: LicenceTier.pro, seatsUsed: 7, seatLimit: 30),
    );
    await tester.pumpAndSettle();

    expect(find.text('7 / 30'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        '7 of 30 client seats used. Pro plan. Open plan settings.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('offers the invite action when there is room', (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(),
      plan: licence(seatsUsed: 2, seatLimit: 10),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Invite'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('disables the invite action at the limit, with a reason',
      (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(),
      plan: licence(seatsUsed: 10, seatLimit: 10),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Invite'),
    );
    expect(button.onPressed, isNull);
    // Both the header action and the empty-state action carry the reason.
    expect(
      find.byTooltip(
        'All 10 seats are in use. Withdraw an invite or upgrade.',
      ),
      findsWidgets,
    );
  });

  testWidgets('disables the invite action once the licence has lapsed',
      (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(),
      plan: licence(
        status: LicenceStatus.canceled,
        graceEndsAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Invite'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('banners a lapsed licence', (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(),
      plan: licence(
        status: LicenceStatus.canceled,
        graceEndsAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Your licence has lapsed'), findsOneWidget);
  });

  testWidgets('shows no banner on a healthy plan with room', (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(),
      plan: licence(seatsUsed: 1, seatLimit: 10),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('lapsed'), findsNothing);
    expect(find.textContaining('seats on your'), findsNothing);
  });

  testWidgets('the empty roster points at the invite flow', (tester) async {
    // "No clients yet" with no way to get one was the old state of this
    // screen — the invite endpoint had no caller anywhere in the app.
    await _pump(tester, FakeTrainerConsoleRepository());
    await tester.pumpAndSettle();

    expect(find.text('No clients yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Invite a client'), findsOneWidget);
  });
}
