import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/seed_verified_foods.dart';

/// The verified-food seeder checks its prefs gate *before* reading the asset,
/// so it can no longer read the version out of the JSON — the whole point is to
/// avoid decoding 1.2 MB on every launch just to learn there is nothing to do.
/// That leaves the constant able to drift from the asset, which would mean a
/// new food dataset shipping without ever being seeded. This catches that.
void main() {
  test('kVerifiedFoodsSeedVersion matches the bundled asset', () {
    final raw =
        File('assets/data/verified_foods_de.json').readAsStringSync();
    final assetVersion =
        (jsonDecode(raw) as Map<String, dynamic>)['version'] as int;

    expect(
      kVerifiedFoodsSeedVersion,
      assetVersion,
      reason:
          'assets/data/verified_foods_de.json is at v$assetVersion but '
          'kVerifiedFoodsSeedVersion is $kVerifiedFoodsSeedVersion. Bump the '
          'constant in lib/core/seed_verified_foods.dart so existing installs '
          're-seed.',
    );
  });
}
