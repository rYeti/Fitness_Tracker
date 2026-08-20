import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/l10n/app_localizations.dart';

import 'package:ForgeForm/feature/chat/data/chat_repository.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/trainer_console_home.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/trainer_console_shell.dart';

import '../chat/fakes.dart';
import 'fakes.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeTrainerConsoleRepository repository, {
  Size size = const Size(1400, 1200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // Chat is injected so the shell doesn't reach for the real SignalR socket or
  // the registered AppDatabase, neither of which exists under test.
  final db = newTestDatabase();
  final signalR = FakeChatSignalRClient();
  addTearDown(() async {
    await signalR.dispose();
    await db.close();
  });

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TrainerConsoleHome(
        repository: repository,
        chatRepository: ChatRepository(
          db: db,
          api: FakeChatApi(),
          signalR: signalR,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('desktop shows the sidebar with every section', (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        roster: [fakeClient()],
        rosterWithStats: [fakeRosterEntry()],
        nutrition: fakeNutrition(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ForgeForm'), findsOneWidget);
    for (final route in TrainerConsoleRoute.values) {
      expect(find.text(route.label), findsWidgets, reason: route.label);
    }
  });

  testWidgets('mobile swaps the sidebar for a bottom bar', (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        roster: [fakeClient()],
        rosterWithStats: [fakeRosterEntry()],
        nutrition: fakeNutrition(),
      ),
      size: const Size(420, 900),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('ForgeForm'), findsNothing);
  });

  testWidgets('selecting a section swaps the visible screen', (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        roster: [fakeClient()],
        rosterWithStats: [fakeRosterEntry()],
        nutrition: fakeNutrition(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);

    await tester.tap(find.text('Nutrition').first);
    await tester.pumpAndSettle();

    // The nutrition screen's own ring is now on screen.
    expect(find.textContaining('Daily intake'), findsOneWidget);
  });

  testWidgets('messages discloses that it is not wired up', (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        roster: [fakeClient()],
        rosterWithStats: [fakeRosterEntry()],
        nutrition: fakeNutrition(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Messages').first);
    await tester.pumpAndSettle();

    expect(find.text('Messaging isn’t wired up yet'), findsOneWidget);
  });

  testWidgets('the active client is shared across sections', (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        roster: [fakeClient(), fakeClient(id: 'c2', name: 'Ana Silva')],
        rosterWithStats: [fakeRosterEntry()],
        nutrition: fakeNutrition(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nutrition').first);
    await tester.pumpAndSettle();

    // Switch client from the Nutrition pane...
    await tester.tap(find.text('Robert Meyer').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Silva').last);
    await tester.pumpAndSettle();

    // ...and Session Review opens on the same client, not its own default.
    await tester.tap(find.text('Session Review').first);
    await tester.pumpAndSettle();

    expect(find.text('Ana Silva'), findsWidgets);
    expect(find.text('Robert Meyer'), findsNothing);
  });
}
