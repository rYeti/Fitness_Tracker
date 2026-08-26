# The chrome nobody tests

Three screenshots arrived with the same complaint attached: the app looks
inconsistent. One showed the trainee dashboard with the greeting's first word
hidden behind an avatar. One showed the Trainer Console with a band of dead
space under its top bar. One showed Settings, with its bottom navigation bar
circled in red and the last form field pressed up against it.

They look like three unrelated cosmetic nits. They are four bugs, and the
interesting thing about all four is that no compiler, no analyzer and no
green test suite could have found any of them — 366 tests were passing while
every one of them was on screen. This document is about why that is, because
the shape of the mistake matters more than the four instances of it.

## What was actually wrong

### 1. A SafeArea that defeats itself

Eight screens looked like this:

```dart
return SafeArea(
  child: Scaffold(
    appBar: AppBar(title: Text(l10n.settings)),
    body: ...,
  ),
);
```

Every part of that reads as careful. It is exactly backwards.

`Scaffold` already handles insets, and it handles them better than a caller
can, because it knows what it is holding: given an `appBar` it removes the top
padding from `body` and hands the inset to the bar, which grows by that much
and paints its own background behind the status bar. Given a
`bottomNavigationBar` it does the same at the other end.

`SafeArea` works by *consuming* an inset — it applies the padding itself and
then removes it from the `MediaQuery` it passes down. So wrapping the
`Scaffold` from outside hands the Scaffold a box that no longer knows a status
bar exists. The bar renders at its bare `kToolbarHeight`, starting below the
status bar rather than behind it, and the strip above it shows the raw page
background.

That is the entire content of screenshot three. Settings' charcoal bar begins
below the clock; the Dashboard's extends up behind it. Same app, same theme,
same bar widget, two different results, because one of them was wrapped and
the other was not.

| | app bar top | app bar height | status strip |
|---|---:|---:|---|
| `Scaffold(appBar: …)` | 0 | `kToolbarHeight + inset` | painted charcoal |
| `SafeArea(child: Scaffold(appBar: …))` | inset | `kToolbarHeight` | page background |

### 2. A SafeArea paid twice

The Trainer Console had the mirror-image version. Its mobile shell built the
bar as the first child of a `Column`:

```dart
Scaffold(
  body: Column(
    children: [
      if (onExitConsole != null) _ExitBar(onExitConsole: onExitConsole!),
      Expanded(child: child),
    ],
  ),
  bottomNavigationBar: _BottomNav(...),
)
```

`_ExitBar` wrapped itself in a `SafeArea`, correctly, so it cleared the status
bar. But `SafeArea` removes the inset **for its own subtree**, and
`Expanded(child: child)` is a *sibling*, not a descendant. It kept the full
`MediaQuery` padding. And all five console sections wrap their bodies in a
`SafeArea` of their own — correctly, because on desktop they sit beside a
sidebar with no bar above them to pay it.

So on mobile the status-bar inset was paid twice: once by the bar, once again
by whichever section was visible. A ~40px band of nothing, under the bar, on
every tab.

The conditional is why it only reproduced sometimes. `PostAuthHome` passes a
non-null `onExitConsole`, so a trainer landing in the console from sign-in
always saw it; reaching the console from Settings pushes it as a route,
`onExitConsole` is null, no `_ExitBar` is built, and the gap vanishes. "It
happens on the first start up" was a precise bug report.

### 3. A Stack over text

The dashboard greeting card:

```dart
Stack(
  children: [
    Container(margin: const EdgeInsets.only(top: 12), ...),  // the card
    Positioned(left: 24, top: 0, child: /* 54px avatar */),
  ],
)
```

The card starts 12px down. Inside it, 16px of padding and a 12px `SizedBox`
put the greeting text at y=40. The avatar spans y=0 to y=54 and x=24 to x=78.
The text starts at x=16.

They overlap. `Stack` did precisely what it is for.

### 4. Two clients, two bottom bars

Commit `5c0a638` moved the Trainer Console to Material 3's `NavigationBar` and
left the trainee app on the Material 2 `BottomNavigationBar`. Neither is
broken. They just answer the same gesture differently — pill indicator versus
coloured icon, selected-only label versus five permanent ones, outlined-then-
filled icons versus one filled set — and a user who switches between the two
surfaces sees one app that cannot make up its mind.

## Why none of this was caught

Each of the four is invisible to every automatic check the project runs, and
for a *different* reason. That is the part worth internalising.

**The type system has nothing to check.** `SafeArea(child: Scaffold(...))` is
well-typed. So is `Scaffold(body: SafeArea(...))`. So is a `Positioned` inside
a `Stack`. There is no ill-formed program here to reject.

**The analyzer has no rule.** These are not unused variables or missing
awaits. Every lint in the project passes on all four.

**Widget tests assert presence, and everything was present.** A test that
pumps the console and finds every nav label passes identically whether the
inset is paid once or twice. A test that finds the greeting text passes
whether or not an avatar is drawn on top of it. Overlap and offset are
*numbers*, and no test was asking for a number.

**And the fourth is not a defect at all.** Two different bottom bars is a
consistency failure. There is no assertion that could fail, because neither
half is wrong on its own. It can only be caught by something that holds both
at once — which is the same reason `contrast_test.dart` exists in this
codebase, and says so in its own header: contrast is a property of a *pair*,
and nothing held both halves.

So the general rule:

