# The list that never knew which meal it was in

Open the food search from Frühstück and from Mittagessen and screenshot both.
Before this change the two images were identical, pixel for pixel below the app
bar: the same ten foods under *Kürzlich hinzugefügt*, in the same order —
Philadelphia, eggs, cheddar, smoked salmon, cucumber, radishes, carrot, peanut
butter, rice flakes, hemp seeds. Only the title differed.

Nothing was broken. Every row was a real food this user had really added, and
the list was ordered exactly as its code said to order it. It was simply
answering a question nobody had asked. The screen exists to log *one meal* —
that is the whole reason it takes a `category` — and the list under it was the
only part of it that didn't know which meal that was.

Line references are to the commit that introduces this document.

---

## 1. What the screen actually read

`FoodAddScreen` is constructed with a category string (`Breakfast`, `Lunch`,
`Dinner`, `Snacks`) and passes it to everything it writes. The recent list read
one query:

```dart
Stream<List<FoodItemData>> watchVisibleFoodItems() =>
    (select(foodItem)
      ..where((t) => t.hiddenFromRecent.equals(false))).watch();
```

`FoodItem` is the device's whole food library. Look at its columns and the
shape of the problem is right there: `name`, four macros, `gramm`,
`hiddenFromRecent`, sync bookkeeping. **No category. No timestamp.** It is a
catalogue of foods, not a log of eating.

So "recently added" was inferred from `FoodItem.id` — the autoincrement,
descending — and "for this meal" was inferred from nothing at all, because
there was nothing in the query to infer it from. The category on the widget was
used for the title and for the write, and never once for the read.

The data to do better was on the device the entire time, one join away:

| Table | What it holds |
|---|---|
| `MealTable` | one row per day per category — this is where `Breakfast` lives |
| `MealFoodTable` | `mealId` → `foodEntryId`, the foods in that meal |
| `FoodItem` | the food itself |

## 2. Why nothing caught it

The compiler had nothing to say, and could not have. `List<FoodItemData>` is
the same type in every permutation; there is no type that means "ordered by
relevance to the meal being logged". Ordering is the classic property that
survives every static check and every green test suite — `test/nutrition/`
asserted on *totals*, which are order-invariant by definition, and no test
anywhere asserted that a list came back in a particular sequence.

Neither did anyone reading the code. `watchVisibleFoodItems()` is a correct
function with an accurate name and a useful docstring. The defect is not inside
it; it is in the gap between what it returns and what the screen calling it
needed. That gap is invisible unless you hold both ends at once.

> A screen opened per-context that reads context-free data will look right,
> pass review, pass its tests, and be useless.

This is the same shape as the duplicate-meals bug
(`docs/trainer-nutrition-duplicate-meals.md`): correct code on both sides of a
seam, and a rule that lived in nobody's head but the user's.

## 3. The fix, and the two things that made it non-obvious

`MealDao.watchFoodNamesLoggedInCategory` joins the three tables and returns the
normalised names of every food ever logged under a category, most recent first.
`_buildRecentFoods` partitions the deduplicated recent list against it: foods
eaten at this meal on top under *Bei dieser Mahlzeit gegessen*, everything else
under *Weitere Lebensmittel*.

Two decisions inside that are not obvious from the diff, and both would have
produced a feature that compiles, runs, and silently does nothing.

### It matches on name, not on food id

The obvious join is `MealFoodTable.foodEntryId` → the id of the row in the
recent list. It would have returned almost nothing.

`_quickAddFromRecent` — the `+` button on every recent row — does not link the
food you tapped. It reads your gram amount, scales the macros, and **inserts a
brand-new `FoodItem`** carrying that portion, then links *that* row to the
meal:

```dart
final newFoodId = await db.foodItemDao.insertFoodItem(
  FoodItemCompanion.insert(
    name: item.name,                                 // ← the only field preserved
    calories: (item.calories * ratio).round(),
    ...
```

