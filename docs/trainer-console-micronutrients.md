# Micronutrients: the Trainer Console's Nutrition tab, and the trainee diary

A walkthrough of how micronutrient tracking works, written to be read on its
own. It covers three defects that were sitting in the trainee app's existing
micronutrient feature before this change touched it — none of them a type
error, all three invisible until a number was compared to something else —
plus the design decisions the diff alone doesn't explain: why values are
stored in grams everywhere, why the day total folds the way it does, why a
pin write replaces a set instead of editing it, and where the premium gate
actually lives.

§8 was added later and records a fourth defect of the same family, found the
way the first three were: by a user noticing two numbers on one screen that
should have agreed and didn't.

Line references are to the commit that introduced this document, except in
§8, which points at the commit that added it.

---

## 1. The feature already existed. It was already wrong.

Before this change, `ExtendedNutrients`
(`fittnes_tracker/lib/feature/food_tracking/data/models/extended_nutrients.dart`,
now `lib/core/nutrition/extended_nutrients.dart`) already parsed 21
nutrients from OpenFoodFacts, stored them as a JSON blob on `food_item`, and
rendered them per-food behind a premium gate in `food_detail_view.dart`. It had
shipped, presumably been used, and nothing about it looked broken — because
nothing had ever needed the numbers to be *right*, only present. Building a
day-level aggregate and a target-relative bar on top of it is what made three
existing defects visible for the first time.

### 1a. A unit label is a string, and a string is never wrong

`ExtendedNutrients.fromNutriments` stores OpenFoodFacts' `vitamin-c_100g` field
verbatim — call it `0.053` for 53 mg of vitamin C. `food_detail_view.dart`
rendered that value like this:

```dart
nutrientTile(loc.nutrientVitaminC, nutrients.vitaminC, loc.unitMg),
```

`loc.unitMg` is the string `"mg"`. The code prints `0.053`, labels it `"mg"`,
and the screen reads "Vitamin C: 0.05 mg". Nobody wrote `0.053 mg` on purpose;
nobody had to. Dart's type checker verified that `nutrients.vitaminC` is a
`double?` and that `loc.unitMg` is a `String`, and both of those things were
true. Whether the *number* the code multiplies by nothing actually means what
the *label* claims is not a type — it's an invariant that lived only in
whoever wrote the OpenFoodFacts parser's head, and it silently stopped holding
the moment the parser stored a value the display code assumed had already been
converted.

Five of the twenty-one fields (`fiber`, `sugar`, `saturatedFat`, `salt`,
`sodium`) happen to be correct, because their display unit *is* grams, which is
also the storage unit — the bug is invisible by coincidence on those five and
present on the other sixteen. That's what let it ship: a screen with 21 rows
where 5 look right is a screen that looks right.

This stayed invisible for exactly as long as nothing compared one of those 16
numbers to anything else. A raw `"0.05 mg"` on a detail screen reads as a
small, plausible amount of a micronutrient — it doesn't look *wrong*, it looks
like someone ate very little vitamin C. The defect only becomes obvious once
you divide it by a target: 0.05 mg of a 90 mg target is a 0% bar, every day,
for every user, for every affected nutrient. Building the Trainer Console's
target-relative bars is what forced the fix, not a review of the existing
trainee feature.

**The fix**, in `lib/core/nutrition/nutrient_defs.dart`, is a single
conversion table (`NutrientDef.gramsToDisplay`) that both the trainee's
existing per-food card and the new console surfaces read from. A unit is now a
number (a multiplier) attached to the same definition that owns the label,
the target, and the grouping — not a second, independently-typed string
chosen by whoever wrote the row.

### 1b. `scaleTo(double)` cannot express "this argument means per-100g"

`ExtendedNutrients.scaleTo(double grams)` divided every field by 100 and
multiplied by `grams`. That's correct for an OpenFoodFacts result, which is
always reported per 100 g. It is wrong for a **re-added local food**: when a
trainee re-logs a food they already saved, `food_add_screen.dart` builds a
product map whose macros are already scaled to that food's own serving —
`_gramm`, which can be anything. The macros beside `scaleTo` handled this
correctly:

