#!/usr/bin/env python3
"""
Generates lib/core/seed_exercises_data.dart from exercises/exercises.csv.

Run from the fittnes_tracker/ directory:
    python3 tool/generate_seeds.py

The script:
  1. Extracts existing German translations from the current seed file (by name).
  2. Parses all 873 exercises from the CSV.
  3. Writes a fresh seed_exercises_data.dart preserving any German translations
     we already have and leaving nameDe null for the rest.
  4. Bumps kExerciseSeedVersion so existing installs re-run the seed once.

Only the *data* is generated. The seeding logic lives in the hand-written
lib/core/seed_exercises.dart and is never touched by this script.
"""
import csv, json, os, re, textwrap

# ── Mappings ────────────────────────────────────────────────────────────────

CATEGORY_MAP = {
    'strength':              'ExerciseType.strength',
    'powerlifting':          'ExerciseType.strength',
    'olympic weightlifting': 'ExerciseType.strength',
    'strongman':             'ExerciseType.strength',
    'plyometrics':           'ExerciseType.calisthenics',
    'stretching':            'ExerciseType.flexibility',
    'cardio':                'ExerciseType.cardio',
}

MUSCLE_MAP = {
    'abdominals':  'MuscleGroup.abs',
    'abductors':   'MuscleGroup.legs',
    'adductors':   'MuscleGroup.legs',
    'biceps':      'MuscleGroup.biceps',
    'calves':      'MuscleGroup.legs',
    'chest':       'MuscleGroup.chest',
    'forearms':    'MuscleGroup.biceps',
    'glutes':      'MuscleGroup.legs',
    'hamstrings':  'MuscleGroup.legs',
    'lats':        'MuscleGroup.back',
    'lower back':  'MuscleGroup.back',
    'middle back': 'MuscleGroup.back',
    'neck':        'MuscleGroup.fullBody',
    'quadriceps':  'MuscleGroup.legs',
    'shoulders':   'MuscleGroup.shoulders',
    'traps':       'MuscleGroup.back',
    'triceps':     'MuscleGroup.triceps',
}

# ── Helpers ─────────────────────────────────────────────────────────────────

def esc(s: str) -> str:
    """Escape a string for use inside Dart single-quoted string literals."""
    return s.replace('\\', '\\\\').replace("'", "\\'")

def parse_json_list(raw: str) -> list:
    try:
        result = json.loads(raw)
        if isinstance(result, list):
            return result
    except Exception:
        pass
    return []

def build_description(instructions_raw: str) -> str | None:
    steps = parse_json_list(instructions_raw)
    if not steps:
        return None
    text = ' '.join(str(s).strip() for s in steps)
    if len(text) > 400:
        text = text[:400].rsplit(' ', 1)[0] + '...'
    return text or None

def map_muscles(muscles_raw: str) -> list:
    muscles = parse_json_list(muscles_raw)
    seen = []
    for m in muscles:
        mapped = MUSCLE_MAP.get(m.strip().lower())
        if mapped and mapped not in seen:
            seen.append(mapped)
    return seen or ['MuscleGroup.fullBody']

# ── Step 1: extract existing German translations ─────────────────────────────

def load_existing_translations(seed_path: str) -> dict:
    """
    Returns {english_name: {nameDe, descriptionDe}} for every exercise in
    the current seed file that already has a German name.
    """
    if not os.path.exists(seed_path):
        return {}

    with open(seed_path, encoding='utf-8') as f:
        src = f.read()

    field_re = re.compile(r"(\w+):\s*'((?:[^'\\]|\\.)*)'")
    result = {}
    # Split on each Exercise( constructor — skip the preamble before the first one
    for block in re.split(r'\bExercise\(', src)[1:]:
        fields = dict(field_re.findall(block))
        name = fields.get('name')
        name_de = fields.get('nameDe')
        if name and name_de:
            result[name] = {
                'nameDe': name_de,
                'descriptionDe': fields.get('descriptionDe'),
            }
    return result

def read_seed_version(seed_path: str) -> int:
    """Current kExerciseSeedVersion in the generated file, or 0 if absent."""
    if not os.path.exists(seed_path):
        return 0
    with open(seed_path, encoding='utf-8') as f:
        m = re.search(r'const kExerciseSeedVersion = (\d+);', f.read())
    return int(m.group(1)) if m else 0

# ── Step 2: read CSV ─────────────────────────────────────────────────────────

