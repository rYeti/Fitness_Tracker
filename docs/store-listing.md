# Writing ForgeForm's store listing from the code

There is a version of this task that takes twenty minutes: open the app, look at
the tabs, write "track your workouts and nutrition with our powerful all-in-one
fitness app", pick ten keywords that sound gym-adjacent, and hand it over. That
version is wrong in a way nothing catches. The compiler has no opinion about
marketing copy. The test suite has no opinion. The reviewer at Apple has an
opinion, but they only voice it once, at submission, after you've waited.

What follows is what it actually took to write `store/LISTING.md` from this
repository, the two places the app's own copy contradicts the app's own
behaviour, and the general shape of mistake that both of those are instances
of.

---

## The failure mode: prose that no type system can check

Everything in this repo that describes the app to a *user* — the paywall's
feature list, the onboarding blurb, the store listing — is a claim about
behaviour written in a place where nothing verifies it. `paywallFeatureExport`
is a string in `intl_en.arb`. It says "Export workout data (CSV)". Nothing in
Dart, and nothing in the test suite, connects that string to whether the export
tile is actually behind `PremiumGate`. Rename the widget, move the gate, delete
the gate — the string stays exactly as true-looking as it was.

This is the same category as the bugs the other docs in this folder record. In
`docs/trainer-nutrition-duplicate-meals.md` the invariant "one meal row per
user, per day, per category" lived only in code, so code drifted away from it.
Here the invariant is "the listing describes the app", it lives only in prose,
and prose drifts faster than code because nobody recompiles it.

The defence used while writing the listing was mechanical: **every sentence in
the description had to be traceable to a file**. Not to a memory of the app, not
to a screenshot — to a symbol. That is slower and it is the only thing that
works. Two contradictions fell out of it immediately.

---

## Contradiction 1: exports are advertised as Premium and shipped as free

The paywall lists CSV export as something you get by subscribing:

```
paywallFeatureExport = Export workout data (CSV)
```

The Settings screen builds four export tiles — workouts CSV, weight CSV,
nutrition CSV, and a full JSON backup — and **not one of them is wrapped in
`PremiumGate`**. The screen reads `hasPremium` at the top of `build`, and uses it
for the upgrade banner, but the export tiles' `onTap` goes straight to
`_runExport` with no entitlement check.

So a free user taps Export and gets their CSV.

The listing takes the shipped behaviour, not the paywall's claim: exports appear
in the free bullet list ("Everything exports — … It's your data"), and the
Premium paragraph does not mention them. That is the only safe direction. A
listing that promises a free feature and delivers it is fine. A listing that
sells a paid feature the app gives away is a listing that will need editing the
week someone notices.

**This is a bug in one of the two places, and the listing can't decide which.**
Either the gate is missing from Settings or the string is stale on the paywall.
Both are one-line fixes and they are opposite fixes, so it needs a product call,
not a code call.

## Contradiction 2: the rest timer is half-gated, and the half that matters is free

`PremiumGate` wraps the rest-timer **switch** in Settings. It does not wrap the
timer. `active_workout_view.dart` holds

```dart
bool _restTimerEnabled = true;
…
_restTimerEnabled = prefs.getBool('rest_timer_enabled') ?? true;
```

and calls `showRestTimer(context)` on set completion with no entitlement check
anywhere in the path. The preference defaults to `true` and a free user has no
way to write `false` — the switch that would do it is behind the gate.

The net effect is inverted from what the gate looks like it is doing: **free
users get the rest timer and cannot turn it off; paying users get the ability to
turn it off.** Whether that is the intent or an accident, the timer itself ships
to everyone, so the listing states it as a free feature and says nothing about
the toggle. Worth someone deciding on deliberately; the current arrangement
reads like a gate that was placed on the settings row because that is where the
feature "lived" in the UI, without following where the behaviour actually runs.

---

## The numbers in the copy, and where each came from

Specific numbers outperform adjectives in store copy — "873 exercises" is a
reason to install, "a huge exercise library" is noise — but only if they are
right. Each one in the listing is a count taken from the repo, not an estimate:

| Claim | Source | How it was counted |
|---|---|---|
| 873 exercises | `lib/core/seed_exercises_data.dart` | `grep -c "name:"` on the generated seed list; the file's own header comment splits out 581 strength |
| 7,140 verified foods | `assets/data/verified_foods_de.json` | length of the `foods` array |
| BLS as the source | same file | its `source` / `citation` / `doi` keys — the dataset carries its own provenance, which is why the copy can name it |
| Open Food Facts for barcodes | `service_locator.dart`, `food_api.dart` | the `world.openfoodfacts` host is in the client config |
| ECDH P-256, AES-256-GCM | `feature/chat/domain/chat_crypto.dart` | `ChatEncryption.ecdhP256AesGcm`, documented in `docs/chat-encryption.md` |
| English + Deutsch | `main.dart` | `supportedLocales: const [Locale('en'), Locale('de')]` |
| Free tier: 3 templates, 10 custom foods | `intl_en.arb` | `freeTemplateLimitReached`, `paywallFeatureCustomFoods` |

