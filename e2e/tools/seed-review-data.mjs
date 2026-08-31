#!/usr/bin/env node
/**
 * Seeds a running ForgeForm API with one trainee, one trainer, and enough
 * realistic data that every screen renders populated rather than empty.
 *
 * Why the API and not a SQL fixture: the trainee app is local-first. Its
 * screens read a drift/sqlite database on the device, and a fresh browser
 * profile starts that database empty. What fills it is `SyncService.pullAll()`
 * on sign-in — so the only way to get a populated Food or Gym tab in a browser
 * is for the server to have the rows to hand back. Writing them through the
 * app's own endpoints also means this file cannot drift from the schema the
 * way a SQL fixture would.
 *
 * CLAUDE.md asks for placeholder data that looks like real trainer data. The
 * numbers below are plausible rather than round: 2,837 kcal against a 2,900
 * target, 96.1kg on the way from 100 to 95.
 *
 * Usage: node tools/seed-review-data.mjs [--api http://127.0.0.1:5080]
 */

const args = process.argv.slice(2);
const apiFlag = args.indexOf('--api');
const API = (apiFlag >= 0 ? args[apiFlag + 1] : 'http://127.0.0.1:5080').replace(/\/$/, '');

export const TRAINEE = {
  username: 'robert.meyer',
  password: 'ReviewPass!2026',
  firstName: 'Robert',
  lastName: 'Meyer',
  email: 'robert.meyer@example.com',
  dateOfBirth: '1991-04-12T00:00:00Z',
};

export const TRAINER = {
  username: 'nina.brandt',
  password: 'ReviewPass!2026',
  firstName: 'Nina',
  lastName: 'Brandt',
  email: 'nina.brandt@example.com',
  dateOfBirth: '1988-09-02T00:00:00Z',
  accountType: 'Trainer',
};

/**
 * A third account that is *deliberately never linked to a trainer*.
 *
 * Several screens exist only on one side of `isTrainerClient`: the Profile tab
 * shows "Your coach" when it is true and "Join a trainer" when it is false, and
 * exactly one of those two screens is reachable per account. Linking the main
 * trainee — which is what makes coach chat and the console's Client Detail
 * reachable at all — therefore *removes* the only route to `JoinTrainerScreen`.
 *
 * Keeping an unlinked account in the seed is what stops that from being a
 * trade. Do not link this one to fix a failing test; the failure would be the
 * test asking the wrong account.
 */
export const UNLINKED_TRAINEE = {
  username: 'lena.fischer',
  password: 'ReviewPass!2026',
  firstName: 'Lena',
  lastName: 'Fischer',
  email: 'lena.fischer@example.com',
  dateOfBirth: '1994-11-23T00:00:00Z',
};

let quiet = false;
const log = (...a) => { if (!quiet) console.log(...a); };

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
  if (!res.ok) {
    throw new Error(`${method} ${path} -> ${res.status} ${text.slice(0, 300)}`);
  }
  return parsed;
}

/**
 * Register, falling back to login when the account is already there.
 *
 * The API rate-limits auth at 5 requests per window and a 429 presents much
 * like a wrong password, so this is deliberately the only place that touches
 * an auth endpoint more than once per account.
 */
async function account(spec) {
  try {
    const created = await call('/api/auth/register', { method: 'POST', body: spec });
    log(`  registered ${spec.username}`);
    return created.token;
  } catch (err) {
    if (!/40[09]|Conflict|exists/i.test(String(err))) throw err;
    const login = await call('/api/auth/login', {
      method: 'POST',
      body: { username: spec.username, password: spec.password },
    });
    log(`  reusing ${spec.username}`);
    return login.token;
  }
}

const daysAgo = (n) => {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - n);
  d.setUTCHours(12, 0, 0, 0);
  return d.toISOString();
};

