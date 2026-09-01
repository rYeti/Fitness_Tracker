# Play Console — copy and paste

Every value below sits **alone in its own code block**, so a copy takes the
field's text and nothing else. Character counts are outside the blocks on
purpose.

The reasoning behind these words — alternates, ASO logic, why certain claims are
worded the way they are — is in `LISTING.md`. This file is only for filling in
the console.

**Ready to paste:** app name, short description, full description, and every
graphic asset.
**Blocked on you:** everything under *App content* — a hosted privacy policy
URL, and the declaration forms only the account holder can answer.

---

## Main store listing

### App name — 9 / 30

```
ForgeForm
```

### Short description — 68 / 80

```
Log workouts, scan food, track weight — with real coaching built in.
```

### Full description — 3203 / 4000

Paragraphs are unwrapped to single lines on purpose: Play preserves the line
breaks you paste, so the hard-wrapped copy in `LISTING.md` would show up as a
ragged column on a phone. Play renders no Markdown — the bullets are literal
`•` characters and are meant to be.

```
You already know what to do in the gym. You just need somewhere to put it.

ForgeForm is a training and nutrition log built for people who actually lift and actually count their macros — not a feed, not a challenge board, not a step counter. Open it, log the set, log the meal, close it.

WHAT YOU GET

• 873 exercises, already there — every one with written instructions and its target muscle groups. Add your own when your gym has something odd.

• Log a set in seconds — weight, reps and optional RPE, with your previous set shown right there so you know what to beat.

• A rest timer that starts itself the moment you finish a set. No extra tap.

• Plans that follow your calendar — build a workout once, then run it as a fixed cycle or pick any workout on any day. Scheduled sessions land on a calendar you can actually see.

• Barcode scanning for food — point the camera at the packet and it's logged, backed by the Open Food Facts database.

• 7,140 verified foods built in, sourced from the German Federal Food Key (BLS) nutrient database, marked with a Verified badge so you know the numbers came from a lab and not from a stranger's guess.

• Meals that stay organised — breakfast, lunch, dinner and snacks, with portion sizes, custom foods and saved meal templates for the meals you eat every week.

• Protein, carbs and fat tracked against a daily calorie goal you set yourself — or let the app work one out from your age, height, activity level and goal.

• Weight logging with a goal weight and a trend chart, so a bad morning on the scale stops looking like a catastrophe.

• Streaks, session history and progress stats that show whether the last month was real training or just attendance.

• Coming from FitNotes? Import your CSV export and your history comes with you.

• Everything exports — workouts, weight history and nutrition as CSV, or your whole log as one JSON backup. It's your data.

• Works offline. Every log is written to your device first and synced to the server when you have signal, so a basement gym with no bars is not a reason to lose a session.

• Dark and light themes, English and Deutsch.

TRAINING WITH A COACH

If your trainer uses ForgeForm, they can see the training you agreed on and you can message them in the app. That chat is end-to-end encrypted — ECDH P-256 key agreement and AES-256-GCM, so the message is sealed on your phone and the server forwards a blob it cannot read.

Coaches get their own side of it: a client roster with adherence and attendance at a glance, a workout builder, nutrition monitoring, and session review. It runs in a desktop browser, because a coach's workstation is not a phone.

PREMIUM

The everyday log is free. Premium unlocks unlimited workout plans and meal templates, all-time history with custom date ranges, per-exercise progress graphs, the weight-and-calorie correlation chart, an adaptive calorie target that learns your real expenditure from your own logs, full vitamin and mineral breakdowns, unlimited custom foods, and plan durations up to a year. Cancel anytime; the subscription auto-renews until you do.

START TODAY

Install ForgeForm, log one workout and one meal, and let the numbers do the arguing.
```

---

## Graphics

All produced by `store/screenshots/compose.mjs`. Sizes are exact; no resizing
needed at upload.

| Console slot | Requirement | File |
| --- | --- | --- |
| App icon | 512 × 512, 32-bit PNG | `store/screenshots/out/store/play/icon-512.png` |
| Feature graphic | 1024 × 500 | `store/screenshots/out/store/play/feature-graphic.png` |
| Phone screenshots | 2–8, 1080 × 1920 | `store/screenshots/out/store/play/01…05*.png` |

Upload the screenshots **in filename order** — the numbering is the store order,
and slot 1 is the one that carries the listing in search results.

| # | File | What it shows |
| --- | --- | --- |
| 1 | `01-food-day.png` | Training and nutrition. One app. |
| 2 | `02-active-workout.png` | Log a set. Keep moving. |
| 3 | `03-food-search.png` | Log food in seconds. |
| 4 | `04-progress-nutrition.png` | See the trend, not just today. |
| 5 | `05-gym-today.png` | Your plan, on your calendar. |

Five, not the maximum eight. The Dashboard and Progress → Gym are captured but
not framed — both would show an empty state caused by data problems recorded in
`screenshots/README.md`, and a screenshot of a zero is worse than one fewer
screenshot. Adding them later is a `compose.mjs` edit, not a redesign.

Tablet screenshots are optional. Without them Play shows the phone shots on
tablets and marks the listing as not optimised for large screens — worth doing
before a wide launch, not a blocker for the internal track.

---

## Store settings

### App category

```
Health & Fitness
```

Tags (Play allows up to 5, chosen from its fixed list — these are the closest
matches to what the app actually does):

```
Weight & Diet
Exercise & Fitness
Personal Training
```

### Contact details

Required: an email address shown publicly on the listing. Website and phone are
optional.

```
yetitime69@gmail.com
```

Decide deliberately whether to publish a personal address or set up a support
alias first — this one is public on the store page.

---

## App content — none of this can be filled from the repo

| Item | What it needs |
| --- | --- |
| **Privacy policy URL** | `privacy-policy.html` exists in the repo but is not hosted anywhere. Play needs a public URL that resolves before you can submit. GitHub Pages on this repo is the cheapest option. |
| **Data safety** | A form declaring what the app collects and whether it is shared. It does collect account data, and chat is end-to-end encrypted (`docs/chat-encryption.md`) — worth stating, since Play surfaces it. Answer it from the code, not from memory. |
| **Content rating** | A questionnaire. Answering it generates the rating; there is nothing to prepare. |
| **Target audience and content** | Age groups. The app is not directed at children; picking any under-13 group pulls in Families policy obligations. |
| **Ads** | The app serves none. Declare "No ads". |
| **Government apps / News apps / Financial features** | All "no". |
| **App access** | Every screen worth reviewing is behind a login, so Play needs test credentials or the review is done against the login screen. Provide a demo account. |

---

## Before you hit publish

- [ ] Privacy policy hosted, URL pasted
- [ ] Data safety form completed
- [ ] Content rating questionnaire completed
- [ ] Target audience set
- [ ] Test account provided under App access
- [ ] Screenshots uploaded in order, feature graphic and icon uploaded
- [ ] Release notes: `PLAY_NOTES.md` under `## Unreleased` — the release
      workflow reads it, and it is capped at 500 characters per locale

The listing is **German and English** in the app itself
(`supportedLocales: [en, de]`). This package is English only; a `de-DE` listing
would need the same fields translated, and Play treats a partial translation as
a separate locale rather than a fallback.