The exercise and food counts are the two most likely to rot. Both come from
generated or bundled data files, so both change silently when someone
regenerates a seed. If either is regenerated, the listing needs the new number —
that is a manual step, and this table is the only place that records it.

---

## What was deliberately left out

**"AI-powered" anything.** There is none. The adaptive TDEE card
(`adaptive_tdee_service.dart`) is a rolling energy-balance calculation over
logged weight and food. Calling that AI is the sort of thing that wins a week of
installs and loses the review score permanently.

**Step counting, sleep, heart rate, HealthKit / Google Fit.** No integration
exists. These are the top of every fitness-app keyword list, which is exactly
why they are tempting and exactly why including them would be a lie that the
first reviewer catches.

**The Trainer Console as a headline feature.** It is real and it is good, but a
consumer store listing sells to the person tapping Install, and that person is
overwhelmingly a trainee. It gets a paragraph — "if your trainer uses ForgeForm"
— framed as something that happens *to* the reader, not a product they are being
asked to evaluate. `trainer-console-spec.md` positions it for trainers; that is a
different listing, and arguably a different SKU.

**"Fitness" as a keyword.** The keyword field caps at 100 characters. Spending
seven of them on a term where the app ranks somewhere past the fourth page is
seven characters not spent on "barcode", where it can genuinely compete.

---

## The screenshots, and why they are HTML

`store/screenshots/screens.html` + `render.mjs` produce twelve PNGs — six
panels at each store's phone size — with Playwright driving the Chromium the
e2e suite already has. The alternative was capturing the running Flutter app.
Both were viable; HTML won on three counts.

**It follows the tokens by construction.** The `:root` block is a transcription
of the token list in `CLAUDE.md`. A designer's export drifts from the app's
theme; this file cannot, because the values are the same values.

**It is diffable.** Re-rendering after a copy change is `node render.mjs`, and
the change shows up in a text diff of the markup. A PNG from a screen recording
is a binary blob that nobody can review.

**It sizes itself.** The whole layout is expressed in `rem` where
`.shot { font-size: calc(100vh / 100) }` — one rem is one percent of the shot's
height. Adding a store size is a row in the `TARGETS` array, not a redesign.

The obvious cost, stated plainly at the bottom of `LISTING.md`: **these are
designed mocks, not captures of the shipping build.** Apple's guideline 2.3.3
and Play's store-listing policy both require screenshots to show the actual app.
These are honest — every element corresponds to something in the code — but they
are drawn, and drawn artwork drifts from a build the same way prose does.
Before submission they get replaced by real captures or verified panel by panel
against the running app.

### Two CSS bugs worth remembering, because both rendered silently

**Percentage heights collapse inside an auto-height flex item.** The weekly
volume chart was `height: 56%` inside a column whose own height came from its
content. Every bar resolved to zero. No error, no warning — the card just
rendered as a label, a caption, and a strip of day names with nothing between
them, which reads as "designed that way" rather than "broken". The fix is a
resolved height on the plot (`height: 16rem`) with the columns stretching inside
it. This is the layout equivalent of the `waitFor`-on-nothing trap in
`docs/e2e-playwright.md`: the failure produces a *plausible* result, so nothing
draws your attention to it.

**A clipped card reads as a broken render; a faded one reads as scroll.** The
same markup fills a 1290×2796 iOS canvas and a 1080×1920 Play canvas, so content
that fits one gets cut by the other — on the Play nutrition panel, mid-word
through a heading. A mask on `.screen` fading the last 5rem turns that cut into
an affordance. It costs nothing on the taller canvas, where the fade falls over
empty background.

Both are the same lesson as the two contradictions above, one layer down: the
dangerous failure is not the one that throws. It is the one that produces
something that looks finished.

---

## The rule this leaves behind

**A user-facing claim is a behavioural assertion stored where nothing checks
it.** Paywall strings, onboarding copy, store descriptions and release notes are
all in this category. Treat them the way you would treat a comment claiming an
invariant: assume it was true when written, verify it against the code before
relying on it, and when you change the behaviour, go and find the prose.

Concretely, for this repo:

- Changing a `PremiumGate` means checking `store/LISTING.md` §3 and the
  `paywallFeature*` strings in both `.arb` files. All three describe the same
  boundary and none of them import each other.
- Regenerating `seed_exercises_data.dart` or `verified_foods_de.json` means
  updating the counts in §1–§3 of the listing. The table above says which.
- Adding a genuinely new user-visible capability means the listing is stale
  until someone edits it, and nothing will tell you.

`CHANGELOG.md` records what changed. `PLAY_NOTES.md` tells existing users what
changed. `store/LISTING.md` tells someone who has never opened the app what it
is — and it is the only one of the three that goes stale without anyone
noticing, because the people who would notice never installed it.
