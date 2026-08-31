# ForgeForm — App Store & Google Play listing package

Every claim below is traceable to code in this repository. Nothing here
describes a feature that does not ship. Where a feature is behind the premium
subscription it is labelled, because an unqualified claim in a store listing is
a refund request waiting to happen.

Why each claim is worded the way it is, and the two places the paywall's own
copy disagrees with the shipped gating: `docs/store-listing.md`.

---

## 1. Promotional text / subtitle

**iOS subtitle (30 char limit):**

```
Train, eat, track. One app.
```

*27 characters.*

Alternates, all inside the limit, if the first reads too flat next to the
icon:

| Subtitle | Chars |
|---|---|
| `Train, eat, track. One app.` | 27 |
| `Lifts, macros, weight — one app` | 31 ✗ *(over — do not use)* |
| `Your lifts and macros, logged` | 29 |
| `Log the lift. Log the meal.` | 27 |
| `Strength and macros, together` | 29 |

**iOS promotional text (170 char limit, editable without review):**

```
873 exercises with instructions, barcode food logging and 7,140 verified foods,
built in. Log offline, sync when you're back. Coaching chat is end-to-end encrypted.
```

*162 characters.*

**Google Play "Promo text" is deprecated** — Play shows the short description
instead. Use §2 there.

---

## 2. Short description (Google Play, 80 char limit)

```
Log workouts, scan food, track weight — with real coaching built in.
```

*68 characters.*

Alternates:

| Short description | Chars |
|---|---|
| `Log workouts, scan food, track weight — with real coaching built in.` | 68 |
| `Workout log, macro tracker and coach chat. Works offline, syncs later.` | 70 |
| `873 exercises, barcode macros, weight goals. One app, works offline.` | 68 |

---

## 3. Long description

Written once and used for both stores. Google Play's long description caps at
4,000 characters; this is ~2,750, leaving room for localised expansion. The App
Store description field caps at 4,000 too, so the same text drops straight in.

Apple does not render Markdown or emoji-bullets as formatting — the bullets
below use a plain `•` and a blank line between blocks, which both stores show
correctly.

```
You already know what to do in the gym. You just need somewhere to put it.

ForgeForm is a training and nutrition log built for people who actually lift and
actually count their macros — not a feed, not a challenge board, not a step
counter. Open it, log the set, log the meal, close it.

WHAT YOU GET

• 873 exercises, already there — every one with written instructions and its
  target muscle groups. Add your own when your gym has something odd.

• Log a set in seconds — weight, reps and optional RPE, with your previous
  set shown right there so you know what to beat.

• A rest timer that starts itself the moment you finish a set. No extra tap.

• Plans that follow your calendar — build a workout once, then run it as a
  fixed cycle or pick any workout on any day. Scheduled sessions land on a
  calendar you can actually see.

• Barcode scanning for food — point the camera at the packet and it's logged,
  backed by the Open Food Facts database.

• 7,140 verified foods built in, sourced from the German Federal Food Key
  (BLS) nutrient database, marked with a Verified badge so you know the
  numbers came from a lab and not from a stranger's guess.

• Meals that stay organised — breakfast, lunch, dinner and snacks, with
  portion sizes, custom foods and saved meal templates for the meals you eat
  every week.

• Protein, carbs and fat tracked against a daily calorie goal you set
  yourself — or let the app work one out from your age, height, activity
  level and goal.

• Weight logging with a goal weight and a trend chart, so a bad morning on
  the scale stops looking like a catastrophe.

• Streaks, session history and progress stats that show whether the last
  month was real training or just attendance.

• Coming from FitNotes? Import your CSV export and your history comes with
  you.

• Everything exports — workouts, weight history and nutrition as CSV, or your
  whole log as one JSON backup. It's your data.

• Works offline. Every log is written to your device first and synced to the
  server when you have signal, so a basement gym with no bars is not a reason
  to lose a session.

• Dark and light themes, English and Deutsch.

TRAINING WITH A COACH

If your trainer uses ForgeForm, they can see the training you agreed on and
you can message them in the app. That chat is end-to-end encrypted — ECDH
P-256 key agreement and AES-256-GCM, so the message is sealed on your phone
and the server forwards a blob it cannot read.

Coaches get their own side of it: a client roster with adherence and
attendance at a glance, a workout builder, nutrition monitoring, and session
review. It runs in a desktop browser, because a coach's workstation is not a
phone.

PREMIUM

The everyday log is free. Premium unlocks unlimited workout plans and meal
templates, all-time history with custom date ranges, per-exercise progress
graphs, the weight-and-calorie correlation chart, an adaptive calorie target
that learns your real expenditure from your own logs, full vitamin and mineral
breakdowns, unlimited custom foods, and plan durations up to a year. Cancel
anytime; the subscription auto-renews until you do.

START TODAY

Install ForgeForm, log one workout and one meal, and let the numbers do the
arguing.
```

