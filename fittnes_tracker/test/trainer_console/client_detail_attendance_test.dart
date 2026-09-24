import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/client_detail_screen.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

import 'fakes.dart';

/// Twelve Monday week starts, oldest first, 6 Jul – 21 Sep 2026: the window
/// from the screenshot where "20/7" and "24/8" wrapped onto two lines.
final _weeks = [
  for (var i = 0; i < 12; i++)
    AttendanceWeek(
      weekStart: DateTime(2026, 7, 6).add(Duration(days: 7 * i)),
      plannedSessions: 3,
      completedSessions: i % 4,
    ),
];

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ClientDetailScreen(
        clientId: 'c1',
        clientName: 'Maya Chen',
        repository: FakeTrainerConsoleRepository(
          workoutSummary: ClientWorkoutSummary(
            attendance: _weeks.reversed.toList(),
            strengthProgression: const [],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Iterable<Text> _weekLabels(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .where((t) => RegExp(r'^\d{1,2}/\d{1,2}$').hasMatch(t.data ?? ''));

void main() {
  // A spread of widths, because the bug only shows where short labels
  // ("6/7") fit a column and long ones ("20/7") don't.
  for (final (name, size) in [
    ('360 wide', const Size(360, 2400)),
    ('412 wide', const Size(412, 2400)),
    ('460 wide', const Size(460, 2400)),
    ('600 wide', const Size(600, 2400)),
    ('1400 wide', const Size(1400, 2400)),
  ]) {
    testWidgets('$name: every week label sits on one line, on one baseline', (
      tester,
    ) async {
      await _pump(tester, size);

      final labels = _weekLabels(tester).toList();
      expect(labels, isNotEmpty);

      final lineHeights = <double>{};
      final baselines = <double>{};
      for (final label in labels) {
        final box = tester.renderObject<RenderBox>(find.byWidget(label));
        lineHeights.add(box.size.height);
        baselines.add(box.localToGlobal(Offset.zero).dy);
      }
      // A wrapped label is twice as tall and sits higher than its neighbours.
      expect(lineHeights, hasLength(1));
      expect(baselines, hasLength(1));

      // Labels must not collide with one another either.
      final rects = [
        for (final label in labels) tester.getRect(find.byWidget(label)),
      ]..sort((a, b) => a.left.compareTo(b.left));
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].left, greaterThanOrEqualTo(rects[i - 1].right));
      }

      // The current week is always named.
      expect(labels.map((t) => t.data), contains('21/9'));
    });
  }

  testWidgets('desktop labels every week', (tester) async {
    await _pump(tester, const Size(1400, 2400));
    expect(_weekLabels(tester), hasLength(12));
  });
}
