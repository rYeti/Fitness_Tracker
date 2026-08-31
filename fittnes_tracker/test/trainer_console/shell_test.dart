import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/l10n/app_localizations.dart';

import 'package:ForgeForm/feature/chat/data/chat_repository.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/trainer_console_home.dart';
import 'package:ForgeForm/feature/chat/presentation/widgets/unread_badge.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/trainer_console_shell.dart';

import 'package:ForgeForm/feature/trainer_console/presentation/providers/trainer_licence_provider.dart';

import '../chat/fakes.dart';
import 'fakes.dart';
import 'licence_fakes.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeTrainerConsoleRepository repository, {
  Size size = const Size(1400, 1200),
  FakeChatApi? chatApi,
  VoidCallback? onExitConsole,
  double statusBarHeight = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.view.padding = FakeViewPadding(top: statusBarHeight);
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
        onExitConsole: onExitConsole,
        repository: repository,
        // The console owns a licence provider for its seat affordances;
        // injected here so the shell tests don't reach the network.
        licenceProvider: TrainerLicenceProvider(
          repository: FakeTrainerLicenceRepository(current: licence()),
        ),
        chatRepository: ChatRepository(
          db: db,
          api: chatApi ?? FakeChatApi(),
          signalR: signalR,
          crypto: FakeChatCrypto(),
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
        rosterWithStats: [fakeRosterEntry()],
        nutrition: fakeNutrition(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ForgeForm'), findsOneWidget);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    for (final route in TrainerConsoleRoute.values) {
      final label = route.label(l10n);
      expect(find.text(label), findsWidgets, reason: label);
    }
  });

  testWidgets('mobile swaps the sidebar for a bottom bar', (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        rosterWithStats: [fakeRosterEntry()],
        nutrition: fakeNutrition(),
      ),
      size: const Size(420, 900),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('ForgeForm'), findsNothing);
  });

  // The console used to build its exit bar as the first child of a Column and
  // wrap *that* in a SafeArea. SafeArea removes the inset for its own subtree
  // only, so the sibling holding the five sections kept the full status-bar
  // padding — and every section has a SafeArea of its own, so the inset was
  // paid a second time. The result was a band of dead space under the bar, on
  // all five tabs, for any trainer who landed in the console from sign-in
  // (PostAuthHome passes a non-null onExitConsole; a push from Settings does
  // not, which is why it only ever reproduced on startup).
  //
  // Nothing about that is visible to the compiler, or to a test that only asks
  // whether widgets are present: both layouts render every widget. It is
  // visible only as a number.
  testWidgets('the status bar inset is paid once, not twice', (tester) async {
    // Measured as a *difference* between two runs rather than as an absolute
    // offset: the heading shares a Row with the taller seat chip, so its own
    // box is centred within it and the raw number carries a few pixels of text
    // metrics that have nothing to do with insets.
    Future<double> contentOffsetBelowBar(double statusBarHeight) async {
      await _pump(
        tester,
        FakeTrainerConsoleRepository(
          rosterWithStats: [fakeRosterEntry()],
          nutrition: fakeNutrition(),
        ),
        size: const Size(420, 900),
        onExitConsole: () {},
        statusBarHeight: statusBarHeight,
      );
      await tester.pumpAndSettle();
      return tester.getTopLeft(find.text('Dashboard').first).dy -
          tester.getBottomLeft(find.byType(AppBar)).dy;
    }

    final withoutStatusBar = await contentOffsetBelowBar(0);
    final withStatusBar = await contentOffsetBelowBar(40);

    // A 40px status bar must push the *bar* down and nothing else. Before the
    // fix the section's own SafeArea paid the inset a second time below the
    // bar, so this difference was 40 rather than 0.
    expect(withStatusBar, closeTo(withoutStatusBar, 0.5));
  });

  testWidgets('selecting a section swaps the visible screen', (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
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

  testWidgets('messages opens the real chat screen', (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        rosterWithStats: [fakeRosterEntry()],
        nutrition: fakeNutrition(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Messages').first);
    await tester.pumpAndSettle();

    // Messages used to be a placeholder saying it wasn't wired up. It is now
    // the real screen, so what this pins is that the tab opens it and that an
    // empty inbox says so rather than rendering nothing.
    expect(find.text('No conversations yet'), findsOneWidget);
  });

  testWidgets('the active client is shared across sections', (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        rosterWithStats: [
          fakeRosterEntry(),
          fakeRosterEntry(id: 'c2', name: 'Ana Silva'),
        ],
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

  // ── Unread badge on the Messages tab ──────────────────────────────────────

  Map<String, dynamic> conversation(String id, String name, int unread) => {
        'otherPartyId': id,
        'otherPartyName': name,
        'lastMessagePreview': 'see you thursday',
        'lastMessageAt': DateTime.utc(2026, 8, 1, 9).toIso8601String(),
        'unreadCount': unread,
      };

  testWidgets('the sidebar badges Messages with the total unread count',
      (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        rosterWithStats: [fakeRosterEntry()],
        nutrition: fakeNutrition(),
      ),
      chatApi: FakeChatApi(conversations: [
        conversation('client-a', 'Robert Meyer', 2),
        conversation('client-b', 'Ana Duarte', 3),
        conversation('client-c', 'Tom Vasquez', 0),
      ]),
    );
    await tester.pumpAndSettle();

    // The total across conversations, not a per-row count and not a dot: the
    // trainer wants to know how much is waiting before deciding to open it.
    expect(find.widgetWithText(UnreadBadge, '5'), findsOneWidget);
  });

  testWidgets('no badge when everything is read', (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        rosterWithStats: [fakeRosterEntry()],
        nutrition: fakeNutrition(),
      ),
      chatApi: FakeChatApi(conversations: [
        conversation('client-a', 'Robert Meyer', 0),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(UnreadBadge), findsNothing);
  });

  testWidgets('mobile badges the Messages destination too', (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        rosterWithStats: [fakeRosterEntry()],
        nutrition: fakeNutrition(),
      ),
      size: const Size(420, 900),
      chatApi: FakeChatApi(conversations: [
        conversation('client-a', 'Robert Meyer', 4),
      ]),
    );
    await tester.pumpAndSettle();

    // Material's Badge on the tab icon rather than UnreadBadge -- see
    // _BottomNav._maybeBadge for why the two presentations differ.
    expect(find.widgetWithText(Badge, '4'), findsOneWidget);
  });

  testWidgets('a count past 99 is capped rather than breaking the layout',
      (tester) async {
    await _pump(
      tester,
      FakeTrainerConsoleRepository(
        rosterWithStats: [fakeRosterEntry()],
        nutrition: fakeNutrition(),
      ),
      chatApi: FakeChatApi(conversations: [
        conversation('client-a', 'Robert Meyer', 120),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(UnreadBadge, '99+'), findsOneWidget);
  });

  group('what fetches on open', _lazyMountTests);
}

/// Which sections reach for the network, and when.
///
/// The shell used to be a plain [IndexedStack], which builds every child immediately — so
/// opening the console mounted all five sections and each fired its own loads for a screen
/// nobody was looking at. These pin both halves of what replaced it: nothing fetches until
/// its section is opened, and opening it twice still only fetches once.
void _lazyMountTests() {
  testWidgets('only the dashboard fetches when the console opens', (
    tester,
  ) async {
    final repository = FakeTrainerConsoleRepository(
      rosterWithStats: [fakeRosterEntry()],
      nutrition: fakeNutrition(),
    );
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    expect(repository.calls['roster'], 1);
    expect(repository.calls['kpis'], 1);
    // Nutrition and Session Review are behind their own tabs.
    expect(repository.calls['nutrition'], isNull);
    expect(repository.calls['sessions'], isNull);
  });

  testWidgets('opening a section fetches it, and returning to it does not', (
    tester,
  ) async {
    final repository = FakeTrainerConsoleRepository(
      rosterWithStats: [fakeRosterEntry()],
      nutrition: fakeNutrition(),
    );
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nutrition').first);
    await tester.pumpAndSettle();
    expect(repository.calls['nutrition'], 1);

    // Away and back. The section stays mounted, which is the half of IndexedStack's
    // behaviour that was always wanted — switching tabs must not re-fetch.
    await tester.tap(find.text('Dashboard').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nutrition').first);
    await tester.pumpAndSettle();

    expect(repository.calls['nutrition'], 1);
  });
}
