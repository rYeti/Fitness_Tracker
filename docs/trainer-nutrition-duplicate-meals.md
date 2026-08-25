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

---

# Part two: the push path nobody was on

§4 above ended by naming one duplication this fix left alone — a re-push adding
the same food to a meal twice — and calling it client-side work. Going after it
turned up something larger, and the duplication was the least of it.

`MealDao.markMealPendingUpdate` and `MealDao.markMealPendingDelete` exist, are
written correctly, and had **no callers anywhere in the app**.

## 7. Three symptoms, one dead code path

`syncMeals()` iterates `getUnsyncedMeals()` — every meal whose `syncStatus` is
not `synced`. A meal that has been pushed once is `synced` forever, because the
only two functions that could take it back out of that state were never called.
So:

| What the user did | What the server was told |
|---|---|
| Logged breakfast, waited for a sync | Breakfast, with the food it had at that moment |
| Added coffee half an hour later | **Nothing.** The meal was `synced`, so it was skipped |
| Deleted the coffee again | **Nothing.** The local row was destroyed and no `DELETE` was ever issued |
| Synced again after a reconcile pass | The meal's foods, *appended a second time* |

The first row is the one that matters. A food logged after the day's first sync
never left the phone: not to the trainer, not to the user's other device, and
not to a reinstall. It looked fine locally forever, which is exactly why it went
unreported — the only screen that could show the difference is the trainer's,
and until Part One that screen was showing two of everything anyway.

`MealFoodTable.serverId` even carries the comment *"used to delete specific
entries"*. The column was added for a deletion that was never wired up. A field
whose doc comment describes a feature is not evidence the feature exists.

### Why nothing caught it

There is no failing call to find. `markMealPendingUpdate` compiles, is exported,
is covered by no test, and is referenced by nothing — and Dart's analyzer says
nothing about an unused *public* method on a DAO, because being called from
elsewhere is the entire point of a public method. The same is true of the
deletion endpoint on the API: `DELETE api/Meal/{mealId}/foods/{foodItemId}` is
implemented, tested at the repository level, reachable, and had no client.

> Two correct halves and no line joining them is invisible to every tool that
> checks halves. A status enum with no writer is a queue nobody joins, and it
> looks exactly like a queue nobody happens to be in.

## 8. Making the push a reconcile

The three symptoms have one shape — the server's copy of a meal's entries and
the device's copy were never compared, only appended to — so the fix is one
change of stance: **push by reconciling, not by appending**.

`planMealEntryPush` (`lib/core/network/services/meal_entry_reconcile.dart`) is a
pure function over "what this device has" and "what the server says it has". It
returns two lists: entries to **adopt** (the server already holds this food;
stamp the local row with the server's id) and entries to **push** (it genuinely
doesn't). Everything the server holds that the device doesn't is left alone.

Matching is by food **and count**, never set membership. Two portions of the
same food is a real thing to log, and the API's own DTO documents that repeats
are meaningful, so "the server already has an egg" cannot answer "should I push
this second egg". Local two, server one → adopt one, push one.

That one function covers the duplication from §4 (after a reconcile reset, all
the entries are adopted and nothing is pushed) and makes the additions fix safe
to turn on: `addFoodToMeal` now marks a pushed meal `pendingUpdate`, so
`_syncUpdateMeal` starts running on a path that had never run before, against
meals the server already has entries for.

Being a pure function is also the only reason it has tests. `SyncService` takes
a concrete `ApiClient` wrapping a private `Dio`; there is no seam to fake and no
sync test in this repo to copy. Pulling the *decision* out of the I/O left the
part worth asserting on assertable, and the part that isn't — three HTTP calls
in a row — small enough to read.

### The API had to stop lying first

`_syncUpdateMeal` believes the PUT response when it asks what the server holds.
`MealRepository.UpdateMealAsync` fetched the meal **without** `.Include`ing its
food entries, so `FoodEntries` serialised as `[]` — indistinguishable from a
meal with no food. A reconcile against that answer re-pushes everything, which
is the exact bug being fixed, arriving through the fix. One `.Include`, and a
test that pins it, because nothing else in the codebase would have noticed:
before this change, no caller read that field of that response.

## 9. Deletions need a tombstone, not a reconcile

Additions reconcile cleanly. Deletions cannot, and the reason is worth keeping.

Deleting a local `MealFoodTable` row destroys the only record that the entry
existed. An offline removal has nothing left to push. The tempting fix is to
extend the reconcile — "anything the server has that the device doesn't, delete"
— and it is wrong: the device's list is not the truth, it is *one device's*
truth. A phone that hasn't pulled since yesterday would silently delete every
food the user logged on the web in between.

So removals leave a `MealFoodDeletionTable` row: the meal's server id, the
food's server id, when. Keyed exactly the way the delete route is
(`DELETE api/Meal/{mealId}/foods/{foodItemId}` removes one matching row), so two
portions leave two tombstones and take two calls. `_syncMealFoodDeletions()`
drains the queue before any entry is pushed — a remove-then-re-add in the same
window has to be applied in that order, or the re-add is what gets deleted — and
treats a 404 as success, because the entry being gone is precisely what the row
was asking for. Nothing is queued when the meal or the food has no server id:
there is nothing there to delete, and a tombstone naming a meal the server never
had would retry forever.

The pull needs the matching guard. `_pullMeals` re-adds any server entry it
doesn't recognise, so between a removal and its push it would faithfully restore
the food the user just deleted. It now skips one server entry per queued
deletion — one, not all, so a second portion the user *kept* survives.

## 10. What to take from part two

- **Ask who calls it.** Every other check — types, tests, analyzer, review —
  looks at whether a function is right, not at whether anything reaches it.
  Two correct halves with no edge between them pass all of them.
- **A comment describing behaviour is not behaviour.** `serverId`'s "used to
  delete specific entries" outlived the deletion by however long it took someone
  to grep for the endpoint.
- **Silence on the client is not silence in the system.** Losing a food only
  after the day's first sync is invisible on the device that lost it. It took a
  second reader — the trainer — for anyone to be able to see it at all.
- **Reconcile additions; queue deletions.** Absence on one device means "I
  haven't heard about it yet" at least as often as it means "this is gone".
  Additive reconciliation is safe under partial knowledge; subtractive isn't.
- **Extract the decision from the I/O.** Not for purity — for the test that
  otherwise doesn't get written, in a file that had no tests at all.
