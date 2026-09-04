import 'dart:convert';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/nutrition/extended_nutrients.dart';
import 'package:ForgeForm/core/utils/app_logger.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

const _kSeedVersionKey = 'verified_foods_seed_version';

/// The `version` field of `assets/data/verified_foods_de.json`.
///
/// Duplicated here so the prefs gate can be checked *before* the 1.2 MB asset
/// is read and decoded — reading the version out of the JSON meant paying the
/// full parse on every launch just to discover there was nothing to do.
/// `test/seed/seed_versions_test.dart` fails if this drifts from the asset.
const kVerifiedFoodsSeedVersion = 3;

/// Seeds the verified-food layer from the bundled JSON asset.
///
/// Idempotent per [kVerifiedFoodsSeedVersion]: re-runs only when the bundled
/// version is newer than the last seeded one, replacing the whole table (the
/// asset is the source of truth). Swapping the asset for a newer BLS export
/// re-seeds every install on next launch — bump the constant to match.
Future<void> seedVerifiedFoodsIfNeeded(AppDatabase db) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getInt(_kSeedVersionKey) ?? 0) >= kVerifiedFoodsSeedVersion) {
      return;
    }

    // loadString has to stay on this isolate (it's a platform channel), but the
    // decode is the expensive half — ~7k entries — so it goes to a worker.
    final raw = await rootBundle.loadString('assets/data/verified_foods_de.json');
    final foods = await compute(_parseFoods, raw);

    // Single batch statement so a full BLS-sized dataset (~7k rows) seeds in
    // well under a second instead of 7k round-trips.
    await db.batch((batch) {
      batch.deleteAll(db.verifiedFoodTable);
      batch.insertAll(db.verifiedFoodTable, [
        for (final f in foods)
          VerifiedFoodTableCompanion.insert(
            name: f['name'] as String,
            nameDe: Value(f['nameDe'] as String?),
            calories: f['calories'] as int,
            protein: (f['protein'] as num).toDouble(),
            carbs: (f['carbs'] as num).toDouble(),
            fat: (f['fat'] as num).toDouble(),
            sourceCode: Value(f['sourceCode'] as String?),
            extendedNutrientsJson: Value(_encodeExtendedNutrients(f)),
          ),
      ]);
    });
    await prefs.setInt(_kSeedVersionKey, kVerifiedFoodsSeedVersion);
    AppLogger.i(
      'Seeded ${foods.length} verified foods (v$kVerifiedFoodsSeedVersion)',
    );
  } catch (e, st) {
    AppLogger.e('Verified food seed failed', e, st);
  }
}

/// Runs on a worker isolate — returns plain JSON types so the result is cheap
/// to send back.
List<Map<String, dynamic>> _parseFoods(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return (json['foods'] as List).cast<Map<String, dynamic>>();
}

/// Re-encodes a food's `extendedNutrients` object (added by
/// `tool/generate_verified_foods.py`, joined in from BLS 4.0) as the same
/// JSON shape [ExtendedNutrients.toJsonString] produces, so a verified food
/// and an OpenFoodFacts food are indistinguishable to every reader of this
/// column. Null when the asset carries no micronutrient data for this food.
String? _encodeExtendedNutrients(Map<String, dynamic> f) {
  final raw = f['extendedNutrients'] as Map<String, dynamic>?;
  if (raw == null) return null;
  return ExtendedNutrients.fromJson(raw).toJsonString();
}
