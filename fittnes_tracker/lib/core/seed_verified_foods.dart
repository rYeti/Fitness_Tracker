import 'dart:convert';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/utils/app_logger.dart';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

const _kSeedVersionKey = 'verified_foods_seed_version';

/// Seeds the verified-food layer from the bundled JSON asset.
///
/// Idempotent per asset `version`: re-runs only when the bundled version is
/// newer than the last seeded one, replacing the whole table (the asset is
/// the source of truth). Swapping the asset for a BLS 4.0 export re-seeds
/// every install on next launch with no code changes.
Future<void> seedVerifiedFoodsIfNeeded(AppDatabase db) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = await rootBundle.loadString('assets/data/verified_foods_de.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final version = json['version'] as int;

    if ((prefs.getInt(_kSeedVersionKey) ?? 0) >= version) return;

    final foods = (json['foods'] as List).cast<Map<String, dynamic>>();
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
          ),
      ]);
    });
    await prefs.setInt(_kSeedVersionKey, version);
    AppLogger.i('Seeded ${foods.length} verified foods (v$version)');
  } catch (e, st) {
    AppLogger.e('Verified food seed failed', e, st);
  }
}
