# Duplicate meals: an invariant only one client believed

The Trainer Console's Nutrition tab listed a client's day as two breakfasts, two
lunches, two dinners and two snacks. The client's own app showed the same day as
four meals, correctly, on the same data.

Both screens were right about what they read. There genuinely were two rows for
each category in the database, and there had been for a long time — the trainee
app simply cannot render a duplicate, so nothing had ever reported one. The
console is the first surface in this product to list meal rows as rows, and the
first thing it did was surface a rule that four separate pieces of code assumed
and nothing enforced:

> A meal is one row per user, per day, per category.

Line references are to the commit that introduces this document.

---

## 1. Who believed the rule

Every place the client app touches a meal treats day + category as its identity:

| Code | What it assumes |
|---|---|
| `NutritionRepository.addFoodToMeal` | looks the day's meals up, reuses the row whose category matches, creates one only if there isn't one |
| `NutritionRepository.getFoodItemsForCategory` | `firstWhere((m) => m.category == category)` — reads *the* row |
| `food_tracking_screen.dart` | renders four fixed sections: Breakfast, Lunch, Dinner, Snacks |
| `MealDao.deduplicateMeals` | groups local rows by `date|category` and merges the extras away |

The server believed nothing. `Meals` has no unique constraint on that triple,
`POST api/Meal` inserted whatever it was given, and `GET` handed back whatever
was stored. That is not an oversight anyone made in a single place — it is the
default. A rule that lives only in the code that happens to write the data is a
rule the data does not have.

## 2. Where the second row came from

None of these involve a user logging breakfast twice.

- **A reconcile that guessed wrong.** `SyncService._reconcileTable` fetches the
  server's list and clears the local `serverId` of any row it can't find, so the
  next push re-creates it. A fetch that fails midway, or a row that is filtered
  out of the response, resets a meal that was never gone — and `_syncNewMeal`
  POSTs a second copy of it.
- **A lost response.** `_syncNewMeal` marks the row synced *after* the POST
  returns. If the app is killed, or the network drops, between the server
  committing the row and the client storing its id, the meal stays pending and
  is pushed again.
- **A second device.** Two installs each with an unlinked local row for the same
  day push independently; each POST created its own row.
- **The category rename.** Snacks were once written `"Snack"` and are now
  written `"Snacks"` — `MealTemplateDao` still migrates the old spelling on
  read. A client logging a snack after that rename could not match the row it
  had written before it, so it made a new one.
- **The local cleanup that only cleaned locally.** `MealDao.deduplicateMeals`
  merges duplicate *local* rows and deletes the extra — without deleting its
  server twin, which it has no way to do from a DAO. The device ends up tidy and
  the server keeps the row forever.

The last one is worth dwelling on. Someone had already found this bug, on the
device, and fixed the half of it they could see. The fix made the symptom
permanently invisible to the only reader that existed at the time.

## 3. Why nothing caught it

The compiler had nothing to say: `List<Meal>` is the same type whether it holds
one breakfast or two. Neither did the tests — `MealRepositoryTests` seeds one
meal per day, and under one meal per day the two readings are identical.

The arithmetic mostly didn't give it away either, which is what kept this quiet
for so long. Everything numeric on this screen — the calorie ring, the macro
bar, the 7-day trend — sums *food entries*, not meals. Where the duplicate rows
divided a day's foods between them (§2's local-cleanup and second-device cases),
every total was already correct and agreed with the client's own numbers to the
kilocalorie. Only the row count was wrong, and only one screen displayed it.

> A duplicate that changes a total gets found by whoever reads the total. A
> duplicate that only changes what a list looks like waits for the first client
> that renders the list.

### The case that does move the numbers, and isn't fixed here

The reconcile path is different in a way worth writing down. `_reconcileTable`
clears the food entries' `serverId`s along with the meal's, so the next sync
re-pushes those foods as well as the meal. Before this change that produced two
meal rows holding the same food; after it, one meal row holding that food twice.
Either way the day's calories are inflated by the re-pushed food, and that half
of the problem is **still there**.