```dart
final base = widget.foodItem.gramm > 0 ? widget.foodItem.gramm.toDouble() : 100.0;
// … calories/protein/carbs/fat all divide by `base`
extendedNutrients: extended?.scaleTo(grams),   // always divides by 100
```

Log 500 g of a food whose own serving is 250 g, and the macros scale by
`500/250 = 2×`. The micronutrients, going through `scaleTo`, scale by
`500/100 = 5×`. Both numbers sit on the same screen, both came from the same
edit, and they disagree by a factor of 2.5 — not because either line is
*wrong* on its own (`scaleTo(100 → grams)` is exactly what its name says) but
because the two call sites hold incompatible beliefs about what "the stored
value" already represents, and nothing about the type `double` distinguishes
"grams consumed" from "grams this blob is already scaled to."

**The fix** replaces the implicit contract with an explicit one:
`rescale({required double fromGrams, required double toGrams})`. `scaleTo` no
longer exists — there is no version of this method left to call with only one
end of the scaling specified, so a caller cannot accidentally assume the other
end is 100. Every call site (`food_detail_view.dart`'s save handler,
`food_tracking_screen.dart`'s inline portion editor) now passes the same
`base` the macros beside it already compute.

### 1c. Editing a food's weight silently discarded its micronutrients

`FoodItemDao.updateFoodItem` took `calories`, `protein`, `carbs`, `fat`, and
`gramm` — no `extendedNutrientsJson`. Editing a food's logged weight rewrote
every macro for the new amount and left the micronutrient blob at whatever it
was for the *old* weight. This one isn't a unit bug or a scaling bug; it's a
parameter that was never there, so there was nothing for the compiler to
flag and nothing for a reviewer to notice unless they already knew the column
existed.

**The fix** adds the parameter, defaulting to `Value.absent()` (leave
untouched) so the many callers that only ever touch macros are unaffected,
and threads a `rescale`d value through from every caller that has one to give.

### What these three have in common

None is a logic error a unit test on the function in isolation would have
caught — `scaleTo(100)` genuinely does divide by 100, correctly, every time.
Each is a *contract* violated at the boundary between two pieces of code that
each individually did what they said. The fix in every case is to make the
contract a value the type system can see (`fromGrams`/`toGrams` instead of an
implicit 100; a table instead of a per-row unit string) rather than a fact a
future reader has to already know.

---

## 2. Storage is grams, everywhere, forever

Every `ExtendedNutrients` field is in grams, full stop — regardless of
whether the value came from OpenFoodFacts (already grams) or from BLS 4.0
(mixed mg/µg/g, converted once, at seed-generation time, never at read time).
This was a deliberate choice over the alternative of storing each field in
"its" natural unit (mg for calcium, µg for vitamin D, …):

- **One conversion, one place, one direction.** `NutrientDef.gramsToDisplay`
  in `lib/core/nutrition/nutrient_defs.dart` is the only place a stored value
  is ever multiplied by anything to become a number a person reads. Storing
  mixed units would mean every summing operation — the day total, the meal
  total — would need to know which unit each field is in before adding two of
  them together, and the C# mirror of that table would have to agree byte for
  byte or a fold across the API boundary would silently misconvert one side.
- **No migration for a data source that didn't exist yet.** Every row written
  before this change is already in grams (OpenFoodFacts' own convention).
  Making grams the *rule*, not an accident of the first data source, means
  joining in BLS costs a one-time import-time conversion and nothing else —
  no backfill, no versioned blob, no "which unit is this row" flag.

BLS 4.0 (`assets/data/bls_nutrients.json` at generation time, since deleted —
see §5) reports each of its 138 component codes in a unit named in
`bls_components.json`: grams for fibre, milligrams for iron, **micrograms**
for vitamin B6 and vitamin K. `tool/generate_verified_foods.py` reads that
unit per code and converts — never a hardcoded factor per nutrient, always
looked up:

```python
UNIT_TO_GRAMS = {"g": 1.0, "mg": 0.001, "µg": 0.000001, "ug": 0.000001}
factor = UNIT_TO_GRAMS.get(unit)   # unit comes from bls_components.json
return value * factor
```

Getting one nutrient's factor wrong here is the exact same failure mode as
§1a — a plausible-looking number, invisible until compared to a target — so
the fix for that defect and the design of this importer are the same
decision: never let a unit be a fact someone has to remember; always let it be
a value read from the data that names it.

### Null, zero, and "TR" are three different things

BLS's own legend is explicit: `"null": "no data available - do not interpret
as zero"`, and separately, `"TR": "traces: present, exact amount unknown"`.
This is the same distinction `ExtendedNutrients` needed to make about
OpenFoodFacts data (nothing enforced it there either, until now) — a nutrient
nobody measured is not the same fact as a nutrient measured at zero, and
folding the two together produces a lie in exactly one direction: it makes a
food, or a day, look *more* deficient than the data actually supports.

`tool/generate_verified_foods.py` maps both `null` and `"TR"` to "absent" (the
key is omitted from the food's `extendedNutrients` object entirely) and
leaves a genuine reported `0` as `0` — raw oats' vitamin A, vitamin C and
vitamin B12 are all real, quantified zeros in BLS and appear as `0.0` in the
generated seed, while alfalfa sprouts' vitamin E is simply not a key in that
food's object at all, because BLS never measured it.

`ExtendedNutrients.operator+` (Dart) and `ExtendedNutrients operator +` (C#,
`FitTracker.Api/Nutrition/ExtendedNutrients.cs`) both implement the same
null-preserving rule, independently, because they run on opposite sides of the
API boundary and neither can call the other:

```dart
double? add(double? a, double? b) =>
    a == null && b == null ? null : (a ?? 0) + (b ?? 0);
```

`null + null == null`. `null + 5 == 5`. Only when *both* sides are silent does
the sum stay silent; the moment either side reports a value, the fold reports
it. `ExtendedNutrients.sum([])` (the identity, folded over zero foods) is
all-null — a day with nothing logged has *no* micronutrient data, not zero
grams of everything.

---

## 3. The day total is folded from `loggedMeals`, and there is exactly one reason why

`TrainerConsoleService.GetClientNutritionSummaryAsync` already had a
double-counting incident before this feature existed:
`docs/trainer-nutrition-duplicate-meals.md` and
`docs/trainer-console-duplicate-rows.md` both describe how a client's app
re-pushing the same meal twice — same day, same category, split or duplicated
across two rows — used to show the trainer double the actual calories,
because the day total was computed by re-traversing the raw `Meal` rows
independently of the already-deduplicated `loggedMeals` list the meal
cards render from. Two numbers, same screen, same day, disagreeing by 2×.

The fix for *that* bug was `CollapseRepushedMeals`, applied once, on the way
into `loggedMeals`. The lesson it left behind — stated explicitly in
`docs/trainer-console-duplicate-rows.md` — is that **a read-side fold has to
share the write path's idempotency key, or it will find a different set of
duplicates than the write path already resolved.** Any second, independent
pass over the raw rows is a second chance for that to happen again, for
whatever new number is being computed.

So the micronutrient day total does not re-scan `todaysMeals`. It's folded
from the exact same per-meal values already computed while building
`loggedMeals`:

```csharp
(LoggedMealDto Dto, ExtendedNutrients? Nutrients) BuildLoggedMeal(
    IGrouping<string, MealResponseDto> sameCategory)
{
    // `foods` here is already CollapseRepushedMeals-cleaned.
    var foodNutrients = foods.Select(f => ExtendedNutrients.TryParse(f.ExtendedNutrientsJson));
    var mealNutrients = /* fold of foodNutrients */;
    return (dto, mealNutrients);
}

var loggedMealResults = todaysMeals.GroupBy(...).Select(BuildLoggedMeal).ToList();
var dayNutrients = ExtendedNutrients.Sum(loggedMealResults.Select(r => r.Nutrients)...);
```

If a future change ever needs the day's micronutrients computed some other
way, the one question to ask first is whether that path also runs through
`CollapseRepushedMeals` — if it doesn't, it will eventually double-count the
next time a client re-pushes a meal, for exactly the reason the two docs above
already had to fix twice.

---

## 4. A trainer's pin write replaces the set. It never edits one row.

`TrainerNutrientPin` rows are never added or removed individually — a PUT to
`api/TrainerConsole/{clientId}/nutrient-pins` takes the *entire* pinned set and
`TrainerNutrientPinRepository.ReplacePinsAsync` deletes every existing row for
that `(trainer, client)` pair and inserts the new set, in one `SaveChanges`
call.

This is the same trap `docs/trainer-console-duplicate-rows.md` names directly:
*"an idempotent outer call doesn't make its side effects idempotent."* A
`ToggleNutrientPin(key)` endpoint would be simpler to call from the client,
but its side effect — flip one row's presence — is only correct if the client
and server agree on the *current* set before the toggle, and two devices (or
one device retrying a failed request) toggling the same key can leave the pair
in a state neither side intended, silently, with no error to observe. A "set
these N keys" write has no such window: applying it twice, from two devices,
in either order, produces the same final set either time.

The trade-off is a marginally larger payload per write (the whole set instead
of one key) for a property (idempotence of the actual database state, not
just of the HTTP call) that a chat-adjacent, sync-adjacent codebase has
already paid to relearn twice.

---

## 5. The premium gate is enforced where the data is, and it has an honest limit

Per `CLAUDE.md`, the Trainer Console's client-side gate (`TrainerConsoleGate`)
is a UX guard, never a security boundary — every endpoint independently
re-checks the caller. Micronutrients follow the same rule, one level deeper:
the *values themselves*, not just the card that would show them, are absent
from the API response when either party isn't entitled.

```csharp
var micronutrientsLocked =
    !await _trainerClientService.DerivesProAsync(trainerId) ||
    !await _trainerClientService.DerivesProAsync(clientId);
// …
var foodNutrients = micronutrientsLocked
    ? []
    : foods.Select(f => ExtendedNutrients.TryParse(f.ExtendedNutrientsJson));
```

`DerivesProAsync` reuses the exact rule `TrainerClientService.GetStatusAsync`
already computes as `ProFromLicence` — a paid, current licence, either the
caller's own or (for a client) their trainer's — rather than a second,
independently-maintained copy of `docs/trainer-licensing.md`'s entitlement
logic.

**The honest limit:** device-side IAP premium (`AccessProvider._isPremium`,
backed by RevenueCat) is invisible to the server — it never crosses the API
boundary, by design (see `docs/trainer-licensing.md` on why premium must be
server-computed). So "premium" in this gate means *licence-derived* Pro only.
In practice this rarely matters for a coached trainee: a client of a paying
trainer already derives Pro from that trainer's licence
(`proFromTrainer` in `GetStatusAsync`), so the client-side half of this gate
only actually bites once the trainer's own licence has lapsed. That's stated
plainly here rather than implied, because it would be easy to read the two
`DerivesProAsync` calls as two independent checks when the second one is, for
most clients, already implied by the first.

---

## 6. Where the target numbers came from, and why they don't all agree

The Trainer Console design specifies 10 nutrients with daily reference
targets (fibre 30 g, sugar 50 g, saturated fat 22 g, sodium 2300 mg,
potassium 3500 mg, calcium 1000 mg, iron 8 mg, magnesium 400 mg, vitamin C
90 mg, vitamin D 20 µg) and calls them final. The product wants bars for all
21 nutrients `ExtendedNutrients` carries, so the other 11 needed a source that
wasn't the design: they use EU NRV values (Regulation 1169/2011, Annex XIII).

The two provenances don't always agree with each other on nutrients they
*both* cover in spirit — the design's iron target (8 mg) is lower than the EU
NRV figure (14 mg) most adult reference tables use; calcium (1000 vs. 800) and
potassium (3500 vs. 2000) similarly diverge. This document keeps the design's
10 numbers verbatim rather than reconciling them against NRV, because the
design's own fidelity note calls them final and this feature did not have a
mandate to relitigate that. It's recorded here as a known inconsistency, not
a hidden one — a future pass that wants one consistent reference table across
all 21 nutrients has a real decision to make, and this is where to find out
why the numbers don't currently match.

Every target in `nutrient_defs.dart` is a **general-population reference
intake**, not a per-client goal — this app has no per-client micronutrient
targets, unlike its calorie goal (`UserSettings.DailyCalorieGoal`). The UI
says "of 30 g", never "your target", and nothing here should be read as
personalised advice.

Salt and sodium are both present as separate, independently pinnable
nutrients despite being roughly proportional (salt ≈ sodium × 2.5) — that's
not an oversight, it's what "all 21 fields `ExtendedNutrients` carries" meant
when the target list was extended past the design's original 10.

---

## 7. What was rejected, and why

**A bottom sheet for the meal detail view**, matching the old
`MealDetailSheet` this feature replaces. The new screen needs a per-item
breakdown *and* a full 21-row micronutrient rail with its own scroll region —
that doesn't fit a sheet stacked over the Nutrition tab without either
truncating one of the two, so it's a pushed screen
(`MealDetailScreen`) instead. It is deliberately **not** a
`TrainerConsoleRoute` value: that enum drives the sidebar and bottom tab bar,
and a drill-in from tapping a meal must not become a permanent nav
destination.

**Device-local pin storage** (`SharedPreferences`, keyed by client id) instead
of a server-side table. It would have avoided a migration and an endpoint, but
the pins would vanish on a new browser or a reinstalled app — and the Trainer
Console is a **web-first** surface (`CLAUDE.md`: "the browser is the trainer's
workstation"), where "a new browser" is not an edge case, it's Tuesday.

**A runtime BLS lookup** instead of baking the join into the seed. This would
have avoided a one-time generation step, but at the cost of keeping the 4.3 MB
raw BLS matrix (`bls_nutrients.json`) shipped in every install forever, for
data that's fully static once matched — plus a second file
(`bls_components.json`) that has to keep agreeing with it. Joining once, at
build time, and deleting both raw files (recoverable from git history and the
DOI below, should BLS publish a new version) nets the app **smaller**, not
larger: the old `bls_nutrients.json` + `bls_components.json` + v2 seed totalled
~5.6 MB; the v3 seed alone is ~3.9 MB.

**Converting units in storage**, rewriting every existing `FoodItem` row to a
canonical mixed-unit representation instead of standardising on grams at the
read boundary. This would have meant a migration touching every client's food
library, for a conversion that costs nothing extra to do once, at display
time, in one table (`NutrientDef.gramsToDisplay`) both platforms already read
from.

---

## 8. The fourth defect: a call site that listed the fields it knew about

§1 collected three defects that were already sitting in the trainee's
micronutrient feature before the Trainer Console work touched it. This is the
fourth, found the same way — by a user comparing two numbers that should have
agreed — and it is the cheapest of the four to write and the hardest of the
four to see.

Open the food search from Breakfast, tap a food under **Recently Added**, and
the Food Details screen showed *no* Detailed Nutrition card at all. Add it,
and the day's **Tracked nutrients** card still read "No data logged today" for
every pinned nutrient — while the macro ring directly above it had just gone
from 0 g to 35 g of protein off the very same tap. One screen, one action, two
numbers, and only one of them moved.

### 8a. One omission, two symptoms

`FoodAddScreen` reaches the detail screen by two different doors, and they
were built at different times by different hands:

| Door | Builds the model with | Micronutrients |
|---|---|---|
| a search result (`_selectFoodItem`) | a product map carrying `_extended_nutrients_json` | carried |
| a Recently Added tile (`_recentFoodTile`) | `FoodItemModel(id:, name:, calories:, protein:, carbs:, fat:, gramm:)` | **dropped** |

That second constructor call is the whole bug. It is not wrong about
anything it says: every field it passes is the right field with the right
value. It simply stops after the four macros and the weight, because when it
was written those were all the fields there were. `extendedNutrients` and
`openFoodFactsId` were added to `FoodItemModel` later, as optional named
parameters — and an optional named parameter is, precisely, a field that
every existing call site is allowed to keep not mentioning.

Everything downstream then behaved correctly, which is what made it look
like two unrelated bugs:

- `food_detail_view.dart` gates its card on
  `if (widget.foodItem.extendedNutrients != null)`. Null in, no card. The
  screen didn't fail to render the data; it correctly rendered the absence of
  data it had been handed.
- "Add to log" inserts a **new** `FoodItem` row for the amount logged — the
  library entry is a recipe, the logged row is the meal — and writes
  `extendedNutrientsJson: Value(rescaledNutrients?.toJsonString())`. With
  `extendedNutrients` null, `rescaledNutrients` is null, and the row is
  written with an explicit null blob. `FoodTrackingScreen._dayMicronutrients`
  then folds over exactly that column and, per §2's null-preserving rule,
  correctly reports "no data" — because there genuinely was none in the row
  it read.

The second symptom is the first symptom, one table further on. There was
never a bug in the fold, in the gate, or in the insert: the data died at the
constructor and every screen after it was honest about what it had been
given.

### 8b. Why nothing caught it

The compiler had nothing to say and could not have had. `FoodItemModel` with
seven of its nine fields filled in is a `FoodItemModel`. There is no type
that means "a model built from a row, with nothing left behind" — the field
is `ExtendedNutrients?`, and `null` is a member of that type, so the omission
type-checks as the *value* null rather than registering as an absence of
code.

Worse, `null` is also load-bearing here in a way that hid the omission from
review. §2's central rule is that a nutrient nobody reported must stay null
through every fold rather than becoming a reported zero. That rule makes null
a legitimate, common, expected value on this field — most custom foods
genuinely have no micronutrients. So a null blob arriving at the detail screen
is not anomalous, is not loggable, and cannot be asserted against: the screen
cannot distinguish "this food has no micronutrient data" from "this food's
micronutrient data was dropped two frames ago by a caller that didn't know
the field existed." Both are null. Both are supposed to be null sometimes.

> The tests were no better placed. `test/food/food_detail_actions_test.dart`
> pumps `FoodDetailsScreen` with a hand-written `FoodItemModel` that has no
> micronutrients — because it is testing which action button renders, and
> micronutrients are irrelevant to that. It therefore reproduced the exact
> shape of the bug inside the test fixture and passed, as it should have.
> `test/nutrition/food_tracking_tracked_nutrients_test.dart` drives the
> tracked-nutrients card straight from an `AccessProvider`, deliberately
> avoiding the database, so it never sees a row at all. Every test in the
> area was correct, was passing, and was looking somewhere else.

This is the same shape as §1c — `updateFoodItem` missing an
`extendedNutrientsJson` parameter — and it is worth naming as a pattern
rather than as two incidents, because the two are *not* the same code and the
fix for one did nothing for the other:

> A nullable field added to an existing type does not fail; it defaults. Every
> call site written before the field existed keeps compiling, keeps passing,
> and quietly starts asserting "this thing has no such data" — an assertion
> nobody wrote and nobody can grep for.

### 8c. The fix, and why it is a factory rather than one more argument

The obvious repair is to add `extendedNutrients: …` to the constructor call
in `_recentFoodTile`. That fixes today's bug and leaves tomorrow's in place:
the next field added to `FoodItemModel` gets dropped by the same call site
for the same reason.

So the tile now calls `FoodItemModel.fromData(item)` — the factory that
already existed, one file over, that reads every column of a `FoodItemData`
including the two the hand-written copy forgot. The tile had a
`FoodItemData` in hand the entire time; it was destructuring it by hand
instead of converting it.

```dart
// before — compiles, runs, silently asserts "no micronutrients, no barcode"
foodItem: FoodItemModel(
  id: item.id, name: item.name,
  calories: item.calories, protein: item.protein,
  carbs: item.carbs, fat: item.fat, gramm: item.gramm,
),

// after
foodItem: FoodItemModel.fromData(item),
```

The rule this leaves behind: **a row-to-model conversion is a named factory,
never a constructor call spelled out at the call site.** A factory can be
under-filled in exactly one place, where it is reviewed once against the
table; a spelled-out constructor can be under-filled at every call site, and
each one looks complete on its own screen. `openFoodFactsId` came back for
free with the same change — a food re-logged from Recently Added had been
losing its barcode too, which is why editing such an entry could never
re-fetch its portion sizes from OpenFoodFacts.

### 8d. The `+` button was the same bug wearing different clothes

The Recently Added tile has a second action: `_quickAddFromRecent`, the `+`
that asks for a weight and logs the food without opening the detail screen at
all. It builds its own `FoodItemCompanion.insert(…)` and it, too, listed the
macros and stopped.

It needed one thing the tile fix didn't, and the difference is worth
understanding because it is §1b restated. The tile hands a model to a screen
that will do its own scaling later; `_quickAddFromRecent` writes the row
itself, at a weight the user just typed, so it owes that row a blob scaled to
that weight:

```dart
final base = item.gramm > 0 ? item.gramm : 100;
final rescaledNutrients = existingNutrients?.rescale(
  fromGrams: base.toDouble(),
  toGrams: newGramm.toDouble(),
);
```

`fromGrams: base`, never a hardcoded 100 — the same `base` the four macro
lines beside it are already dividing by. This is the third call site in the
codebase to pass exactly that pair, alongside `food_detail_view.dart`'s save
handler and `food_tracking_screen.dart`'s inline portion editor, and the
reason all three read identically is that `scaleTo` was deleted in §1b
specifically so that no fourth one could be written any other way.

### 8e. What was deliberately not fixed

Two other paths still write `FoodItem` rows with no micronutrients. Both are
real gaps; neither is this bug, and folding them in would have widened a
two-line fix into a feature.

- **Meal templates.** `MealTemplateItem` has no micronutrient field at all —
  not a dropped one, an absent one — so `applyTemplateToMeal` and
  `applyTemplatePortion` have nothing to carry. Giving templates
  micronutrients means a column, a migration and a sync change on both sides
  of the API, and it is a feature decision rather than a defect.
- **`food_search_screen.dart`**, the OpenFoodFacts picker used while
  *building* a template, inserts library rows from raw nutriment keys without
  ever calling `ExtendedNutrients.fromNutriments`. A food first added to the
  library through that door is permanently micronutrient-free, including when
  it later shows up under Recently Added. That one is a genuine three-line
  omission of the same family as this section, recorded here so the next
  person to open that file knows it is known.

### 8f. What is pinned

`test/food/recent_food_micronutrients_test.dart` drives both real screens
against an in-memory database: it seeds one food with a micronutrient blob,
taps its Recently Added tile, asserts the Detailed Nutrition card renders
both a gram-unit nutrient (fibre) and a converted one (iron, stored in grams,
shown in mg), then taps "Add to log" and asserts the **newly inserted row** —
the one the day fold actually reads — carries the blob, with the unreported
nutrients still null rather than zero.

It deliberately asserts on the database row rather than on the day card. The
card is one more screen away, and a test that stopped at the card would pass
just as happily if the fold were fixed to paper over an empty row. The row is
where the data has to be.

---

## Regenerating the seed

`tool/generate_verified_foods.py` requires `assets/data/bls_nutrients.json`
and `assets/data/bls_components.json`, both deleted from the repository after
generating v3 (see §7). To regenerate against a newer BLS export: re-download
those two files from the Bundeslebensmittelschlüssel project
(DOI `10.25826/Data20251217-134202-0`, cited in the generated seed's own
`citation`/`doi` fields), place them back under `assets/data/`, bump
`NEW_VERSION` in the script and `kVerifiedFoodsSeedVersion` in
`lib/core/seed_verified_foods.dart` together, and re-run the script from
`fittnes_tracker/`.
