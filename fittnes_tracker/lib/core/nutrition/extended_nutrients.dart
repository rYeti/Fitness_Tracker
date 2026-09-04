import 'dart:convert';

/// Extended nutritional data, sourced from OpenFoodFacts (crowdsourced/custom
/// foods) or the BLS 4.0 dataset (verified/seeded German staples — see
/// `tool/generate_verified_foods.py`). All fields are nullable — not every
/// food reports every value, and BLS's own legend is explicit that a missing
/// value must never be read as zero.
///
/// Every field is stored in **grams**, regardless of source. OpenFoodFacts
/// already reports `*_100g` fields in grams; BLS reports mixed mg/µg/g and is
/// converted to grams once, at import time. Display units (mg, µg) are a
/// presentation concern — see [lib/core/nutrition/nutrient_defs.dart] for the
/// gram-to-display conversion, so every surface that shows a number agrees
/// with every other surface about what it means.
///
/// Lives in `core` — not `feature/food_tracking` — for the same reason
/// `meal_category.dart` does: both the trainee food tracker and the Trainer
/// Console read and sum these values, and a fold kept in one feature module
/// is a fold the other feature can silently drift away from.
class ExtendedNutrients {
  // Macro detail
  final double? fiber;
  final double? sugar;
  final double? saturatedFat;
  final double? salt;
  final double? sodium;

  // Vitamins
  final double? vitaminA;
  final double? vitaminC;
  final double? vitaminD;
  final double? vitaminE;
  final double? vitaminK;
  final double? vitaminB1;  // thiamine
  final double? vitaminB2;  // riboflavin
  final double? vitaminB3;  // niacin
  final double? vitaminB6;
  final double? vitaminB9;  // folate
  final double? vitaminB12;

  // Minerals
  final double? calcium;
  final double? iron;
  final double? magnesium;
  final double? potassium;
  final double? zinc;

  const ExtendedNutrients({
    this.fiber,
    this.sugar,
    this.saturatedFat,
    this.salt,
    this.sodium,
    this.vitaminA,
    this.vitaminC,
    this.vitaminD,
    this.vitaminE,
    this.vitaminK,
    this.vitaminB1,
    this.vitaminB2,
    this.vitaminB3,
    this.vitaminB6,
    this.vitaminB9,
    this.vitaminB12,
    this.calcium,
    this.iron,
    this.magnesium,
    this.potassium,
    this.zinc,
  });

  static const empty = ExtendedNutrients();

  bool get hasAnyData => [
        fiber, sugar, saturatedFat, salt, sodium,
        vitaminA, vitaminC, vitaminD, vitaminE, vitaminK,
        vitaminB1, vitaminB2, vitaminB3, vitaminB6, vitaminB9, vitaminB12,
        calcium, iron, magnesium, potassium, zinc,
      ].any((v) => v != null);

  // ── OpenFoodFacts parsing ─────────────────────────────────────────────────

  factory ExtendedNutrients.fromNutriments(Map<String, dynamic> n) {
    double? g(String key) {
      final v = n[key];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return ExtendedNutrients(
      fiber:        g('fiber_100g'),
      sugar:        g('sugars_100g'),
      saturatedFat: g('saturated-fat_100g'),
      salt:         g('salt_100g'),
      sodium:       g('sodium_100g'),
      vitaminA:     g('vitamin-a_100g'),
      vitaminC:     g('vitamin-c_100g'),
      vitaminD:     g('vitamin-d_100g'),
      vitaminE:     g('vitamin-e_100g'),
      vitaminK:     g('vitamin-k_100g'),
      vitaminB1:    g('vitamin-b1_100g'),
      vitaminB2:    g('vitamin-b2_100g'),
      vitaminB3:    g('vitamin-pp_100g'),
      vitaminB6:    g('vitamin-b6_100g'),
      vitaminB9:    g('vitamin-b9_100g'),
      vitaminB12:   g('vitamin-b12_100g'),
      calcium:      g('calcium_100g'),
      iron:         g('iron_100g'),
      magnesium:    g('magnesium_100g'),
      potassium:    g('potassium_100g'),
      zinc:         g('zinc_100g'),
    );
  }

  // ── JSON persistence ──────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        if (fiber        != null) 'fiber':        fiber,
        if (sugar        != null) 'sugar':        sugar,
        if (saturatedFat != null) 'saturatedFat': saturatedFat,
        if (salt         != null) 'salt':         salt,
        if (sodium       != null) 'sodium':       sodium,
        if (vitaminA     != null) 'vitaminA':     vitaminA,
        if (vitaminC     != null) 'vitaminC':     vitaminC,
        if (vitaminD     != null) 'vitaminD':     vitaminD,
        if (vitaminE     != null) 'vitaminE':     vitaminE,
        if (vitaminK     != null) 'vitaminK':     vitaminK,
        if (vitaminB1    != null) 'vitaminB1':    vitaminB1,
        if (vitaminB2    != null) 'vitaminB2':    vitaminB2,
        if (vitaminB3    != null) 'vitaminB3':    vitaminB3,
        if (vitaminB6    != null) 'vitaminB6':    vitaminB6,
        if (vitaminB9    != null) 'vitaminB9':    vitaminB9,
        if (vitaminB12   != null) 'vitaminB12':   vitaminB12,
        if (calcium      != null) 'calcium':      calcium,
        if (iron         != null) 'iron':         iron,
        if (magnesium    != null) 'magnesium':    magnesium,
        if (potassium    != null) 'potassium':    potassium,
        if (zinc         != null) 'zinc':         zinc,
      };