> A defect that only manifests as a coordinate, or as a difference between two
> places that are each individually fine, will not be found by anything that
> checks one place at a time. It has to be measured, or made structurally
> impossible.

## What was done, and why that shape

### Made impossible, where possible

The greeting card's avatar is now a `Row`. This is not "the same layout with
better numbers" — a `Row` cannot place two children on top of each other. The
class of bug is gone rather than the instance, which is worth more than a
test would be.

The same reasoning drove `ForgeAppBar` and `ForgeNavBar`. The 26 app bars
across the app were each individually deciding a background colour, an
elevation and a title size, and getting three different answers to the last
one — 17px on four screens, 20px on eleven, and a hand-built wordmark on six,
five of which hardcoded `#FF6B3E` instead of using the token that exists for
it. `ForgeAppBar` sets *none* of those. The theme already declares all three
in both light and dark; a bar that declares nothing cannot disagree with it.

That is the general shape:

> Chrome assembled per screen drifts. Chrome assembled once cannot.

### Measured, where not

Two things could not be made structurally impossible, so they are measured.

The console's inset is pinned by comparing two pumps of the same screen, one
with a 0px status bar and one with 40px:

```dart
final withoutStatusBar = await contentOffsetBelowBar(0);
final withStatusBar = await contentOffsetBelowBar(40);
expect(withStatusBar, closeTo(withoutStatusBar, 0.5));
```

A difference, not an absolute. The first attempt asserted the offset was 16
and got 23.5, because the heading shares a `Row` with a taller seat chip and
its box is centred within it — 7.5px of text metrics that have nothing to do
with insets. Asserting the *difference* cancels everything that is not the
inset. Run against the old `Column` layout it reads 63.5 against 23.5, which
is the 40px, exactly.

The `SafeArea`-wrapping-`Scaffold` rule is checked over the source, not the
widget tree:

```dart
final pattern = RegExp(r'SafeArea\(\s*(?://[^\n]*\n\s*)*child:\s*Scaffold\(');
```

That is an unusual thing to put in a test suite, and it is the right tool
here. The failure has no runtime signature to assert on without already
knowing which screen to suspect and what its bar's y-offset should be — and if
you knew that, you would have found the bug. The pattern catches the ninth
occurrence before anyone renders it.

## The half of an inset audit that is easy to skip

Removing wrong `SafeArea`s is the visible half. The other half is adding the
missing ones, and it is easy to skip because nothing points at it — there is
no offending code to grep for, only an absence.

Three were found by asking, for each screen, *which edge does this body
actually reach?*

- The rest-timer sheet was the one modal bottom sheet in the app with no
  `SafeArea`. On a phone using gesture navigation its controls sat under the
  home indicator.
- Settings' scroll view had 8px of bottom padding, so the last field ended
  flush against the navigation bar and read as clipped by it. This is the
  circled part of screenshot three, and it is not an inset bug at all — the
  `Scaffold` sized the body correctly. It is a spacing bug that *looks* like
  one, which is its own small lesson: not everything touching a bar is an
  inset problem.
- The dashboard's scroll view ended 16px from the bottom with a `SpeedDial`
  floating over it, so the last card sat under the FAB. A FAB floats over the
  body by definition; it never displaces it, so the body has to make room.

## A load failure that renders as an empty state

One more thing fell out of the same pass, and it is the most serious bug in
it.

`WorkoutProvider` loaded like this:

```dart
try {
  _plans = completePlans;
} finally {
  _loading = false;
  notifyListeners();
}
```

A `finally` restores the flag and lets the exception continue. So a throw left
`plans` empty, `loading` false, and nothing anywhere recording that the load
had failed. The list view checked `plans.isEmpty` and rendered its empty
state: *"No workouts found"*, with a **Create your first workout** button.

A trainee whose database read failed was told their training history did not
exist.

Both paths end in an empty list, and an empty list is a perfectly good value —
so there was nothing for a type to catch, and a test asserting "an empty load
shows the empty state" would have passed while describing the bug. The
distinction has to be *carried*, deliberately, which is what the new `error`
field does. This is the identical defect commit `7ff1dcd` fixed for
`WeightProvider` in the same app, two tabs over; the fact that it recurred is
the argument for writing it down rather than just fixing it.

`WorkoutProvider` now takes its two DAOs as constructor parameters, still
defaulting to the registered database. A failure state no test can reach is a
failure state nobody can trust.

Progress had the softer version: a `SnackBar`, gone in four seconds, leaving a
chart that reads as "you have logged nothing".

The remaining `SnackBar`s were left alone on purpose. A save that fails is not
a load that fails — the form is still on screen and the button is still there,
so the retry already exists and an inline error strip would only be in the
way. "Route every error through `ErrorStateView`" would have been the tidier
rule and the worse one.

## What to take from this

1. **Prefer a layout that cannot express the bug** over one that expresses it
   correctly today. A `Row` beats a well-tuned `Stack`.
2. **Let the framework own the insets it already understands.** `Scaffold`
   knows what an `appBar` and a `bottomNavigationBar` are; a `SafeArea` wrapped
   around it knows nothing and takes the inset away.
3. **An inset audit has two halves**, and the one that adds is the one that
   gets skipped, because absence does not grep.
4. **Consistency defects need a test that holds both halves.** One bar, one
   theme, one token — or a test that compares the two, like the contrast suite
   already does.
5. **`finally` is not `catch`.** It restores your invariants and drops your
   reason. If the caller has to tell a failure apart from an empty result,
   something has to carry that, and "the list is empty" never will.
