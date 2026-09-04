import 'package:ForgeForm/core/nutrition/extended_nutrients.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// Which section of the micronutrient table a nutrient belongs in. Shown as
/// a muted caption beside the nutrient's label — see the Trainer Console
/// Nutrition tab and Food Detail handoff.
enum NutrientGroup { carbohydrate, fat, mineral, vitamin }

extension NutrientGroupLabel on NutrientGroup {
  String label(AppLocalizations l10n) => switch (this) {
    NutrientGroup.carbohydrate => l10n.nutrientGroupCarbohydrate,
    NutrientGroup.fat => l10n.nutrientGroupFat,
    NutrientGroup.mineral => l10n.nutrientGroupMineral,
    NutrientGroup.vitamin => l10n.nutrientGroupVitamin,
  };
}

/// One nutrient's identity, display unit, daily reference target and whether
/// lower is better — the single definition every surface (trainee food
/// detail, Trainer Console Nutrition tab and meal detail, and the C# parity
/// test) reads from, so a target or a unit can never drift between them.
///
/// [ExtendedNutrients] stores every value in **grams**; [gramsToDisplay] is
/// the factor this def multiplies by to reach [displayUnit] (e.g. 1000 for
/// mg, 1e6 for µg). Getting a unit wrong here is not a compiler error and
/// nothing else catches it — see `docs/trainer-console-micronutrients.md`.
///
/// [target] is a general-population reference intake (the design's own 10
/// values, or an EU NRV value — see the doc for the full table and why the
/// two provenances disagree on a few numbers), never a per-client goal: this
/// app has no per-client micronutrient targets, and the UI says "of 30 g",
/// never "your target".
class NutrientDef {
  final String key;
  final String Function(AppLocalizations) label;
  final NutrientGroup group;
  final String Function(AppLocalizations) displayUnit;
  final double gramsToDisplay;
  final double target;
  final bool invert;
  final double? Function(ExtendedNutrients) valueOf;

  const NutrientDef({
    required this.key,
    required this.label,
    required this.group,
    required this.displayUnit,
    required this.gramsToDisplay,
    required this.target,
    required this.valueOf,
    this.invert = false,
  });

  /// This nutrient's value from [n], converted from storage grams to
  /// [displayUnit]. Null stays null — "not reported" must never become "0".
  double? displayValue(ExtendedNutrients n) {
    final grams = valueOf(n);
    return grams == null ? null : grams * gramsToDisplay;
  }

  /// [displayValue] as a fraction of [target] (in the same display unit),
  /// for a progress bar. Null when there's nothing to show.
  double? ratio(ExtendedNutrients n) {
    final value = displayValue(n);
    if (value == null) return null;
    return value / target;
  }
}

const double _mg = 1000;
const double _ug = 1000000;