  String toJsonString() => jsonEncode(toJson());

  factory ExtendedNutrients.fromJsonString(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return ExtendedNutrients.fromJson(map);
  }

  factory ExtendedNutrients.fromJson(Map<String, dynamic> map) {
    double? d(String k) => (map[k] as num?)?.toDouble();
    return ExtendedNutrients(
      fiber:        d('fiber'),
      sugar:        d('sugar'),
      saturatedFat: d('saturatedFat'),
      salt:         d('salt'),
      sodium:       d('sodium'),
      vitaminA:     d('vitaminA'),
      vitaminC:     d('vitaminC'),
      vitaminD:     d('vitaminD'),
      vitaminE:     d('vitaminE'),
      vitaminK:     d('vitaminK'),
      vitaminB1:    d('vitaminB1'),
      vitaminB2:    d('vitaminB2'),
      vitaminB3:    d('vitaminB3'),
      vitaminB6:    d('vitaminB6'),
      vitaminB9:    d('vitaminB9'),
      vitaminB12:   d('vitaminB12'),
      calcium:      d('calcium'),
      iron:         d('iron'),
      magnesium:    d('magnesium'),
      potassium:    d('potassium'),
      zinc:         d('zinc'),
    );
  }

  // ── Rescaling ─────────────────────────────────────────────────────────────

  /// Returns a copy rescaled from a food whose stored values represent
  /// [fromGrams] of it to one representing [toGrams].
  ///
  /// Deliberately explicit on both ends — there is no "the caller means
  /// per-100g" default. That implicit contract (the old `scaleTo(grams)`,
  /// which always divided by 100) is exactly what let a re-added local food's
  /// macros and micronutrients scale by two different factors: the macros
  /// correctly divided by that food's own base serving while this divided by
  /// 100 regardless of what the value actually represented. See
  /// `docs/trainer-console-micronutrients.md`.
  ExtendedNutrients rescale({required double fromGrams, required double toGrams}) {
    if (fromGrams == toGrams || fromGrams == 0) return this;
    final r = toGrams / fromGrams;
    double? s(double? v) => v == null ? null : v * r;
    return ExtendedNutrients(
      fiber:        s(fiber),
      sugar:        s(sugar),
      saturatedFat: s(saturatedFat),
      salt:         s(salt),
      sodium:       s(sodium),
      vitaminA:     s(vitaminA),
      vitaminC:     s(vitaminC),
      vitaminD:     s(vitaminD),
      vitaminE:     s(vitaminE),
      vitaminK:     s(vitaminK),
      vitaminB1:    s(vitaminB1),
      vitaminB2:    s(vitaminB2),
      vitaminB3:    s(vitaminB3),
      vitaminB6:    s(vitaminB6),
      vitaminB9:    s(vitaminB9),
      vitaminB12:   s(vitaminB12),
      calcium:      s(calcium),
      iron:         s(iron),
      magnesium:    s(magnesium),
      potassium:    s(potassium),
      zinc:         s(zinc),
    );
  }

  // ── Folding ───────────────────────────────────────────────────────────────

  /// Null-preserving addition: a nutrient neither side reported stays null,
  /// never becomes a reported zero. `null + null == null`, `null + 5 == 5`.
  ///
  /// This is the whole reason every field here is nullable — a bar drawn from
  /// `a ?? 0 + b ?? 0` reads "ate none of this" for what should read
  /// "nobody said". See `docs/trainer-console-micronutrients.md`.
  ExtendedNutrients operator +(ExtendedNutrients other) {
    double? add(double? a, double? b) =>
        a == null && b == null ? null : (a ?? 0) + (b ?? 0);
    return ExtendedNutrients(
      fiber:        add(fiber, other.fiber),
      sugar:        add(sugar, other.sugar),
      saturatedFat: add(saturatedFat, other.saturatedFat),
      salt:         add(salt, other.salt),
      sodium:       add(sodium, other.sodium),
      vitaminA:     add(vitaminA, other.vitaminA),
      vitaminC:     add(vitaminC, other.vitaminC),
      vitaminD:     add(vitaminD, other.vitaminD),
      vitaminE:     add(vitaminE, other.vitaminE),
      vitaminK:     add(vitaminK, other.vitaminK),
      vitaminB1:    add(vitaminB1, other.vitaminB1),
      vitaminB2:    add(vitaminB2, other.vitaminB2),
      vitaminB3:    add(vitaminB3, other.vitaminB3),
      vitaminB6:    add(vitaminB6, other.vitaminB6),
      vitaminB9:    add(vitaminB9, other.vitaminB9),
      vitaminB12:   add(vitaminB12, other.vitaminB12),
      calcium:      add(calcium, other.calcium),
      iron:         add(iron, other.iron),
      magnesium:    add(magnesium, other.magnesium),
      potassium:    add(potassium, other.potassium),
      zinc:         add(zinc, other.zinc),
    );
  }

  /// Folds a collection with [operator +]. Returns [empty] (all-null) for an
  /// empty iterable, not a data point about "zero intake".
  static ExtendedNutrients sum(Iterable<ExtendedNutrients> values) =>
      values.fold(empty, (acc, v) => acc + v);
}
