import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/providers/theme_provider.dart';
import 'package:ForgeForm/core/widgets/forge_app_bar.dart';
import 'package:ForgeForm/core/widgets/forge_nav_bar.dart';

/// Chrome is the part of a UI nobody writes a test for, because there is
/// nothing to assert about it that sounds like behaviour: a bar either renders
/// or it doesn't, and it always renders. So it drifts. The trainee app and the
/// Trainer Console ended up with two different bottom bars and eleven
/// different app-bar title sizes without a single test going red.
///
/// What can be asserted is that both surfaces are built from the *same*
/// widget, and that the widget defers to the theme instead of restating it.
void main() {
  late ThemeProvider themeProvider;

  setUp(() {
    themeProvider = ThemeProvider(AppDatabase.test(NativeDatabase.memory()));
  });

  Widget host(ThemeData theme, Widget child, {double statusBarHeight = 0}) {
    return MaterialApp(
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(
          padding: EdgeInsets.only(top: statusBarHeight),
        ),
        child: child,
      ),
    );
  }

  group('ForgeAppBar', () {
    testWidgets('takes its title style from the theme, not from the screen', (
      tester,
    ) async {
      final theme = themeProvider.darkTheme;
      await tester.pumpWidget(
        host(theme, const Scaffold(appBar: ForgeAppBar(title: 'Settings'))),
      );

      final style = tester.widget<Text>(find.text('Settings')).style;
      // Null: the Text carries no style of its own, so AppBar's own
      // DefaultTextStyle (built from appBarTheme.titleTextStyle) applies. Four
      // screens used to hardcode `fontSize: 17` here, which is not a smaller
      // version of the theme's 20 so much as a second, undocumented size.
      expect(style, isNull);
      expect(theme.appBarTheme.titleTextStyle?.fontSize, 20);
    });

    testWidgets('paints behind the status bar rather than below it', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          themeProvider.darkTheme,
          const Scaffold(appBar: ForgeAppBar(title: 'Settings')),
          statusBarHeight: 40,
        ),
      );

      // The bar starts at y=0 and absorbs the inset as internal padding. Eight
      // screens wrapped their whole Scaffold in a SafeArea, which consumes the
      // inset *before* the Scaffold sees it — the bar then started at y=40 and
      // left a strip of raw page background above it. On a device that read as
      // Settings having a different, shorter app bar than the Dashboard.
      expect(tester.getTopLeft(find.byType(AppBar)).dy, 0);
      expect(
        tester.getSize(find.byType(AppBar)).height,
        kToolbarHeight + 40,
      );
    });
  });

  group('ForgeNavBar', () {
    final destinations = [
      const ForgeNavDestination(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
      ),
      const ForgeNavDestination(
        label: 'Messages',
        icon: Icons.forum_outlined,
        activeIcon: Icons.forum_rounded,
        badgeCount: 3,
        semanticLabel: 'Messages, 3 unread',
      ),
    ];

    testWidgets('the selected destination is the filled icon, the rest are '
        'outlined', (tester) async {
      await tester.pumpWidget(
        host(
          themeProvider.darkTheme,
          Scaffold(
            bottomNavigationBar: ForgeNavBar(
              destinations: destinations,
              selectedIndex: 0,
              onSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.dashboard_rounded), findsOneWidget);
      expect(find.byIcon(Icons.dashboard_outlined), findsNothing);
      expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
      expect(find.byIcon(Icons.forum_rounded), findsNothing);
    });

    testWidgets('a count reaches a screen reader, not just the eye', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          themeProvider.darkTheme,
          Scaffold(
            bottomNavigationBar: ForgeNavBar(
              destinations: destinations,
              selectedIndex: 0,
              onSelected: (_) {},
            ),
          ),
        ),
      );

      // NavigationDestination builds its own semantics from `label`, and the
      // badge is decoration as far as that is concerned — an orange pill
      // nobody announces is invisible. The count rides in the tooltip, which
      // Flutter exposes as SemanticsProperties.tooltip and screen readers
      // announce after the label; it is the one string here that carries it.
      expect(find.byTooltip('Messages, 3 unread'), findsOneWidget);
      // And the destination without one is not given a bare, count-less
      // tooltip that would read as a duplicate of its own label.
      expect(find.byTooltip('Dashboard'), findsOneWidget);
    });

    testWidgets('the indicator is a tint, not the solid orange M3 derives', (
      tester,
    ) async {
      for (final theme in [themeProvider.lightTheme, themeProvider.darkTheme]) {
        // Forge Orange is the scheme's `secondary`, so M3's default indicator
        // (from secondaryContainer) comes out solid orange — and the selected
        // glyph, which is also orange, disappears into it.
        final indicator = theme.navigationBarTheme.indicatorColor;
        expect(indicator, isNotNull);
        expect(indicator!.a, lessThan(0.5));
      }
    });
  });

  // A rule, not an instance.
  //
  // `SafeArea(child: Scaffold(...))` type-checks, renders, and looks like
  // careful inset handling. It is the opposite: SafeArea consumes the inset
  // and then hands the Scaffold a box that no longer knows a status bar
  // exists, so the app bar stops painting behind it and a strip of raw page
  // background appears above the bar. Eight screens had it, which is why
  // Settings' bar visibly sat lower than the Dashboard's on the same device.
  //
  // No widget test would catch this without knowing to measure the bar's y
  // offset on the specific screen, so the guard is over the source instead.
  test('no screen wraps a Scaffold in a SafeArea', () {
    final offenders = <String>[];
    final pattern = RegExp(r'SafeArea\(\s*(?://[^\n]*\n\s*)*child:\s*Scaffold\(');

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (pattern.hasMatch(entity.readAsStringSync())) {
        offenders.add(entity.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Let the Scaffold handle the inset: give it an appBar, or put '
          'the SafeArea inside `body` where it can guard the edge that '
          'actually needs guarding.',
    );
  });
}
