# The button that was there so you could not press it

Build a meal template. Tap **Add food**. The screen that opens is the ordinary
per-meal food search, and before you type anything it shows *Recently Added* —
the foods you actually eat, which is very often exactly the food you want in
the template. Tap one. You get the food detail screen, you set the portion,
and then you look at two buttons: a green **Add to log**, and below it a grey
**Add to Template** that does nothing when you press it.

The one you came here for is the dead one.

Nothing about that is a crash, a failed request, or a wrong number. Every
widget rendered, every value on the screen was correct, and the button you
could press did exactly what it said. The bug is that the screen had no idea
which of two jobs it was doing, and had been built so that being wrong about
that looked like a design choice.

Line references are to the commit that introduces this document.

---

## 1. One screen, two jobs, one boolean

`FoodDetailsScreen` serves two callers that want opposite things from it.

| Caller | Wants | Result of the screen |
| --- | --- | --- |
| The food log (`FoodAddScreen` from a meal) | The food written to today's diary | Inserts a `FoodItem`, calls `addFoodToMeal`, pops `true` |
| The template builder (`Create`/`EditMealTemplateScreen`) | The food *handed back*, nothing persisted | Pops a scaled `FoodItemModel`; the template screen owns the write |

Which job it does is decided by one constructor flag, `isTemplate`, threaded
down from `FoodAddScreen.isTemplate`, which the two template screens set to
`true` when they push it:

```dart
final result = await Navigator.push<FoodItemModel>(
  context,
  MaterialPageRoute(
    builder: (context) => FoodAddScreen(
      category: _selectedCategory,
      isTemplate: true,
    ),
  ),
);
```

That flag is the entire mechanism. It has a default (`false`), so forgetting it
is not a compile error, not a runtime error, and not visible in a diff review
unless you already know the flag exists. There is no type distinguishing "a
detail screen that logs" from "a detail screen that returns" — they are the
same class, told apart by a bool that defaults to the wrong answer for the
caller that is easiest to forget.

## 2. Where the flag fell out

`FoodAddScreen` pushes the detail screen from three places. Two of them passed
the flag:

- `_selectFoodItem`, the tap handler for a *search result* — passed
  `isTemplate: widget.isTemplate`, and on the way back translated a returned
  `FoodItemModel` into a `Navigator.pop` of its own, so the template screen
  received it.
- `BarcodeScannerView`, which is handed the flag when it is pushed and passes
  it on to the detail screen it opens; `_scanBarcode` similarly forwards a
  `FoodItemModel` result upward.

The third did not:

```dart
// _recentFoodTile — before
await Navigator.push<bool>(
  context,
  MaterialPageRoute(
    builder: (context) => FoodDetailsScreen(
      foodItem: FoodItemModel(...),
      category: widget.category,
      date: widget.date,          // no isTemplate
    ),
  ),
);
```

`_recentFoodTile` is the *Recently Added* list — the thing the screen shows
before a query is typed. It is not an edge case you have to go looking for; it
is the default state of the screen. So the two paths a user would describe as
"searching for a food" behaved differently from each other, and the difference
was invisible in the code because the broken one is defined by an *absent*
argument. You cannot grep for the parameter that isn't there.

Notice also the return type: `Navigator.push<bool>`. Even had the flag been
passed, the result would have been thrown away and the template screen would
have waited forever on a `FoodItemModel` that was popped one route too low.
Two independent omissions, both of which only show up by using the app.

The same gap existed in `_addCustomFood`, the **+** button that lets you type a
food's macros by hand. It inserted the food into the library — correct in both
modes, a custom food should exist in the catalogue — and then unconditionally
called `addFoodToMeal`. In template mode, defining a custom food while building
a template silently logged that food to *today's* diary and gave the template
nothing. That one is worse than a dead button: it writes something the user
never asked for, to a day they were not even looking at.

## 3. Why nothing caught it

This is the part worth keeping.

**The compiler cannot object to a default.** `isTemplate = false` exists so the
common caller stays terse. The cost of that convenience is that the parameter
becomes invisible at every call site that omits it, including the ones that
omit it by mistake. A named parameter with a default is, for review purposes,
not part of the call.

