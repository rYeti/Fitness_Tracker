import 'dart:convert';

/// Extended nutritional data sourced from OpenFoodFacts.
/// All fields are nullable — not every product reports every value.
/// Stored in the database as a single JSON text column.
class ExtendedNutrients {
  // Macro detail
  final double? fiber;
  final double? sugar;
  final double? saturatedFat;
  final double? salt;
  final double? sodium;

  // Vitamins (per 100 g; µg where noted, otherwise mg)
  final double? vitaminA;    // µg
  final double? vitaminC;    // mg
  final double? vitaminD;    // µg
  final double? vitaminE;    // mg
  final double? vitaminK;    // µg
  final double? vitaminB1;   // mg  thiamine
  final double? vitaminB2;   // mg  riboflavin
  final double? vitaminB3;   // mg  niacin
  final double? vitaminB6;   // mg
  final double? vitaminB9;   // µg  folate
  final double? vitaminB12;  // µg

  // Minerals (mg per 100 g)
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

  // ── Scaling ───────────────────────────────────────────────────────────────

  /// Returns a copy scaled from per-100g values to [grams] consumed.
  ExtendedNutrients scaleTo(double grams) {
    if (grams == 100) return this;
    final r = grams / 100;
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
}
