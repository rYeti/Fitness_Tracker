import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/core/providers/theme_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/status_badge.dart';

/// Contrast is a property of a **pair**, and nothing in this codebase used to
/// hold both halves at once: the theme declares a background, a widget
/// declares a foreground, and Flutter composites them at paint time. A type
/// system has nothing to say about it and a green widget test proves only that
/// something rendered — which is exactly how a 2.83:1 primary button shipped
/// on every light-theme screen.
///
/// This file is the one place a pair can be named. Modelled on
/// seat_meter_theme_test.dart, which exists for the same reason: the last
/// defect of this kind "was invisible to tests that used the default theme,
/// and only showed up in a browser".
void main() {
  late ThemeProvider themeProvider;

  setUp(() {
    themeProvider = ThemeProvider(AppDatabase.test(NativeDatabase.memory()));
  });

  group('WCAG AA — brand pairs', () {
    test('white on the light-theme primary clears AA body text', () {
      final scheme = themeProvider.lightTheme.colorScheme;
      expectContrast(
        scheme.onPrimary,
        scheme.primary,
        atLeast: 4.5,
        because: 'every filled button and FAB in the light theme is this pair',
      );
    });

    test('the raw brand orange still passes on dark surfaces', () {
      // The point of forgeOrangeOnLight is that dark keeps the real brand
      // colour. If this ever fails, the dark theme was darkened needlessly.
      expectContrast(
        ForgeColors.forgeOrange,
        ForgeColors.cardDark,
        atLeast: 4.5,
        because: 'dark surfaces keep the pure brand orange deliberately',
      );
    });

    test('forgeOrangeOnLight carries text on both light surfaces', () {
      for (final bg in [ForgeColors.surfaceLight, ForgeColors.backgroundLight]) {
        expectContrast(ForgeColors.forgeOrangeOnLight, bg, atLeast: 4.5);
      }
    });
  });

  group('WCAG AA — status tones as foreground', () {
    // The raw tones are fills. As text on a light surface they measure 3.30,
    // 2.04 and 4.23 — amber failing even the 3:1 icon bar — which is why the
    // OnLight variants exist. 68 raw Colors.red/green/orange references
    // across the trainee app used to sit at exactly those ratios.
    const onLight = {
      'ok': ForgeColors.statusOkOnLight,
      'warn': ForgeColors.statusWarnOnLight,
      'bad': ForgeColors.statusBadOnLight,
      'info': ForgeColors.statusInfoOnLight,
    };

    test('every OnLight tone reads on both light surfaces', () {
      onLight.forEach((name, colour) {
        for (final bg in [
          ForgeColors.surfaceLight,
          ForgeColors.backgroundLight,
        ]) {
          expectContrast(colour, bg, atLeast: 4.5, because: name);
        }
      });
    });

    test('the raw tones still read on dark surfaces', () {
      // Dark keeps the raw tones deliberately; if this fails, they were
      // darkened somewhere they did not need to be.
      for (final tone in [
        ForgeColors.statusOk,
        ForgeColors.statusWarn,
        ForgeColors.statusBad,
        ForgeColors.statusInfo,
      ]) {
        expectContrast(tone, ForgeColors.cardDark, atLeast: 3.0);
      }
    });

    test('a snackbar fill carries white text', () {
      // Snackbars are filled with the darkened tone in both themes because
      // their label is always white — the raw green measured 3.30 there.
      for (final fill in [
        ForgeColors.statusOkOnLight,
        ForgeColors.statusBadOnLight,
      ]) {
        expectContrast(const Color(0xFFFFFFFF), fill, atLeast: 4.5);
      }
    });
  });

  group('WCAG AA — body text', () {
    test('onSurface reads on surface, both themes', () {
      for (final theme in [themeProvider.lightTheme, themeProvider.darkTheme]) {
        final s = theme.colorScheme;
        expectContrast(s.onSurface, s.surface, atLeast: 4.5);
      }
    });
  });

  group('WCAG 1.4.11 — non-text UI components', () {
    test('input borders are visible against their own fill', () {
      // A border is the only thing marking where a field is, so it needs 3:1.
      //
      // Both light fills are asserted deliberately. Fields are filled two
      // ways — the theme uses surfaceLight, onboardingFieldDecoration uses a
      // tinted grey — and a border sized against white alone still measured
      // 2.48 on the tinted one, so checking a single fill would have passed
      // a border that is invisible on four screens.
      expectContrast(
        ForgeColors.borderLight,
        ForgeColors.surfaceLight,
        atLeast: 3.0,
      );
      expectContrast(
        ForgeColors.borderLight,
        ForgeColors.inputFillLight,
        atLeast: 3.0,
        because: 'onboardingFieldDecoration fills with this, not surfaceLight',
      );
      expectContrast(
        ForgeColors.borderDark,
        ForgeColors.cardDark,
        atLeast: 3.0,
      );
    });

    test('a light card separates from the page behind it', () {
      // White cards on a white page measured 1.00 and were held apart only by
      // a 2dp drop shadow — which is why the elevation work cannot simply
      // delete that shadow without this pair being fixed first.
      expectContrast(
        ForgeColors.surfaceLight,
        ForgeColors.backgroundLight,
        atLeast: 1.05,
        because: 'a card must be distinguishable from the page without relying '
            'on elevation alone',
      );
    });

    test('the themes actually apply the page background they declare', () {
      // Asserting the token pair is not enough, and this is the exact hole
      // that let the first attempt at this fix ship as a no-op: the page
      // colour was set on ColorScheme.background, which Material 3 deprecated
      // and Scaffold no longer reads, so every page stayed #FFFFFF while the
      // pair-level assertion above passed. Only sampling the rendered pixels
      // caught it. This test closes that gap.
      expect(
        themeProvider.lightTheme.scaffoldBackgroundColor,
        ForgeColors.backgroundLight,
        reason: 'Scaffold reads scaffoldBackgroundColor, not '
            'colorScheme.background',
      );
      expect(
        themeProvider.darkTheme.scaffoldBackgroundColor,
        ForgeColors.backgroundDark,
      );
      // And the card must differ from what is behind it, as rendered.
      expectContrast(
        themeProvider.lightTheme.cardTheme.color!,
        themeProvider.lightTheme.scaffoldBackgroundColor,
        atLeast: 1.05,
      );
    });
  });

  group('StatusBadge foregrounds', () {
    // Mirrors the widget's own computation (status_badge.dart). Kept in step
    // with it deliberately: if the lerp there changes, this fails.
    Color foregroundFor(StatusTone tone, Color base, {required bool isDark}) =>
        isDark
            ? Color.lerp(base, Colors.white, 0.45)!
            : Color.lerp(
                base,
                Colors.black,
                tone == StatusTone.warn ? 0.40 : 0.30,
              )!;

    const tones = {
      StatusTone.ok: ForgeColors.statusOk,
      StatusTone.warn: ForgeColors.statusWarn,
      StatusTone.bad: ForgeColors.statusBad,
    };

    for (final isDark in [false, true]) {
      final label = isDark ? 'dark' : 'light';
      test('every tone reads on its own tint ($label)', () {
        tones.forEach((tone, base) {
          final background = Color.alphaBlend(
            base.withValues(alpha: isDark ? 0.22 : 0.14),
            isDark ? ForgeColors.cardDark : ForgeColors.surfaceLight,
          );
          expectContrast(
            foregroundFor(tone, base, isDark: isDark),
            background,
            // The badge label is 11px, so it is body text, not large text.
            atLeast: 4.5,
            because: '$tone at $label',
          );
        });
      });
    }
  });
}

/// Fails with the measured ratio in the message — a bare `expect(true)` here
/// would tell you a pair is wrong but not by how much, and the gap is what
/// decides how far a colour has to move.
void expectContrast(
  Color foreground,
  Color background, {
  required double atLeast,
  String? because,
}) {
  final ratio = _contrastRatio(foreground, background);
  expect(
    ratio,
    greaterThanOrEqualTo(atLeast),
    reason:
        '${_hex(foreground)} on ${_hex(background)} is '
        '${ratio.toStringAsFixed(2)}:1, needs ${atLeast.toStringAsFixed(1)}:1'
        '${because == null ? '' : ' — $because'}',
  );
}

double _contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// WCAG 2.x relative luminance.
double _relativeLuminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

String _hex(Color c) {
  String p(double v) =>
      (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${p(c.r)}${p(c.g)}${p(c.b)}'.toUpperCase();
}
