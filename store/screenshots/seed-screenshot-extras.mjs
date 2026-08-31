#!/usr/bin/env node
/**
 * Tops up the seeded trainee with completed training history, so the Progress
 * tab has something to draw.
 *
 * Why this is separate from `e2e/tools/seed-review-data.mjs` rather than a
 * change to it: that seeder is the fixture the Playwright suite asserts
 * against, and its counts are load-bearing there ("15 scheduled workouts, 1
 * completed" is quoted in its own log line and mirrors the dashboard's "1/15").
 * Screenshots want a fuller account than tests do. Bending the shared fixture
 * to suit the marketing artwork is how a test fixture stops meaning anything,
 * so this adds on top instead and leaves that file alone.
 *
 * What was actually missing: the base seeder marks exactly one session
 * complete, at `daysAgo(i - 2)` with `i === 0` — which is two days in the
 * *future*. Progress counts completed sessions inside the selected window
 * (7 days by default), so the tab read 0 workouts and a 0-day streak on an
 * account that looked, from the Gym tab, perfectly well populated. The bug was
 * in the fixture's arithmetic, not in the app and not in the screenshot.
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

const daysAgo = (n) => {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - n);
  d.setUTCHours(12, 0, 0, 0);
  return d.toISOString();
};

console.log(`Topping up ${API}`);

const { token } = await call('/api/auth/login', { method: 'POST', body: TRAINEE });

const workouts = await call('/api/Workout', { token });
const workoutIds = (workouts ?? []).map((w) => w.id ?? w.Id).filter(Boolean);
if (!workoutIds.length) {
  console.error('No workouts on this account — run e2e/tools/seed-review-data.mjs first.');
  process.exit(1);
}

// Days 1..6 back, every day except one. A gap is deliberate: an unbroken run of
// completed sessions reads as fabricated, and the rest day is what makes the
// current-streak and longest-streak tiles show different numbers, which is the
// only way that pair of tiles is worth showing at all.
const TRAINED = [1, 2, 3, 5, 6, 7, 8, 9];

let n = 0;
for (const ago of TRAINED) {
  await call('/api/ScheduledWorkout', {
    method: 'POST', token,
    body: {
      workoutId: workoutIds[n % workoutIds.length],
      scheduledDate: daysAgo(ago),
      isCompleted: true,
      isSkipped: false,
    },
  });
  n++;
}

console.log(`  ${n} completed sessions across the last 10 days`);

// The base seeder logs an identical set of meals every day, so the Calorie
// Trend chart draws a perfectly flat line at 2186 — technically correct, and
// useless as a picture of a trend. Adding a different extra to each of the
// last seven days gives the chart something to be a chart about.
const foods = await call('/api/FoodItem', { token });
const byName = new Map((foods ?? []).map((f) => [String(f.name ?? f.Name), f.id ?? f.Id]));
const pick = (...names) => names.map((x) => byName.get(x)).find(Boolean);

// One extra per day, varying in size, on a subset of days. Skipping some days
// entirely matters: a trend where every day moves is as unlike real logging as
// one where no day does.
const EXTRAS = [
  { ago: 1, food: pick('Almonds', 'Olive Oil') },
  { ago: 2, food: pick('Banana', 'Rolled Oats') },
  { ago: 4, food: pick('Whey Protein Isolate', 'Greek Yoghurt 0%') },
  { ago: 5, food: pick('Rye Bread', 'Banana') },
  { ago: 6, food: pick('Olive Oil', 'Almonds') },
];

let extras = 0;
for (const { ago, food } of EXTRAS) {
  if (!food) continue;
  await call('/api/Meal', {
    method: 'POST', token,
    body: { date: daysAgo(ago), category: 'Snacks', foodItemId: food },
  });
  extras++;
}
console.log(`  ${extras} extra snacks, so the calorie trend is not a flat line`);
console.log('Done.');