**The tests could not object either, and adding tests would not have helped**
unless someone had already thought of this exact path. Every reachable assertion
was true: the screen rendered, the macros scaled correctly, the log write
worked. The failure is *which* of two correct behaviours ran.

**And the UI was built to make the wrong answer look deliberate.** This is the
real lesson. The old `_buildAddToMealSection` always rendered both buttons and
disabled the inapplicable one:

```dart
FilledButton(
  style: FilledButton.styleFrom(
    disabledBackgroundColor: Colors.grey.shade300,
    disabledForegroundColor: Colors.grey.shade600,
  ),
  onPressed: !widget.isTemplate ? null : () { ... },
  child: Text(loc.addToTemplate),
),
```

A disabled control is a *statement to the user*: this action exists here, and
something about your current state is why you cannot take it. It is the right
pattern when the user can act on that information — an unsaved form, an empty
selection. It is exactly the wrong pattern for a mode flag the user cannot see,
cannot influence, and does not know exists.

The consequence is that a missing `isTemplate` produced a screen that looked
completely intentional. Grey button, plausible-looking pair of options, nothing
that reads as broken. The user's report was not "the app crashed" but "the
button is not clickable" — they had to interpret a UI that was actively
misleading them. Had the screen rendered only the action that applied, the same
bug would have surfaced as *the wrong single button*, which nobody mistakes for
a design decision.

> **The rule:** disable a control only for a condition the user can see and
> change. A control that is disabled because of internal mode should not be
> rendered at all — that way a wrong mode shows up as a wrong screen, not as a
> deliberate-looking dead end.

## 4. What changed

**`food_detail_view.dart`** — `_buildAddToMealSection` now renders exactly one
primary action, and the two branches moved into named builders,
`_buildAddToTemplateButton` and `_buildAddToLogButton`. The disabled-state
styling is gone: nothing on this screen is ever disabled now. Neither button's
logic changed.

**`food_add_screen.dart`** — `_recentFoodTile` passes `isTemplate` and forwards
a `FoodItemModel` result upward, matching `_selectFoodItem` exactly:

```dart
final result = await Navigator.push<dynamic>(
  context,
  MaterialPageRoute(
    builder: (context) => FoodDetailsScreen(
      ...,
      isTemplate: widget.isTemplate,
      date: widget.date,
    ),
  ),
);
if (widget.isTemplate && result is FoodItemModel && mounted) {
  Navigator.pop(context, result);
}
```

`_addCustomFood` returns the newly created food to the template instead of
logging it, and its confirm button reads *Add to Template* rather than *Add to
log* in that mode. The food is still inserted into the library first, so the
template's `foodId` points at a real row.

That leaves all four ways into a template — search result, recent food,
barcode, hand-entered custom food — going to the same place.

## 5. What is pinned

`test/food/food_detail_actions_test.dart` asserts the property, not the
implementation: in template mode exactly one action is on screen and it is
*Add to Template*; in log mode exactly one and it is *Add to log*; and template
mode pops a `FoodItemModel` scaled to the entered portion rather than writing
anything. A future caller that forgets the flag still will not fail this test —
no test can catch an omitted default — but a future refactor that brings back a
disabled twin button will.

The structural defence is the change in §4, not the test: with one button
rendered per mode, the failure mode of a forgotten flag is a screen that is
obviously wrong instead of a screen that is quietly wrong.

## 6. If you touch this again

- `FoodDetailsScreen` and `FoodAddScreen` are mode-flagged screens. Any new
  `Navigator.push` of either must pass `isTemplate` explicitly, and any push
  made in template mode must forward a `FoodItemModel` result up to the
  template screen — popping the detail route only gets the value one level.
- Nothing in template mode may write to the food *log*. Writing to the food
  *library* is fine and sometimes necessary; `addFoodToMeal` is the line.
- If you find yourself reaching for `onPressed: null` plus a grey style, check
  whether the user can tell why. If they cannot, render something else.
