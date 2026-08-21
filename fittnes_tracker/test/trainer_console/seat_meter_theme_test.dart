import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/providers/theme_provider.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_licence.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/licence_banner.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/seat_meter.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

import 'licence_fakes.dart';

/// Renders the seat widgets against ForgeForm's *real* theme rather than
/// MaterialApp's defaults, at both breakpoints and in both brightnesses.
///
/// Worth doing on its own because the last console defect of this kind — an
/// orange icon on an orange-derived indicator — was invisible to tests that
/// used the default theme, and only showed up in a browser. A RenderFlex
/// overflow fails the test, so narrow widths are checked here too.
void main() {
  late AppDatabase db;
  late ThemeProvider themes;

  setUp(() {
    db = AppDatabase.test(NativeDatabase.memory());
    themes = ThemeProvider(db);
  });
  tearDown(() => db.close());

  Future<void> pumpAt(
    WidgetTester tester,
    Size size,
    ThemeData theme,
    TrainerLicence plan,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SeatChip(licence: plan),
                      const SizedBox(width: 12),
                      Expanded(child: SeatMeter(licence: plan)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LicenceBanner(licence: plan),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final plans = <String, TrainerLicence>{
    'healthy': licence(tier: LicenceTier.pro, seatsUsed: 7, seatLimit: 30),
    'full': licence(tier: LicenceTier.solo, seatsUsed: 10, seatLimit: 10),
    'over limit': licence(tier: LicenceTier.free, seatsUsed: 12, seatLimit: 3),
    'in grace': licence(
      status: LicenceStatus.pastDue,
      graceEndsAt: DateTime(2026, 9, 3),
    ),
    'lapsed': licence(
      status: LicenceStatus.canceled,
      graceEndsAt: DateTime(2026, 1, 1),
    ),
  };

  for (final entry in plans.entries) {
    for (final width in const [360.0, 1400.0]) {
      testWidgets('${entry.key} lays out at ${width.toInt()}px in light theme',
          (tester) async {
        await pumpAt(
          tester,
          Size(width, 900),
          themes.lightTheme,
          entry.value,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('${entry.key} lays out at ${width.toInt()}px in dark theme',
          (tester) async {
        await pumpAt(tester, Size(width, 900), themes.darkTheme, entry.value);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the seat chip meets the 44px minimum tap target',
      (tester) async {
    await pumpAt(
      tester,
      const Size(360, 900),
      themes.lightTheme,
      plans['healthy']!,
    );

    final size = tester.getSize(find.byType(SeatChip));
    expect(size.height, greaterThanOrEqualTo(44));
    expect(size.width, greaterThanOrEqualTo(44));
  });

  testWidgets('over-limit state is not signalled by colour alone',
      (tester) async {
    // CLAUDE.md: colour is never the only signal. A colourblind trainer has to
    // be able to tell a full plan from a healthy one.
    await pumpAt(
      tester,
      const Size(1400, 900),
      themes.lightTheme,
      plans['over limit']!,
    );

    expect(find.text('12 of 3 clients'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsWidgets);
    expect(find.textContaining("can't add more"), findsWidgets);
  });
}
