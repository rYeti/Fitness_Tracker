#!/usr/bin/env python3
"""
Translates exercise names and descriptions from English to German using Claude.

Usage:
    ANTHROPIC_API_KEY=sk-... python3 tool/translate_exercises.py

Outputs: tool/translations_de.json
Then run: python3 tool/generate_seeds.py  (to bake them into seed_exercises.dart)
"""
import csv, json, os, re, sys, time
import anthropic

BATCH_SIZE = 30
CACHE_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'translations_de.json')

# ── Helpers ──────────────────────────────────────────────────────────────────

def load_csv(csv_path: str) -> list:
    with open(csv_path, newline='', encoding='utf-8') as f:
        content = f.read().lstrip('\n')
    return list(csv.DictReader(content.splitlines()))

def load_cache() -> dict:
    if os.path.exists(CACHE_FILE):
        with open(CACHE_FILE, encoding='utf-8') as f:
            return json.load(f)
    return {}

def save_cache(cache: dict):
    with open(CACHE_FILE, 'w', encoding='utf-8') as f:
        json.dump(cache, f, ensure_ascii=False, indent=2)

def parse_json_list(raw: str) -> list:
    try:
        result = json.loads(raw)
        return result if isinstance(result, list) else []
    except Exception:
        return []

def build_description(instructions_raw: str) -> str:
    steps = parse_json_list(instructions_raw)
    if not steps:
        return ''
    text = ' '.join(str(s).strip() for s in steps)
    if len(text) > 400:
        text = text[:400].rsplit(' ', 1)[0] + '...'
    return text

# ── Translation via Claude API ────────────────────────────────────────────────

SYSTEM_PROMPT = """\
You are a professional fitness translator specialising in German gym terminology.
Translate the given exercise names and descriptions from English to German.
Use standard German gym/fitness vocabulary (e.g. Langhantel, Kurzhantel, Kniebeuge).
Keep brand names and proper nouns (Arnold, Smith) unchanged.
Return ONLY a JSON array matching the input order, each element:
{"nameDe": "...", "descriptionDe": "..."}
descriptionDe may be null if the input description is empty.
"""

def translate_batch(client: anthropic.Anthropic, batch: list[dict]) -> list[dict]:
    """batch: list of {name, description}. Returns list of {nameDe, descriptionDe}."""
    payload = json.dumps(batch, ensure_ascii=False)
    message = client.messages.create(
        model='claude-opus-4-7',
        max_tokens=4096,
        system=SYSTEM_PROMPT,
        messages=[{'role': 'user', 'content': payload}],
    )
    raw = message.content[0].text.strip()
    # Strip markdown code fences if present
    raw = re.sub(r'^```json\s*', '', raw)
    raw = re.sub(r'\s*```$', '', raw)
    return json.loads(raw)

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    api_key = os.environ.get('ANTHROPIC_API_KEY')
    if not api_key:
        print('ERROR: ANTHROPIC_API_KEY not set.', file=sys.stderr)
        print('Run: ANTHROPIC_API_KEY=sk-... python3 tool/translate_exercises.py', file=sys.stderr)
        sys.exit(1)

    script_dir = os.path.dirname(os.path.abspath(__file__))
    root = os.path.join(script_dir, '..')
    csv_path = os.path.join(root, 'exercises', 'exercises.csv')

    client = anthropic.Anthropic(api_key=api_key)
    rows = load_csv(csv_path)
    cache = load_cache()

    pending = [
        {'name': r['name'].strip(), 'description': build_description(r.get('instructions', '[]'))}
        for r in rows
        if r['name'].strip() not in cache
    ]

    print(f'Cached: {len(cache)}  |  To translate: {len(pending)}')
    if not pending:
        print('All done — nothing to do.')
        return

    total_batches = (len(pending) + BATCH_SIZE - 1) // BATCH_SIZE
    for i in range(0, len(pending), BATCH_SIZE):
        batch = pending[i:i + BATCH_SIZE]
        batch_num = i // BATCH_SIZE + 1
        print(f'Batch {batch_num}/{total_batches} ({len(batch)} exercises)...', end=' ', flush=True)
        try:
            results = translate_batch(client, batch)
            for item, result in zip(batch, results):
                cache[item['name']] = result
            save_cache(cache)
            print('OK')
        except Exception as e:
            print(f'FAILED: {e}')
            print('Progress saved. Re-run the script to continue.')
            sys.exit(1)
        time.sleep(0.3)  # gentle rate limiting

    print(f'\nDone. {len(cache)} translations saved to {CACHE_FILE}')
    print('Now run: python3 tool/generate_seeds.py')

if __name__ == '__main__':
    main()
