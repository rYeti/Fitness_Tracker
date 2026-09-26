import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/feature/trainer_console/presentation/widgets/refresh_failed_notice.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/status_badge.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// The notice itself: what it says, to whom, and how big a target it is.
/// Each pane showing it, and Retry reading again, is pinned in
/// live_updates_test.dart; its colours' contrast in contrast_test.dart.
///
/// Each test was run with the rule it pins taken out, and failed there.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool failed,
    VoidCallback? onRetry,
    double width = 400,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RefreshFailedNotice(
            failed: failed,
            onRetry: onRetry ?? () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final retry = find.widgetWithText(TextButton, 'Retry');

  for (final brightness in Brightness.values) {
    testWidgets('wears a warn badge\'s wash and icon colour (${brightness.name})', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                const StatusBadge(tone: StatusTone.warn, label: 'No data'),
                RefreshFailedNotice(failed: true, onRetry: () {}),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Color fillIn(Type widget) => (tester
                  .widgetList<Container>(
                    find.descendant(
                      of: find.byType(widget),
                      matching: find.byType(Container),
                    ),
                  )
                  .firstWhere((c) => c.decoration is BoxDecoration)
                  .decoration! as BoxDecoration)
          .color!;
      Color iconIn(Type widget) => tester
          .widget<Icon>(
            find.descendant(of: find.byType(widget), matching: find.byType(Icon)).first,
          )
          .color!;

      // Read off what each paints, so a notice that works out a tint of its
      // own drifts from the badge here, whatever the numbers.
      expect(fillIn(RefreshFailedNotice), fillIn(StatusBadge));
      expect(iconIn(RefreshFailedNotice), iconIn(StatusBadge));
    });
  }

  testWidgets('says nothing while the last refresh succeeded', (tester) async {
    await pump(tester, failed: false);

    expect(find.text("Couldn't refresh"), findsNothing);
    expect(retry, findsNothing);
  });

  testWidgets('says it in words and an icon, not a tint alone', (
    tester,
  ) async {
    var retried = 0;
    await pump(tester, failed: true, onRetry: () => retried++);

    expect(find.text("Couldn't refresh"), findsOneWidget);
    expect(find.byIcon(Icons.sync_problem_rounded), findsOneWidget);

    await tester.tap(retry);
    expect(retried, 1);
  });

  testWidgets('tells a screen reader what it means, and announces it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, failed: true);

    final notice = find.bySemanticsLabel(
      "Couldn't refresh. What's shown may be out of date.",
    );
    expect(notice, findsOneWidget);
    expect(
      tester.getSemantics(notice),
      matchesSemantics(
        label: "Couldn't refresh. What's shown may be out of date.",
        isLiveRegion: true,
        children: [
          matchesSemantics(
            label: 'Retry',
            isButton: true,
            isFocusable: true,
            isEnabled: true,
            hasEnabledState: true,
            hasTapAction: true,
            hasFocusAction: true,
          ),
        ],
      ),
    );
    semantics.dispose();
  });

  testWidgets('is a 44×44 target on a phone', (tester) async {
    await pump(tester, failed: true, width: 390);

    final size = tester.getSize(retry);
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('is at least 32×32 on a desktop, where a pointer aims', (
    tester,
  ) async {
    await pump(tester, failed: true, width: 1400);

    final size = tester.getSize(retry);
    expect(size.width, greaterThanOrEqualTo(32));
    expect(size.height, greaterThanOrEqualTo(32));
  });
}