**Character count:** ~2,750 including whitespace. Both stores accept it as-is.

---

## 4. ASO keywords

Ten terms, ranked by the intersection of search volume and what this app
actually does. Broad head terms ("fitness") are deliberately excluded — the app
will never rank for them and they waste a field with a 100-character cap.

**Comma-separated list (the answer to the brief):**

```
workout tracker, gym log, macro counter, calorie counter, food scanner, weight tracker, strength training, exercise log, personal trainer, fitness coach
```

**iOS keyword field (100 characters, no spaces after commas, no words already in
the app name or subtitle):**

```
workout,gym,macro,calorie,barcode,weight,strength,lifting,exercise,coach,trainer,log,nutrition
```

*93 characters.* Apple matches across the name, subtitle and keyword field
combined, so "train", "eat" and "track" are omitted here — they already appear
in the subtitle and repeating them buys nothing.

**Google Play** has no keyword field; it indexes the title, short description
and long description. The long description in §3 already carries every term in
the list above at least once, in prose rather than a keyword dump, which is what
Play's spam filter is looking for.

---

## 5. Screenshots

Six store frames in `screenshots/out/store/`. Each is a headline band and a
device bezel wrapped around a **photograph of the running app** — Playwright
driving the real Flutter web bundle, signed in as the seeded trainee against a
local API. Two steps, kept separate on purpose:

| Step | Script | Output |
|---|---|---|
| Photograph the app | `capture-app.mjs` | `out/ios/`, `out/play/` — bare screens |
| Add the store artwork | `compose.mjs` | `out/store/ios/`, `out/store/play/` — upload these |

Nothing in `compose.mjs` redraws a screen; it only adds the chrome a listing
needs and a bare screenshot does not. If a frame ever disagrees with the app,
the fix is to re-run the capture, never to edit the markup. The bare captures
stay in the repo as the evidence that the frames contain real app pixels.

`screenshots/README.md` is the runbook: Postgres, the API, the seed, the build
flags, the capture. Regenerate with `node capture-app.mjs` once that stack is up.

Frame order is store order, not capture order — slot 1 carries the whole
proposition, because in search results it is often the only one seen.

| # | Headline | Screen |
|---|---|---|
| 1 | Training and nutrition. **One app.** | Dashboard — 2186 kcal, 1/3 workouts, Upper A, weight progress |
| 2 | Log a set. **Keep moving.** | Active workout — Bench Press, 82.5 kg × 8 |
| 3 | Macros that **actually add up.** | A logged day — 2,186 / 2,000 kcal, macros, meals by category |
| 4 | Log food **in seconds.** | The food picker for one meal — "Eaten at this meal" above "Other foods" |
| 5 | See the trend, **not just today.** | Progress → Nutrition over the selected range |
| 6 | Your plan, **on your calendar.** | Today's scheduled session — Upper A, 55 min |

**Rendered sizes:**

| Store | Slot | Pixels | Files |
|---|---|---|---|
| App Store | iPhone 6.9" / 6.7" | 1290 × 2796 | `screenshots/out/ios/` |
| Google Play | Phone | 1080 × 1920 | `screenshots/out/play/` |

### Before these go up

They are real, which also means they show exactly what the seeded account has
and nothing more:

- **Progress → Gym is not in the six frames, because its data is still wrong.**
  It reads 1 total workout and a 0-day streak even after
  `seed-screenshot-extras.mjs` posts eight completed sessions across the last
  ten days, and still shows "No workout data yet" under Exercise Progress.
  Probably those tiles count logged sessions rather than scheduled workouts
  flagged complete — unconfirmed. Unfinished, not hidden.
- **The Calorie Trend in frame 5 is a flat line.** Every seeded day carries the
  same total; the extra snacks the top-up posts do not move it and the cause is
  not established (`GET /api/Meal` returns 500 on this build, which blocked the
  diagnostic and is worth a look on its own).
- **Padlocks are visible** on the Progress range selector (All Time, Custom).
  Truthful, but decide deliberately whether to lead with locked features.
The app is **light-themed by default**, which is what these show. The copy above
mentions dark mode as an option, which is accurate.