/// All 21 nutrients [ExtendedNutrients] carries, in display order (grouped:
/// Carbohydrate, Fat, Mineral, Vitamin, matching the trainee food detail
/// card's existing section order).
///
/// Targets marked "design" are the Trainer Console handoff's own values,
/// kept verbatim per its fidelity note. The rest are EU NRV values (Reg.
/// 1169/2011 Annex XIII) — the design specified 10 nutrients with targets;
/// the product wants bars for all 21, so the other 11 needed a source.
const List<NutrientDef> nutrientDefs = [
  // ── Carbohydrate ──────────────────────────────────────────────────────
  NutrientDef(
    key: 'fibre',
    label: _fiber,
    group: NutrientGroup.carbohydrate,
    displayUnit: _unitG,
    gramsToDisplay: 1,
    target: 30, // design
    valueOf: _fiberOf,
  ),
  NutrientDef(
    key: 'sugar',
    label: _sugar,
    group: NutrientGroup.carbohydrate,
    displayUnit: _unitG,
    gramsToDisplay: 1,
    target: 50, // design
    invert: true,
    valueOf: _sugarOf,
  ),
  // ── Fat ───────────────────────────────────────────────────────────────
  NutrientDef(
    key: 'satfat',
    label: _saturatedFat,
    group: NutrientGroup.fat,
    displayUnit: _unitG,
    gramsToDisplay: 1,
    target: 22, // design
    invert: true,
    valueOf: _satFatOf,
  ),
  // ── Mineral ───────────────────────────────────────────────────────────
  NutrientDef(
    key: 'salt',
    label: _salt,
    group: NutrientGroup.mineral,
    displayUnit: _unitG,
    gramsToDisplay: 1,
    target: 6, // NRV
    invert: true,
    valueOf: _saltOf,
  ),
  NutrientDef(
    key: 'sodium',
    label: _sodium,
    group: NutrientGroup.mineral,
    displayUnit: _unitMg,
    gramsToDisplay: _mg,
    target: 2300, // design
    invert: true,
    valueOf: _sodiumOf,
  ),
  NutrientDef(
    key: 'potassium',
    label: _potassium,
    group: NutrientGroup.mineral,
    displayUnit: _unitMg,
    gramsToDisplay: _mg,
    target: 3500, // design
    valueOf: _potassiumOf,
  ),
  NutrientDef(
    key: 'calcium',
    label: _calcium,
    group: NutrientGroup.mineral,
    displayUnit: _unitMg,
    gramsToDisplay: _mg,
    target: 1000, // design
    valueOf: _calciumOf,
  ),
  NutrientDef(
    key: 'iron',
    label: _iron,
    group: NutrientGroup.mineral,
    displayUnit: _unitMg,
    gramsToDisplay: _mg,
    target: 8, // design
    valueOf: _ironOf,
  ),
  NutrientDef(
    key: 'magnesium',
    label: _magnesium,
    group: NutrientGroup.mineral,
    displayUnit: _unitMg,
    gramsToDisplay: _mg,
    target: 400, // design
    valueOf: _magnesiumOf,
  ),
  NutrientDef(
    key: 'zinc',
    label: _zinc,
    group: NutrientGroup.mineral,
    displayUnit: _unitMg,
    gramsToDisplay: _mg,
    target: 10, // NRV
    valueOf: _zincOf,
  ),
  // ── Vitamin ───────────────────────────────────────────────────────────
  NutrientDef(
    key: 'vita',
    label: _vitaminA,
    group: NutrientGroup.vitamin,
    displayUnit: _unitUg,
    gramsToDisplay: _ug,
    target: 800, // NRV
    valueOf: _vitaminAOf,
  ),
  NutrientDef(
    key: 'vitc',
    label: _vitaminC,
    group: NutrientGroup.vitamin,
    displayUnit: _unitMg,
    gramsToDisplay: _mg,
    target: 90, // design
    valueOf: _vitaminCOf,
  ),
  NutrientDef(
    key: 'vitd',
    label: _vitaminD,
    group: NutrientGroup.vitamin,
    displayUnit: _unitUg,
    gramsToDisplay: _ug,
    target: 20, // design
    valueOf: _vitaminDOf,
  ),
  NutrientDef(
    key: 'vite',
    label: _vitaminE,
    group: NutrientGroup.vitamin,
    displayUnit: _unitMg,
    gramsToDisplay: _mg,
    target: 12, // NRV
    valueOf: _vitaminEOf,
  ),
  NutrientDef(
    key: 'vitk',
    label: _vitaminK,
    group: NutrientGroup.vitamin,
    displayUnit: _unitUg,
    gramsToDisplay: _ug,
    target: 75, // NRV
    valueOf: _vitaminKOf,
  ),
  NutrientDef(
    key: 'vitb1',
    label: _vitaminB1,
    group: NutrientGroup.vitamin,
    displayUnit: _unitMg,
    gramsToDisplay: _mg,
    target: 1.1, // NRV
    valueOf: _vitaminB1Of,
  ),
  NutrientDef(
    key: 'vitb2',
    label: _vitaminB2,
    group: NutrientGroup.vitamin,
    displayUnit: _unitMg,
    gramsToDisplay: _mg,
    target: 1.4, // NRV
    valueOf: _vitaminB2Of,
  ),
  NutrientDef(
    key: 'vitb3',
    label: _vitaminB3,
    group: NutrientGroup.vitamin,
    displayUnit: _unitMg,
    gramsToDisplay: _mg,
    target: 16, // NRV
    valueOf: _vitaminB3Of,
  ),
  NutrientDef(
    key: 'vitb6',
    label: _vitaminB6,
    group: NutrientGroup.vitamin,
    displayUnit: _unitMg,
    gramsToDisplay: _mg,
    target: 1.4, // NRV
    valueOf: _vitaminB6Of,
  ),
  NutrientDef(
    key: 'vitb9',
    label: _vitaminB9,
    group: NutrientGroup.vitamin,
    displayUnit: _unitUg,
    gramsToDisplay: _ug,
    target: 200, // NRV
    valueOf: _vitaminB9Of,
  ),
  NutrientDef(
    key: 'vitb12',
    label: _vitaminB12,
    group: NutrientGroup.vitamin,
    displayUnit: _unitUg,
    gramsToDisplay: _ug,
    target: 2.5, // NRV
    valueOf: _vitaminB12Of,
  ),
];

