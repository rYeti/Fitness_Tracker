import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ForgeForm/core/di/service_locator.dart';
import 'package:ForgeForm/core/providers/access_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/trainer_console_gate.dart';

import 'package:ForgeForm/feature/trainer_console/presentation/providers/trainer_licence_provider.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

import 'fakes.dart';
import 'licence_fakes.dart';

/// The gate decides who sees other people's training data, so each branch is
/// pinned here. Note it's a UX guard, not the security boundary — the API
/// re-checks every call against an Active TrainerClient relationship.
Future<void> _pump(
  WidgetTester tester,
  AccessProvider access, {
  Widget? fallback,
  VoidCallback? onExitConsole,
  Size size = const Size(1400, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<AccessProvider>.value(
      value: access,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TrainerConsoleGate(
          fallback: fallback,
          onExitConsole: onExitConsole,
          repository: FakeTrainerConsoleRepository(),
          licenceProvider: TrainerLicenceProvider(
            repository: FakeTrainerLicenceRepository(current: licence()),
          ),
        ),
      ),
    ),
  );
}

void main() {
  // A fake repository is injected below, but the console's own screens still
  // resolve the locator on construction, so it has to be populated.
  // Registrations are lazy — nothing hits the network.
  setUp(() {
    sl.reset();
    setupLocator();
  });

  testWidgets('waits while access state is still resolving', (tester) async {
    await _pump(
      tester,
      AccessProvider.withState(isTrainer: true, initialized: false),
    );

    // A flash of "trainer access only" before the check lands would be worse
    // than a spinner.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Trainer access only'), findsNothing);
  });

  testWidgets('a non-trainer with no fallback is told why', (tester) async {
    await _pump(tester, AccessProvider.withState(isTrainer: false));
    await tester.pumpAndSettle();

    expect(find.text('Trainer access only'), findsOneWidget);
    expect(find.text('ForgeForm'), findsNothing); // console chrome absent
  });

  testWidgets('a non-trainer with a fallback gets the fallback', (
    tester,
  ) async {
    await _pump(
      tester,
      AccessProvider.withState(isTrainer: false),
      fallback: const Scaffold(body: Text('trainee app')),
    );
    await tester.pumpAndSettle();

    expect(find.text('trainee app'), findsOneWidget);
    expect(find.text('Trainer access only'), findsNothing);
  });

  testWidgets('a trainer gets the console', (tester) async {
    await _pump(tester, AccessProvider.withState(isTrainer: true));
    await tester.pump(); // console starts loading its roster

    expect(find.text('ForgeForm'), findsOneWidget); // sidebar wordmark
    expect(find.text('Trainer access only'), findsNothing);
  });

  testWidgets('the exit action only appears when leaving is possible', (
    tester,
  ) async {
    await _pump(tester, AccessProvider.withState(isTrainer: true));
    await tester.pump();
    // Pushed as a route, back already covers it — no redundant control.
    expect(find.text('My training'), findsNothing);

    var exited = false;
    await _pump(
      tester,
      AccessProvider.withState(isTrainer: true),
      onExitConsole: () => exited = true,
    );
    await tester.pump();

    expect(find.text('My training'), findsOneWidget);
    await tester.tap(find.text('My training'));
    expect(exited, isTrue);
  });
}
