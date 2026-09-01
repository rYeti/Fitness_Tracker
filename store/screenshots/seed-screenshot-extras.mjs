#!/usr/bin/env node
/**
 * Tops up the seeded trainee with completed training history and logged sets,
 * so the Progress tab has something to draw.
 *
 * ── What this CANNOT fix, and why ──
 *
 * The Exercise Progress chart stays on "No workout data yet" however many sets
 * this logs. `SyncService` pushes `workoutSetTable` rows to the server and
 * never pulls them back: `_pullScheduledWorkouts` restores sessions and their
 * exercises, but no code path creates a local set row from a server one. A
 * fresh browser profile — which is what every capture run starts with — can
 * therefore only show sets it logged itself on that device.
 *
 * That is worth knowing beyond screenshots: a user reinstalling, or signing in
 * on a second device, gets their workouts, meals and weights back but not their
 * logged sets, so Exercise Progress and the "previous set" reference start
 * empty. Recorded in store/screenshots/README.md.
 *
 * Why this is separate from `e2e/tools/seed-review-data.mjs` rather than a
 * change to it: that seeder is the fixture the Playwright suite asserts
 * against, and its counts are load-bearing there ("15 scheduled workouts, 1
 * completed" is quoted in its own log line and mirrors the dashboard's "1/15").
 * Screenshots want a fuller account than tests do. Bending the shared fixture
 * to suit the marketing artwork is how a test fixture stops meaning anything,
 * so this adds on top instead and leaves that file alone.
 *
 * ── Two bugs this script used to have, both worth keeping written down ──
 *
 * It POSTed *new* scheduled workouts on days the base seeder had already filled
 * with the same workout. Every one collided on (workoutId, calendar date), and
 * `SyncService._pullScheduledWorkouts` drops exactly that:
 *
 *     if (existingByContent.serverId != null &&
 *         existingByContent.serverId != swServerId)
 *       continue;  // server-side duplicate — skip entirely
 *
 * so none of them ever reached the device. The local row that survived was the
 * base seeder's, still `isCompleted: false`, and Progress → Gym went on reading
 * 1 workout however many sessions were posted. That guard is correct — it is
 * the dedup rule from docs/sync-account-switch-duplication.md. The fix is to
 * mutate the sessions that already exist rather than manufacture new ones.
 *
 * And completing a session is not enough for the *Exercise Progress* chart
 * below those tiles: it reads `workout_set_table` for weight and reps, so a
 * session with no logged sets leaves it on "No workout data yet". Hence the
 * sets below.
 *
 * The base seeder also has an arithmetic bug this compensates for: the one
 * session it marks complete is dated `daysAgo(i - 2)` with `i === 0`, which is
 * two days in the *future*, so the 7-day window counted zero.
 *
 * Usage: node seed-screenshot-extras.mjs [--api http://127.0.0.1:5080]
 */

const args = process.argv.slice(2);
const apiFlag = args.indexOf('--api');
const API = (apiFlag >= 0 ? args[apiFlag + 1] : 'http://127.0.0.1:5080').replace(/\/$/, '');

const TRAINEE = { username: 'robert.meyer', password: 'ReviewPass!2026' };

