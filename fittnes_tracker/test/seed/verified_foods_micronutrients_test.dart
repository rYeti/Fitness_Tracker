import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `tool/generate_verified_foods.py` joins BLS 4.0 onto the verified-foods
/// seed at v2 -> v3. These tests read the committed asset directly (the same
/// approach `seed_versions_test.dart` uses) rather than re-running the
/// generator, so they catch a hand-edited or stale asset the same way a
/// broken generation run would leave one.
void main() {
  late Map<String, dynamic> asset;
  late List<dynamic> foods;

  setUpAll(() {
    final raw = File('assets/data/verified_foods_de.json').readAsStringSync();
    asset = jsonDecode(raw) as Map<String, dynamic>;
    foods = asset['foods'] as List<dynamic>;
  });

  test('the asset is at v3 or later', () {
    expect(asset['version'] as int, greaterThanOrEqualTo(3));
  });

  test('every food resolved its sourceCode against BLS', () {
    // tool/generate_verified_foods.py logs a warning and skips a food it
    // can't match, but every current row's sourceCode is a real BLS key, so
    // the join should be 100%, not merely "most of them".
    final withoutData = foods.where(
      (f) => (f as Map<String, dynamic>)['extendedNutrients'] == null,
    );
    expect(withoutData, isEmpty);
  });

  test('a known food carries the right converted values (oats, C131000)', () {
    final oats = foods.cast<Map<String, dynamic>>().firstWhere(
      (f) => f['sourceCode'] == 'C131000',
    );
    final nutrients = oats['extendedNutrients'] as Map<String, dynamic>;

    // BLS reports FIBT in grams (9.3g, no conversion), FE in mg (5.16mg ->
    // 0.00516g) and VITB6 in µg (960µg -> 0.00096g) — three different units,
    // three different factors, all converted to the same storage unit this
    // app uses everywhere else (grams). Getting any one factor wrong is
    // invisible until a value is compared to a target — see
    // docs/trainer-console-micronutrients.md.
    expect(nutrients['fiber'], closeTo(0.0093, 0.0001));
    expect(nutrients['iron'], closeTo(0.00516, 0.000001));
    expect(nutrients['vitaminB6'], closeTo(0.00096, 0.000001));
  });

  test('a BLS-reported zero is a real zero, not an absent key', () {
    // Oats' vitamin C is a genuine 0 in BLS (present, quantified, zero) —
    // must round-trip as 0.0, not be dropped the way a null/"TR" value is.
    final oats = foods.cast<Map<String, dynamic>>().firstWhere(
      (f) => f['sourceCode'] == 'C131000',
    );
    final nutrients = oats['extendedNutrients'] as Map<String, dynamic>;
    expect(nutrients.containsKey('vitaminC'), isTrue);
    expect(nutrients['vitaminC'], 0.0);
  });

  test('a nutrient BLS never quantified for a food is absent, not zero', () {
    // BLS's own legend: "no data available - do not interpret as zero".
    // Alfalfa sprouts (H640100) has no vitamin E entry in BLS at all.
    final sprouts = foods.cast<Map<String, dynamic>>().firstWhere(
      (f) => f['sourceCode'] == 'H640100',
    );
    final nutrients = sprouts['extendedNutrients'] as Map<String, dynamic>;
    expect(nutrients.containsKey('vitaminE'), isFalse);
  });
}
