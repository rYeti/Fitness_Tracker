# Play Console — copy and paste

Every value below sits **alone in its own code block**, so a copy takes the
field's text and nothing else. Character counts are outside the blocks on
purpose.

The reasoning behind these words — alternates, ASO logic, why certain claims are
worded the way they are — is in `LISTING.md`. This file is only for filling in
the console.

**Ready to paste:** app name, short description, full description, and every
graphic asset. **"How to actually upload this"** below is the click-by-click
order to do it in.
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
| Phone screenshots | 8 of 8, 1080 × 1920 | `store/screenshots/out/store/play/01…08*.png` |

Upload the screenshots **in filename order** — the numbering is the store order,
and slot 1 is the one that carries the listing in search results.

| # | File | What it shows |
| --- | --- | --- |
| 1 | `01-food-day.png` | Training and nutrition. One app. |
| 2 | `02-active-workout.png` | Log a set. Keep moving. |
| 3 | `03-exercise-library.png` | 873 exercises. Already in. |
| 4 | `04-food-search.png` | Log food in seconds. |
| 5 | `05-progress-nutrition.png` | See the trend, not just today. |
| 6 | `06-weight.png` | Weigh in. Watch the trend. |
| 7 | `07-gym-today.png` | Your plan, on your calendar. |
| 8 | `08-meal-templates.png` | The meal you eat every week. |

All eight slots Play offers are used. The Dashboard and Progress → Gym are
captured but not framed — both render an empty state caused by defects recorded
in `screenshots/README.md`, and a screenshot of a zero is worse than none.

Tablet screenshots are optional. Without them Play shows the phone shots on
tablets and marks the listing as not optimised for large screens — worth doing
before a wide launch, not a blocker for the internal track.

---

## How to actually upload this

Nothing in the repo pushes a store listing. `.github/workflows/android-release.yml`
publishes through `r0adkll/upload-google-play@v1`, which uploads the **app bundle
and release notes only** (`whatsNewDirectory`, written from `PLAY_NOTES.md`). It
has no inputs for listing text, screenshots, the feature graphic or the icon, and
there is no fastlane here. So this part is done by hand in the console — which is
no great loss, since the Data safety and content-rating forms below are
console-only anyway.

### 0. Get the files onto the machine with the browser on it

The PNGs are committed, so this is a pull, not a download:

```
git checkout claude/app-store-listing-optimization-f8mpd4
git pull
```

Everything you upload is in one folder:

```
store/screenshots/out/store/play/
```

### 1. Main store listing

**Grow → Store presence → Main store listing.**

| Field on the page | What to paste or pick |
| --- | --- |
| App name | the block in §1 above |
| Short description | the block in §2 |
| Full description | the block in §3 — paste it as-is, the line breaks are deliberate |
| App icon | `icon-512.png` |
| Feature graphic | `feature-graphic.png` |
| Phone screenshots | `01-…` through `08-…`, all eight at once |

Select all eight screenshots in one go. Play orders them by filename, which is
the only reason they are numbered — then **check the order in the preview
strip**, because dragging one a few pixels reorders it silently and slot 1 is
the one most people ever see.

Play wants 2–8 phone screenshots, each side between 320 and 3840 px, with a
ratio no more extreme than 2:1. 1080 × 1920 sits comfortably inside all three.

### 2. Store settings

**Grow → Store presence → Store settings.** Category, tags and the public
contact details — see §"Store settings" below for the values.

### 3. App content

**Monetise → App content** (Play has also shelved this under *Policy* — the
left nav wording moves, the page does not). Privacy policy, Data safety,
content rating, target audience, ads. None of it can come from the repo; §"App
content" below says what each one needs.

### 4. Send for review

Everything above saves as a **draft** and changes nothing on the live listing
until you press *Send for review*. Listing review is separate from a release
review and usually takes a day or so, so do it before you plan to ship, not
after.

### Two things worth knowing before you start

**The privacy policy is the one hard blocker.** `privacy-policy.html` is in the
repo root but is not hosted anywhere, and Play will not accept the listing
without a URL that resolves. GitHub Pages on this repo is the cheapest fix.
Sort it before you sit down to do the rest, or you will get to the end and stop.

**The icon here is the *store* icon.** It is separate from the launcher icon
baked into the bundle, and nothing checks that they match. They are both
generated from `fittnes_tracker/assets/icon/app_icon.png`, so they do — but if
that source ever changes, both need updating.

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

- [ ] Privacy policy hosted somewhere public, URL pasted — **do this first**,
      it is the only item that can block everything else
- [ ] Text fields pasted from §1–§3
- [ ] Screenshots uploaded, order checked in the preview strip
- [ ] Feature graphic and icon uploaded
- [ ] Category, tags and contact details set
- [ ] Data safety form completed
- [ ] Content rating questionnaire completed
- [ ] Target audience set
- [ ] Test account provided under App access
- [ ] *Send for review* pressed — nothing above is live until it is
- [ ] Release notes: `PLAY_NOTES.md` under `## Unreleased` — the release
      workflow reads it, and it is capped at 500 characters per locale

The listing is **German and English** in the app itself
(`supportedLocales: [en, de]`). This package is English only; a `de-DE` listing
would need the same fields translated, and Play treats a partial translation as
a separate locale rather than a fallback.
