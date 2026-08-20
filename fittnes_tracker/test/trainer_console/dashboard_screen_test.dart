import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/trainer_dashboard_screen.dart';

import 'fakes.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeTrainerConsoleRepository repository, {
  Size size = const Size(1400, 1000),
  ValueChanged<TrainerRosterEntry>? onClientSelected,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: TrainerDashboardScreen(
        repository: repository,
        onClientSelected: onClientSelected,
      ),
    ),
  );
}

void main() {
  testWidgets('loading shows a skeleton', (tester) async {
    final gate = Completer<void>();
    await _pump(tester, FakeTrainerConsoleRepository(gate: gate));
    await tester.pump();

    expect(find.bySemanticsLabel('Loading dashboard'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a failing load shows an inline error with retry', (
    tester,
  ) async {
    await _pump(tester, FakeTrainerConsoleRepository(throwOnDashboard: true));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
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
    expect(find.text('ADHERENCE'), findsOneWidget);
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