def load_csv(csv_path: str) -> list:
    with open(csv_path, newline='', encoding='utf-8') as f:
        content = f.read().lstrip('\n')
    return list(csv.DictReader(content.splitlines()))

# ── Step 3: generate Dart source ─────────────────────────────────────────────

HEADER_TEMPLATE = """\
// AUTO-GENERATED — run `python3 tool/generate_seeds.py` to regenerate.
// Do not edit by hand.
//
// Data only. The seeding *logic* lives in seed_exercises.dart, which is
// hand-written and must never be regenerated.
import 'package:ForgeForm/feature/workout_planning/data/models/exercise.dart';

/// Bumped by the generator on every regeneration. seed_exercises.dart uses it
/// to decide whether a launch has any seeding work to do at all.
const kExerciseSeedVersion = {version};

final kSeedExercises = <Exercise>[
"""

CAT_ORDER = [
    'strength',
    'powerlifting',
    'olympic weightlifting',
    'strongman',
    'plyometrics',
    'cardio',
    'stretching',
]

def generate(rows: list, translations: dict, version: int) -> str:
    grouped: dict[str, list] = {}
    for row in rows:
        cat = row.get('category', 'strength').strip()
        grouped.setdefault(cat, []).append(row)

    parts = [HEADER_TEMPLATE.format(version=version)]

    for cat in CAT_ORDER:
        cat_rows = grouped.get(cat, [])
        if not cat_rows:
            continue
        dart_type = CATEGORY_MAP.get(cat, 'ExerciseType.strength')
        label = cat.upper()
        parts.append(f'  // ── {label} ({len(cat_rows)}) {"─" * 60}\n')

        for row in cat_rows:
            name = esc(row['name'].strip())
            desc = build_description(row.get('instructions', '[]'))
            muscles = map_muscles(row.get('primaryMuscles', '[]'))
            trans = translations.get(row['name'].strip(), {})
            name_de = trans.get('nameDe')
            desc_de = trans.get('descriptionDe')

            lines = ['  Exercise(', f"    name: '{name}',"]
            if desc:
                lines.append(f"    description: '{esc(desc)}',")
            if name_de:
                lines.append(f"    nameDe: '{esc(name_de)}',")
            if desc_de:
                lines.append(f"    descriptionDe: '{esc(desc_de)}',")
            lines.append(f"    type: {dart_type},")
            lines.append(f"    targetMuscleGroups: [{', '.join(muscles)}],")
            lines.append('  ),')
            parts.append('\n'.join(lines) + '\n')

    parts.append('];\n')
    return '\n'.join(parts)

# ── Main ─────────────────────────────────────────────────────────────────────

def load_json_translations(json_path: str) -> dict:
    """Load translations from the JSON cache produced by translate_exercises.py."""
    if not os.path.exists(json_path):
        return {}
    with open(json_path, encoding='utf-8') as f:
        raw = json.load(f)
    return {
        name: {'nameDe': v.get('nameDe'), 'descriptionDe': v.get('descriptionDe')}
        for name, v in raw.items()
        if v.get('nameDe')
    }


if __name__ == '__main__':
    script_dir = os.path.dirname(os.path.abspath(__file__))
    root = os.path.join(script_dir, '..')

    csv_path  = os.path.join(root, 'exercises', 'exercises.csv')
    seed_path = os.path.join(root, 'lib', 'core', 'seed_exercises_data.dart')
    json_path = os.path.join(script_dir, 'translations_de.json')

    print('Reading existing translations from seed file...')
    translations = load_existing_translations(seed_path)
    print(f'  {len(translations)} from seed file.')

    print('Reading translations from JSON cache...')
    json_translations = load_json_translations(json_path)
    print(f'  {len(json_translations)} from translations_de.json.')
    # JSON cache takes precedence (more complete)
    translations = {**translations, **json_translations}

    print('Parsing CSV...')
    rows = load_csv(csv_path)
    print(f'  {len(rows)} exercises loaded.')

    version = read_seed_version(seed_path) + 1
    print(f'Generating seed_exercises_data.dart (v{version})...')
    dart_src = generate(rows, translations, version)

    with open(seed_path, 'w', encoding='utf-8') as f:
        f.write(dart_src)

    translated_count = sum(1 for r in rows if r['name'].strip() in translations)
    print(f'Done. {len(rows)} exercises written ({translated_count} with German).')
    print(f'Output: {seed_path}')