/// The design's own defaults for a trainer+client pair with no saved pin
/// selection, so the console and the trainee app start identical.
const List<String> defaultPinnedNutrientKeys = ['fibre', 'sugar', 'sodium'];

NutrientDef? nutrientDefForKey(String key) {
  for (final def in nutrientDefs) {
    if (def.key == key) return def;
  }
  return null;
}

// ── label/unit indirection (so the const list above can stay declarative) ──

String _fiber(AppLocalizations l) => l.nutrientFiber;
String _sugar(AppLocalizations l) => l.nutrientSugar;
String _saturatedFat(AppLocalizations l) => l.nutrientSaturatedFat;
String _salt(AppLocalizations l) => l.nutrientSalt;
String _sodium(AppLocalizations l) => l.nutrientSodium;
String _potassium(AppLocalizations l) => l.nutrientPotassium;
String _calcium(AppLocalizations l) => l.nutrientCalcium;
String _iron(AppLocalizations l) => l.nutrientIron;
String _magnesium(AppLocalizations l) => l.nutrientMagnesium;
String _zinc(AppLocalizations l) => l.nutrientZinc;
String _vitaminA(AppLocalizations l) => l.nutrientVitaminA;
String _vitaminC(AppLocalizations l) => l.nutrientVitaminC;
String _vitaminD(AppLocalizations l) => l.nutrientVitaminD;
String _vitaminE(AppLocalizations l) => l.nutrientVitaminE;
String _vitaminK(AppLocalizations l) => l.nutrientVitaminK;
String _vitaminB1(AppLocalizations l) => l.nutrientVitaminB1;
String _vitaminB2(AppLocalizations l) => l.nutrientVitaminB2;
String _vitaminB3(AppLocalizations l) => l.nutrientVitaminB3;
String _vitaminB6(AppLocalizations l) => l.nutrientVitaminB6;
String _vitaminB9(AppLocalizations l) => l.nutrientVitaminB9;
String _vitaminB12(AppLocalizations l) => l.nutrientVitaminB12;

String _unitG(AppLocalizations l) => l.unitG;
String _unitMg(AppLocalizations l) => l.unitMg;
String _unitUg(AppLocalizations l) => l.unitUg;

double? _fiberOf(ExtendedNutrients n) => n.fiber;
double? _sugarOf(ExtendedNutrients n) => n.sugar;
double? _satFatOf(ExtendedNutrients n) => n.saturatedFat;
double? _saltOf(ExtendedNutrients n) => n.salt;
double? _sodiumOf(ExtendedNutrients n) => n.sodium;
double? _potassiumOf(ExtendedNutrients n) => n.potassium;
double? _calciumOf(ExtendedNutrients n) => n.calcium;
double? _ironOf(ExtendedNutrients n) => n.iron;
double? _magnesiumOf(ExtendedNutrients n) => n.magnesium;
double? _zincOf(ExtendedNutrients n) => n.zinc;
double? _vitaminAOf(ExtendedNutrients n) => n.vitaminA;
double? _vitaminCOf(ExtendedNutrients n) => n.vitaminC;
double? _vitaminDOf(ExtendedNutrients n) => n.vitaminD;
double? _vitaminEOf(ExtendedNutrients n) => n.vitaminE;
double? _vitaminKOf(ExtendedNutrients n) => n.vitaminK;
double? _vitaminB1Of(ExtendedNutrients n) => n.vitaminB1;
double? _vitaminB2Of(ExtendedNutrients n) => n.vitaminB2;
double? _vitaminB3Of(ExtendedNutrients n) => n.vitaminB3;
double? _vitaminB6Of(ExtendedNutrients n) => n.vitaminB6;
double? _vitaminB9Of(ExtendedNutrients n) => n.vitaminB9;
double? _vitaminB12Of(ExtendedNutrients n) => n.vitaminB12;