It stays there deliberately. A meal holding the same food twice is exactly what
a client eating two portions of it looks like — `LoggedMealDto.Foods` documents
that repeats are real — so nothing downstream can tell an accidental repeat from
a deliberate one. The fix belongs where the accident is: the reconcile pass
resetting a row whose server copy was never gone. That is a client change on the
push path, out of scope for a read that had to stop lying today, and worth
doing before anyone trusts a trainer-facing calorie number to the kilocalorie.

## 4. The fix, in two halves

**The write path stops making them.** `MealService.CreateMealAsync` now looks
for a meal in the same category on the same day and returns it instead of
inserting a second (`FitTracker.Api/Services/MealService.cs`). Every one of the
causes in §2 is a *repeat* POST, so idempotency answers all of them at once,
including the ones we haven't thought of. The client needs no change: it reads
the returned id and posts its food entries against it, so two devices'
breakfasts merge into one meal exactly as two additions on one device do.

**The read path folds what already exists.** Idempotency does nothing about the
rows already in the database, and this is a fitness log — we are not writing a
migration that deletes a user's meals to make a list look nicer. The console's
nutrition summary groups the day's rows by category and totals across the group
(`FitTracker.Api/Services/TrainerConsoleService.cs`), so an affected client
reads correctly today, with no cleanup and no re-sync.

Both halves compare categories through `MealCategory.AreSame`
(`FitTracker.Api/Repositories/MealCategory.cs`) rather than `==`, so the
`Snack`/`Snacks` rename and the casing difference between the app's
`"Breakfast"` and this API's documented `"breakfast"` don't reopen the hole.

### What a database constraint would have cost

The obvious fix — a unique index on `(UserId, Date, Category)` — does not work
here, and the reason is instructive. `Meal.Date` is not a date. It is the
client's local midnight stored as an instant, so the same calendar day arrives
as `2026-08-20T22:00Z` from Berlin and `2026-08-21T04:00Z` from New York
(`MealDayWindow` exists entirely to undo this). Two rows that violate the rule
are usually not equal on that column, so the index would let them through while
rejecting perfectly good writes from a client that changed timezone. `Category`
has the same problem one level up: `"Snack"` and `"Snacks"` are the same meal
and different strings.

An index enforces equality. The rule here isn't equality — it's equality after
two normalisations, one of which is a 24-hour window centred on a day. Until
`Date` is a real `date` column, that rule can only live in code.

## 5. The other half of the report: Snacks

The same screen had a second, unrelated defect that made the duplicates look
worse than they were. `_MealsCard` matched the lowercase slugs its DTO documents
(`breakfast`, `lunch`, `snack`, `dinner`), but the app writes `Snacks`. Snacks
therefore fell through every lookup: generic plate icon instead of the cookie,
and sorted to the end of the list as an unknown category rather than between
lunch and dinner. The label happened to handle `'snack' || 'snacks'`, so the
row read *Snacks* while behaving like an unrecognised category — one of three
switches agreeing with reality was enough to hide it.

All three now key on one `_key()` normaliser
(`fittnes_tracker/lib/feature/trainer_console/presentation/view/nutrition_screen.dart`).
Three parallel `switch`es over the same string is three chances to be
inconsistent, and it took all three to notice.

## 6. What to take from this

- **An invariant enforced by every reader and no writer is not an invariant.**
  Four pieces of client code kept meals unique per day and category. The
  database was free to hold two, and did.
- **The client that can't see a defect is not evidence there isn't one.** The
  trainee app reads one row per category by construction. It would render a
  hundred duplicates as four meals and never complain.
- **Fixing a duplicate only where you can see it hides it.** The device-side
  de-duplication was a real fix that made the server-side rows permanent and
  silent.
- **Idempotent writes beat cleanup.** A create that returns the existing row
  covers every cause of a repeated POST, including causes nobody has diagnosed.
  A cleanup pass covers the ones it was written for.
- **Normalise once, in one place.** Both the `Snack`/`Snacks` rename and the
  casing drift between client and API were survivable individually. What made
  them bugs was that each comparison site decided for itself.
