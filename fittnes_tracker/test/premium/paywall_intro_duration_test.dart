import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:ForgeForm/feature/premium/paywall_screen.dart';
import 'package:ForgeForm/l10n/app_localizations_en.dart';

IntroductoryPrice _intro(PeriodUnit unit, int units, {int cycles = 1}) =>
    IntroductoryPrice(0, '€0.00', '', cycles, unit, units);

void main() {
  final en = AppLocalizationsEn();

  // RevenueCat's Android bridge turns a Play offer of P2W into 14 × DAY.
  test('a two-week Play trial reads as weeks, not days', () {
    expect(paywallIntroDuration(en, _intro(PeriodUnit.day, 14)), '2 weeks');
    expect(paywallIntroDuration(en, _intro(PeriodUnit.day, 7)), '1 week');
  });

  test('a day count that is not whole weeks stays in days', () {
    expect(paywallIntroDuration(en, _intro(PeriodUnit.day, 3)), '3 days');
    expect(paywallIntroDuration(en, _intro(PeriodUnit.day, 1)), '1 day');
  });

  test('cycles multiply the period', () {
    expect(paywallIntroDuration(en, _intro(PeriodUnit.month, 1, cycles: 3)), '3 months');
    expect(paywallIntroDuration(en, _intro(PeriodUnit.week, 2)), '2 weeks');
  });
}