async function seedTrainee(token) {
  await call('/api/UserSettings', {
    method: 'PUT', token,
    body: {
      dailyCalorieGoal: 2900, themeMode: 'dark', name: 'Robert',
      age: 34, heightCm: 182, sex: 'male',
      activityLevel: 2, goalType: 1,
      startingWeight: 100.0, goalWeight: 95.0,
    },
  });
  log('  settings');

  // A downward trend with a plateau in it, so the chart has a shape rather
  // than a straight line.
  const weights = [
    [42, 100.0], [35, 99.2], [28, 98.4], [21, 98.6],
    [14, 97.5], [7, 96.8], [2, 96.1],
  ];
  for (const [ago, kg] of weights) {
    await call('/api/WeightTracking/TrackWeight', {
      method: 'POST', token, body: { date: daysAgo(ago), weight: kg },
    });
  }
  log(`  ${weights.length} weight records`);

  const foods = [
    ['Greek Yoghurt 0%', 59, 10, 4, 0],
    ['Rolled Oats', 379, 13, 68, 7],
    ['Banana', 89, 1, 23, 0],
    ['Chicken Breast', 165, 31, 0, 4],
    ['Basmati Rice, cooked', 130, 3, 28, 0],
    ['Broccoli, steamed', 35, 2, 7, 0],
    ['Whey Protein Isolate', 373, 82, 6, 3],
    ['Almonds', 579, 21, 22, 50],
    ['Salmon Fillet', 208, 20, 0, 13],
    ['Sweet Potato, baked', 90, 2, 21, 0],
    ['Olive Oil', 884, 0, 0, 100],
    ['Rye Bread', 259, 9, 48, 3],
  ];
  const foodIds = [];
  for (const [name, calories, protein, carbs, fat] of foods) {
    const created = await call('/api/FoodItem', {
      method: 'POST', token,
      body: { name, calories, protein, carbs, fat, gramm: 100 },
    });
    foodIds.push(created.id ?? created.Id);
  }
  log(`  ${foods.length} food items`);

  // One row per user, per day, per category — see
  // docs/trainer-nutrition-duplicate-meals.md. Foods attach to that one row.
  const plan = [
    ['Breakfast', [0, 1, 2]],
    ['Lunch', [3, 4, 5]],
    ['Dinner', [8, 9, 10]],
    ['Snacks', [6, 7]],
  ];
  for (let day = 0; day < 7; day++) {
    for (const [category, indexes] of plan) {
      const meal = await call('/api/Meal', {
        method: 'POST', token,
        body: { date: daysAgo(day), category, foodItemId: foodIds[indexes[0]] },
      });
      const mealId = meal.id ?? meal.Id;
      for (const i of indexes.slice(1)) {
        await call(`/api/Meal/${mealId}/foods/${foodIds[i]}`, { method: 'POST', token });
      }
    }
  }
  log('  7 days of meals');

  // One saved template. Without it `EditMealTemplateScreen` has no route at
  // all: the only way in is the overflow menu on an existing card, so an empty
  // Templates tab makes that screen unreachable rather than empty -- and an
  // unreachable screen is what an audit silently reports as clean.
  await call('/api/MealTemplate', {
    method: 'POST', token,
    body: {
      name: 'Pre-session oats',
      description: 'Oats, banana and whey, 40 minutes before training',
      category: 'Breakfast',
      totalWeightGrams: 320,
      items: [],
    },
  });
  log('  1 meal template');

  const exercises = [
    ['Back Squat', 'Barbell squat to depth', 'Quads, Glutes'],
    ['Romanian Deadlift', 'Hip hinge, controlled eccentric', 'Hamstrings, Glutes'],
    ['Bench Press', 'Flat barbell press', 'Chest, Triceps'],
    ['Pull-Up', 'Full hang to chin over bar', 'Lats, Biceps'],
    ['Overhead Press', 'Standing barbell press', 'Shoulders, Triceps'],
    ['Barbell Row', 'Bent-over row, braced', 'Back, Biceps'],
    ['Leg Press', 'Machine press, full range', 'Quads'],
    ['Walking Lunge', 'Alternating, dumbbells at side', 'Quads, Glutes'],
  ];
  const exerciseIds = [];
  for (const [name, description, targetMuscleGroups] of exercises) {
    const created = await call('/api/Exercise/UserExercise', {
      method: 'POST', token,
      body: { name, description, type: 0, targetMuscleGroups, imageUrl: '', isCustom: true },
    });
    exerciseIds.push(created.id ?? created.Id);
  }
  log(`  ${exercises.length} exercises`);

  const workouts = [
    ['Upper A', 'Horizontal press and pull', [2, 5, 4, 3]],
    ['Lower B', 'Squat focus, posterior chain accessory', [0, 1, 6, 7]],
  ];
  const workoutIds = [];
  for (const [name, description, exerciseIndexes] of workouts) {
    const workout = await call('/api/Workout', {
      method: 'POST', token,
      body: { name, description, difficulty: 2, estimatedDurationMinutes: 55, isTemplate: false },
    });
    const workoutId = workout.id ?? workout.Id;
    workoutIds.push(workoutId);
    const workoutExercises = await call(`/api/Workout/${workoutId}/exercises/batch`, {
      method: 'POST', token,
      body: exerciseIndexes.map((exIndex, order) => ({
        exerciseId: exerciseIds[exIndex], orderPosition: order,
      })),
    });

    // Three planned sets per exercise. Without this, ActiveWorkoutView reads
    // `exerciseData.templates[_currentSetIndex]` on an empty list the moment
    // you tap Start Workout, which throws RangeError: Index out of range: no
    // indices are valid: 0 -- a silent crash, since the error handler paints
    // nothing rather than a visible failure. The real app can't produce this:
    // CreateWorkoutView's exercise editor always shows at least one set row,
    // and set templates are added through their own endpoint
    // (`exercises/{id}/sets/batch`) that a workout built through the UI
    // always calls. Seeding exercises without it was building a workout the
    // app itself has no path to.
    for (const we of workoutExercises) {
      const workoutExerciseId = we.id ?? we.Id;
      await call(`/api/Workout/exercises/${workoutExerciseId}/sets/batch`, {
        method: 'POST', token,
        body: [
          { setNumber: 1, targetReps: '8-10', orderPosition: 0 },
          { setNumber: 2, targetReps: '8-10', orderPosition: 1 },
          { setNumber: 3, targetReps: '6-8', orderPosition: 2 },
        ],
      });
    }
  }
  log(`  ${workouts.length} workouts, 3 planned sets per exercise`);

  // Fifteen scheduled sessions with one completed, matching the "1/15" the
  // dashboard stat tile shows.
  let completed = 0;
  for (let i = 0; i < 15; i++) {
    const isCompleted = i === 0;
    if (isCompleted) completed++;
    await call('/api/ScheduledWorkout', {
      method: 'POST', token,
      body: {
        workoutId: workoutIds[i % workoutIds.length],
        scheduledDate: daysAgo(i - 2),
        isCompleted,
        isSkipped: false,
      },
    });
  }
  log(`  15 scheduled workouts (${completed} completed)`);
}