Every portion of oats you have ever logged is its own `FoodItem` row. The id in
`MealFoodTable` is a scaled sibling of the row on screen, never the row itself.
The only thing that survives the round trip is `name` — which is exactly what
the recent list has always deduplicated on (`name.toLowerCase().trim()`), so
the query normalises identically. `test/nutrition/recent_foods_by_meal_test.dart`
pins this with a test that reproduces the quick-add shape directly, because
"join on the id, it's a foreign key" is the natural simplification for the next
person to reach for.

### It orders on `MealFoodTable.id`, not on `MealTable.date`

`MealTable.date` is the client's local midnight stored as an instant — day
granularity, deliberately (see `MealDayWindow`, and
`docs/trainer-nutrition-duplicate-meals.md` on why it is not a `date` column).
Every food eaten at one meal on one day ties on it, which is most of the foods
that matter. `MealFoodTable.id` is assigned at the moment the food is logged
and orders within a day for free.

That is still a proxy, and worth being honest about: `SyncService._pullFoodItems`
re-inserts pulled rows with fresh local autoincrements, so after a re-login or
a device switch the ids reflect the server's response order, not chronology.
The existing list had exactly this weakness — its ordering was `FoodItem.id
DESC` — so this is not a regression, but nothing here should be described as
"ordered by when you ate it". It is ordered by when this device learned about
it. A real fix is a logged-at column, which is a schema migration and a sync
change, and is not this.

## 4. Normalising the category, once

The query filters on `MealTable.category`, and that string has been written two
ways: snacks were `Snack` and are now `Snacks`, and the tracker capitalises
where the API's DTOs document lowercase. A raw `==` here would have quietly
shown a user none of the snacks they logged before the rename.

The fold already existed three times — `MealTemplateDao`'s read migration, the
Trainer Console's private `_key`, and the server's `MealCategory.AreSame` — so
adding a fourth was the one thing not to do. `lib/core/nutrition/meal_category.dart`
is now the client's single copy, mirroring the server's, and the Trainer
Console's `_key` delegates to it.

SQL cannot express the fold, so `MealCategory.spellings()` exists to hand a
query the list of strings that fold to the same key, compared against
`lower(category)`. That is the honest shape of it: the normalisation lives in
one place, and the places that cannot call it get their input from it.

**Still not converted, deliberately:** `NutritionRepository.addFoodToMeal` and
`getFoodItemsForCategory` compare categories with `==`, as does
`MealDao.getMealByDateAndCategory`. Those are write-path comparisons — changing
what counts as "the same meal" for a *write* can merge rows that are currently
separate, which is a data change, not a display change. It should happen, with
its own test coverage, and not tucked inside a change to a list's ordering.

## 5. Degrading, and the empty case

Two behaviours in `_buildRecentFoods` are there on purpose and read like
oversights:

- The affinity stream is **not** gated on `hasData`. If it is slow or fails,
  `names` falls back to empty and the recent list renders flat — the ordering
  is a nicety, and it must never be able to hold hostage data the screen
  already has in hand.
- When nothing has ever been eaten at this meal, the list renders with **no
  headers at all**, not with *Weitere Lebensmittel* as the only heading. A
  heading that says "other" with nothing to be other than is worse than no
  heading; a fresh install would have been the first thing every new user saw.

The shared `_sectionHeader` these use also raised the label opacity from 0.55
to 0.75. The 0.55 the search-result headings already used is fine for the
de-emphasised body text it was written for, but at 12px on the light surface it
lands near 3.5:1 — under the 4.5:1 AA floor, on text that now carries meaning
rather than decorating a list that was already grouped by where it came from.

## 6. What to take from this

- **A per-context screen must read context-aware data.** The category was
  present, threaded through the constructor, used on the write path, and simply
  never reached the read. Check what a screen's parameters are actually used
  *for*, not just that they are used.
- **Ordering defects are invisible to types and to totals.** No type expresses
  it and no sum changes. If an order matters to the user, assert on it in a
  test, because nothing else will.
- **Follow the write path before you join on a foreign key.** `foodEntryId` is
  a real reference to a real row; it just isn't the row anyone means. The
  natural join here produces an empty result and no error.
- **A proxy for time is not time.** An autoincrement is chronological until
  something re-inserts, and sync re-inserts. Say so in the docstring rather
  than letting the next reader assume more than it gives.