async function call(path, { method = 'GET', body, token } = {}) {
  const res = await fetch(`${API}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let parsed;
  try { parsed = text ? JSON.parse(text) : null; } catch { parsed = text; }
  if (!res.ok) throw new Error(`${method} ${path} -> ${res.status} ${text.slice(0, 300)}`);
  return parsed;
}

const startOfUtcDay = (d) => Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
const daysBetween = (a, b) => Math.round((startOfUtcDay(a) - startOfUtcDay(b)) / 86_400_000);

const daysAgo = (n) => {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - n);
  d.setUTCHours(12, 0, 0, 0);
  return d.toISOString();
};

console.log(`Topping up ${API}`);
const { token } = await call('/api/auth/login', { method: 'POST', body: TRAINEE });

// ── Completed sessions ──────────────────────────────────────────────────────
//
// Complete the sessions the base seeder already created, in the recent past.
// Never create one: a new row on a day that already has this workout is what
// the pull discards.
//
// The gap is deliberate. `summariseFrequency` keeps a streak alive across a gap
// of up to two days, so leaving a three-day hole is the only way to make
// "current streak" and "longest streak" show different numbers — and a pair of
// tiles reading the same value is not worth a screenshot.
// Two consecutive rest days, so the gap between the sessions either side is
// three days. One rest day is not enough: the tolerance is "<= 2", so a single
// missed day is absorbed and both tiles read the same number — which is exactly
// what the first run of this produced (5 and 5).
const REST_DAYS = new Set([3, 4]);
const WINDOW = 10;                    // how far back to reach

const now = new Date();
const scheduled = await call('/api/ScheduledWorkout', { token });

const inWindow = scheduled
  .map((sw) => ({ sw, ago: daysBetween(now, new Date(sw.scheduledDate)) }))
  .filter(({ ago }) => ago >= 1 && ago <= WINDOW && !REST_DAYS.has(ago))
  // One session per day. The account can hold several rows for a day after a
  // few runs of this script's older versions; completing all of them would
  // inflate Total Workouts past what the calendar shows.
  .reduce((keep, entry) => keep.set(entry.ago, keep.get(entry.ago) ?? entry), new Map());

const days = [...inWindow.values()].sort((a, b) => b.ago - a.ago); // oldest first

let completed = 0;
for (const { sw } of days) {
  // Idempotent: this script is re-run throughout a capture session.
  if (!sw.isCompleted) {
    await call(`/api/ScheduledWorkout/${sw.id}`, {
      method: 'PUT', token,
      body: {
        workoutId: sw.workoutId,
        scheduledDate: sw.scheduledDate,
        isCompleted: true,
        isSkipped: false,
        notes: sw.notes ?? null,
      },
    });
  }
  completed++;
}
console.log(`  ${completed} sessions completed across the last ${WINDOW} days`);

// ── Logged sets ─────────────────────────────────────────────────────────────
//
// Weights climb across the window so the per-exercise chart shows a line going
// somewhere. Oldest session gets the lightest load; `step` is per session, not
// per day, so a rest day does not leave a gap in the progression.
const BASE_WEIGHT = 75;
const STEP = 1.25;

let setsLogged = 0;
for (const [index, { sw }] of days.entries()) {
  const detail = await call(`/api/ScheduledWorkout/${sw.id}`, { token });
  const exercises = detail.exercises ?? [];
  if (!exercises.length) continue;

  const weight = BASE_WEIGHT + index * STEP;

  for (const [slot, ex] of exercises.entries()) {
    if ((ex.sets ?? []).length) continue;   // already logged; leave it alone

    // Accessory work is lighter than the first compound of the session. Not a
    // model of anything — just enough spread that every exercise on the chart
    // is not the same line.
    const load = Math.round((weight * (1 - slot * 0.18)) * 2) / 2;

    await call(`/api/ScheduledWorkout/${sw.id}/exercises/${ex.workoutExerciseId}/sets/batch`, {
      method: 'POST', token,
      body: [
        { setNumber: 1, reps: 8, weight: load,        weightUnit: 'kg', rpe: 7 },
        { setNumber: 2, reps: 8, weight: load,        weightUnit: 'kg', rpe: 8 },
        { setNumber: 3, reps: 7, weight: load - 2.5,  weightUnit: 'kg', rpe: 9 },
      ],
    });
    setsLogged += 3;
  }
}
console.log(`  ${setsLogged} sets logged (${BASE_WEIGHT}kg climbing by ${STEP}kg per session)`);

// ── Calorie variety ─────────────────────────────────────────────────────────
//
// The base seeder logs an identical set of meals every day, so the Calorie
// Trend chart draws a perfectly flat line — technically correct, and useless as
// a picture of a trend. A different extra on some days gives it shape. Skipping
// days matters too: a trend where every day moves is as unlike real logging as
// one where no day does.
const foods = await call('/api/FoodItem', { token });
const byName = new Map((foods ?? []).map((f) => [String(f.name ?? f.Name), f.id ?? f.Id]));
const pick = (...names) => names.map((x) => byName.get(x)).find(Boolean);

const EXTRAS = [
  { ago: 1, food: pick('Almonds', 'Olive Oil') },
  { ago: 2, food: pick('Banana', 'Rolled Oats') },
  { ago: 4, food: pick('Whey Protein Isolate', 'Greek Yoghurt 0%') },
  { ago: 5, food: pick('Rye Bread', 'Banana') },
  { ago: 6, food: pick('Olive Oil', 'Almonds') },
];

// Today, explicitly.
//
// The base seeder does seed day 0, but a capture session outlives a UTC
// midnight: seed at 23:00 and by the time the browser opens, "today" is a day
// the seeder never touched and the Dashboard — which reads today, and is
// store frame 1 — shows zeroes on an otherwise full account. Re-running the
// base seeder is the documented fix and did not take, so today is filled here
// directly and unconditionally.
//
// Posting a (day, category) that already exists adds the food to the existing
// meal rather than creating a second one — one meal per user, per day, per
// category (docs/trainer-nutrition-duplicate-meals.md) — which is what makes
// this safe to re-run.
// Kept small on purpose. These are per-100g rows logged whole, so a long list
// runs the day to four thousand calories against a two-thousand goal — real,
// and a terrible advert. Five foods on top of what the base seeder already
// logged lands a little over target, which is what an ordinary day looks like.
const TODAY = [
  ['Breakfast', ['Rolled Oats', 'Banana']],
  ['Lunch',     ['Chicken Breast', 'Broccoli, steamed']],
  ['Snacks',    ['Greek Yoghurt 0%']],
];

// Idempotent, unlike everything else here: posting a (day, category, food)
// again ADDS the food to the existing meal rather than replacing it, so a
// second run doubles the day and a third triples it. `foodEntries` on the
// response is what makes it checkable.
const todaysMeals = await call(`/api/Meal?date=${daysAgo(0).slice(0, 10)}`, { token });
const foodsOn = new Map(
  (todaysMeals ?? []).map((m) => [m.category, (m.foodEntries ?? []).length]));

let today = 0;
for (const [category, names] of TODAY) {
  // Anything already logged in this category means this has run before.
  if ((foodsOn.get(category) ?? 0) > 0) continue;
  for (const name of names) {
    const food = pick(name);
    if (!food) continue;
    await call('/api/Meal', {
      method: 'POST', token,
      body: { date: daysAgo(0), category, foodItemId: food },
    });
    today++;
  }
}
console.log(`  ${today} foods logged for today (0 = already logged)`);

let extras = 0;
for (const { ago, food } of EXTRAS) {
  if (!food) continue;
  // A meal is one row per user, per day, per category (see
  // docs/trainer-nutrition-duplicate-meals.md) — posting the same day and
  // category twice adds a food to the existing meal rather than duplicating it,
  // which is what keeps this re-runnable.
  await call('/api/Meal', {
    method: 'POST', token,
    body: { date: daysAgo(ago), category: 'Snacks', foodItemId: food },
  });
  extras++;
}
console.log(`  ${extras} extra snacks, so the calorie trend is not a flat line`);
console.log('Done.');