/**
 * Put the trainee on the trainer's roster, through the real invite flow.
 *
 * Not a direct row insert: a seat is an Active relationship *or* an unexpired
 * Pending invite, and the limit is enforced at mint *and* at redemption
 * (docs/trainer-licensing.md). Minting and redeeming for real is the only way
 * the seeded state is a state the app can actually produce.
 *
 * Without this link the seed had a trainer with an empty roster, which made
 * three screens unreachable rather than merely empty: the console's Client
 * Detail (no client to open), and both halves of coach chat. A previous audit
 * pass recorded the coach chat screen as a possible app defect because its
 * entry point "did not respond within 15s". The entry point was not there.
 */
async function linkTraineeToTrainer(trainerToken, traineeToken) {
  const status = await call('/api/TrainerClient/status', { token: traineeToken });
  if (status?.isTrainerClient) {
    log('  already on the roster');
    return;
  }
  const invite = await call('/api/TrainerClient/invite', { method: 'POST', token: trainerToken });
  const code = invite.inviteCode ?? invite.InviteCode;
  await call(`/api/TrainerClient/join/${code}`, { method: 'POST', token: traineeToken });
  log(`  linked ${TRAINEE.username} to ${TRAINER.username}`);
}

async function main() {
  quiet = args.includes('--quiet');
  log(`Seeding ${API}`);
  const traineeToken = await account(TRAINEE);
  await seedTrainee(traineeToken);
  const trainerToken = await account(TRAINER);
  await linkTraineeToTrainer(trainerToken, traineeToken);
  // Registered but given no data and no trainer: this account exists to keep
  // the `!isTrainerClient` arm of the Profile tab reachable. See the comment
  // on UNLINKED_TRAINEE.
  const unlinkedTraineeToken = await account(UNLINKED_TRAINEE);
  log('Done.');
  return { traineeToken, trainerToken, unlinkedTraineeToken };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((err) => {
    console.error(String(err));
    process.exit(1);
  });
}

export { main as seed, API };
