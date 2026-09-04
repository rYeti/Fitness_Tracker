#!/usr/bin/env python3
"""
Regenerates assets/data/verified_foods_de.json with per-food micronutrients,
joined in from the BLS 4.0 nutrient matrix.

Run from the fittnes_tracker/ directory:
    python3 tool/generate_verified_foods.py

Inputs (both build-time only; not shipped in the app bundle):
  - assets/data/verified_foods_de.json  (existing, v2) — the name/nameDe/
    calories/protein/carbs/fat/sourceCode rows already seeded. This script
    treats it as the source of truth for those fields and only *adds* to it —
    the German names in here came from a BLS export the repo no longer
    contains, so they are input, not something this script derives.
  - assets/data/bls_nutrients.json — 7,140 foods x 138 BLS component codes,
    keyed by the same `sourceCode` (e.g. "C131000") as verified_foods_de.json.
    Values are a number, null ("no data available - do not interpret as
    zero", per the file's own legend), or the string "TR" (a trace amount,
    present but not quantified).
  - assets/data/bls_components.json — per-code metadata (name, unit, group).
    Units vary by code (mg, µg, g) and drive the gram conversion below —
    never hardcode a unit per nutrient key.

Output: assets/data/verified_foods_de.json, version bumped to 3, each food
gaining an `extendedNutrients` object (only for keys that resolved to a
value — a fold with a null in it should be able to tell a genuine zero from
"BLS never quantified this").

ExtendedNutrients values are stored in grams everywhere in this app (that's
already what every OpenFoodFacts-sourced row holds), so every BLS value is
converted mg/µg -> g here, at import time, not deferred to the client.

Deliberately NOT run automatically at build time or app startup: BLS is a
versioned external dataset (see DOI below) and the join is small enough to
commit its output, the same way tool/generate_seeds.py's CSV parse is never
re-run except by hand.
"""
import json
import sys

VERIFIED_FOODS_PATH = "assets/data/verified_foods_de.json"
BLS_NUTRIENTS_PATH = "assets/data/bls_nutrients.json"
BLS_COMPONENTS_PATH = "assets/data/bls_components.json"

NEW_VERSION = 3

# BLS code -> ExtendedNutrients JSON key (see
# lib/core/nutrition/extended_nutrients.dart for the Dart side of this table).
# Units come from bls_components.json at runtime, not hardcoded here.
BLS_CODE_TO_KEY = {
    "FIBT": "fiber",
    "SUGAR": "sugar",
    "FASAT": "saturatedFat",
    "NACL": "salt",
    "NA": "sodium",
    "VITA": "vitaminA",
    "VITC": "vitaminC",
    "VITD": "vitaminD",
    "VITE": "vitaminE",
    "VITK": "vitaminK",
    "THIA": "vitaminB1",
    "RIBF": "vitaminB2",
    "NIA": "vitaminB3",
    "VITB6": "vitaminB6",
    "FOL": "vitaminB9",
    "VITB12": "vitaminB12",
    "CA": "calcium",
    "FE": "iron",
    "MG": "magnesium",
    "K": "potassium",
    "ZN": "zinc",
}

# Conversion factor from the unit named in bls_components.json to grams.
UNIT_TO_GRAMS = {
    "g": 1.0,
    "mg": 0.001,
    "µg": 0.000001,
    "ug": 0.000001,
}


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def convert_to_grams(value, unit):
    """None/"TR" both mean "no usable quantity" and must stay absent — not 0.
    See the BLS legend: 'no data available - do not interpret as zero'."""
    if value is None:
        return None
    if isinstance(value, str):
        # "TR" (traces): present but not quantified. Any other string is a
        # data shape we don't understand yet — fail loudly rather than
        # silently treating it as missing.
        if value == "TR":
            return None
        raise ValueError(f"Unexpected non-numeric BLS value: {value!r}")
    factor = UNIT_TO_GRAMS.get(unit)
    if factor is None:
        raise ValueError(f"Unknown BLS unit: {unit!r}")
    return round(value * factor, 9)


def main():
    verified = load(VERIFIED_FOODS_PATH)
    bls = load(BLS_NUTRIENTS_PATH)
    components = load(BLS_COMPONENTS_PATH)["components"]

    codes = bls["codes"]
    bls_foods = bls["foods"]
    code_index = {code: codes.index(code) for code in BLS_CODE_TO_KEY}
    code_unit = {code: components[code]["unit"] for code in BLS_CODE_TO_KEY}

    matched = 0
    missing_source = []
    for food in verified["foods"]:
        source_code = food.get("sourceCode")
        row = bls_foods.get(source_code) if source_code else None
        if row is None:
            missing_source.append(source_code)
            continue

        extended = {}
        for code, key in BLS_CODE_TO_KEY.items():
            raw = row[code_index[code]]
            grams = convert_to_grams(raw, code_unit[code])
            if grams is not None:
                extended[key] = grams

        if extended:
            food["extendedNutrients"] = extended
            matched += 1

    verified["version"] = NEW_VERSION
    verified["citation"] = bls["citation"]
    verified["doi"] = bls["doi"]

    with open(VERIFIED_FOODS_PATH, "w", encoding="utf-8") as f:
        json.dump(verified, f, ensure_ascii=False, separators=(",", ":"))

    print(f"Matched {matched}/{len(verified['foods'])} foods against BLS.")
    if missing_source:
        print(
            f"WARNING: {len(missing_source)} foods had no BLS match: "
            f"{missing_source[:10]}",
            file=sys.stderr,
        )


if __name__ == "__main__":
    main()
