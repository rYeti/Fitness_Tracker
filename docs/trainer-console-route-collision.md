# The Trainer Console routing bug: two consoles, one page identity

A trainer who left the console for "My Training," then reopened the console
from Settings, would get bounced straight back to the trainee app the moment
they tapped any section other than Dashboard — Messages, Builder, Nutrition,
Session Review all did it. This walks through why, because the mechanism is
in go_router's page-identity rules, not in any code that looks wrong on its
own.

---

## 1. Two ways to reach the same widget

The console is built from three pieces:

- `PostAuthHome` (`main.dart`) — the single place deciding where an
  authenticated user lands. It owns a `_showTraineeApp` flag: false shows
  `TrainerConsoleGate`, true shows `HomeScreen`. Set true by the console's own
  "My Training" exit action.
- `TrainerConsoleGate` — the role check. Reached two different ways: as the
  child `PostAuthHome` builds at `/` or `/console/:section`, and as its own
  pushed route, `/trainer-console`, from the "Trainer Console" tile in
  Settings and from a tapped chat notification.
- `TrainerConsoleHome` — the actual shell (sidebar/bottom-bar + the five
  `LazyIndexedStack` sections). `_selectRoute`, fired by tapping a section,
  does two things: `setState` the locally-held `_route` (which is what
  `LazyIndexedStack` actually reads), and call
  `GoRouter.maybeOf(context)?.go('/console/${segment}')` to keep the address
  bar in sync — added in `feat(routing): give the Trainer Console real URLs`
  so a section is bookmarkable and browser back works.

The bug is entirely in that second call, and only when the `TrainerConsoleHome`
doing the calling is the *pushed* one.

## 2. What `go()` actually does

`go_router`'s `go()` is declarative: it throws away the router's whole match
list and rebuilds it from scratch for the target location. That is
deliberate and documented — it's what makes browser back land somewhere
sane instead of unwinding an arbitrary stack of imperative pushes. The
consequence that matters here: **a page is identified by which route pattern
matched it, not by the concrete path that was last used to reach it.**
`/console/messages` and `/console/builder` are the same pattern
(`/console/:section`), so navigating between them reuses whatever page in the
Navigator's stack already answers to that pattern — it does not necessarily
mean "build fresh."

Trace the actual sequence that reproduces the report:

1. Trainer is at `/` (or `/console/dashboard`), `PostAuthHome` instance **A**,
   `_showTraineeApp = false`. Console showing.
2. Taps "My Training" → `_showTraineeApp` flips to `true` on instance **A**.
   The URL does not change — this is a pure local `setState`, by design (My
   Training is not a URL-addressable state). `HomeScreen` renders.
3. From Settings, taps "Trainer Console" → `context.push('/trainer-console')`.
   This *pushes* a second page onto the stack, on top of instance A. It
   builds a brand-new `TrainerConsoleGate` → `TrainerConsoleHome`, instance
   **B**, with no `PostAuthHome` involved at all. The stack is now
   `[A: '/', B: '/trainer-console']`. B renders the console correctly —
   nothing has gone wrong yet.
4. Trainer taps "Nutrition" inside B. `_selectRoute` updates B's local
   `_route` (harmless) and then calls `go('/console/nutrition')`.
5. `go()` rebuilds the match list for `/console/nutrition`, which matches the
   `/console/:section` route. Page identity for that route is keyed by the
   *pattern*, not by which concrete instance last held it — and instance
   **A** is sitting right there in the stack, built by `PostAuthHome`, whose
   effective route is functionally the same pattern family. go_router reuses
   **A** rather than building the fresh page B's push implied, and pops B off
   the stack in the process (its match list has no entry for
   `/trainer-console` any more).
6. The trainer is now looking at instance A again — the one whose
   `_showTraineeApp` is still `true` from step 2. `PostAuthHome._home()`
   returns `HomeScreen()`. The console the trainer just opened, and the
   section they just tapped, are both gone; they're back in "My Training."

Nothing here is a compiler-catchable mistake. Both call sites type-check;
`GoRouter.go` returns `void` either way. The failure only exists as *which
already-alive object* a page identity match happens to land on, and that
depends on what else happens to be in the navigation stack at the moment —
which is exactly the kind of state a unit test that mounts `TrainerConsoleHome`
directly (as `shell_test.dart` does, with no `GoRouter` in the tree at all)
can never see. `GoRouter.maybeOf(context)` is `null` there, so `_selectRoute`'s
`go()` call was always a no-op under test.

## 3. The fix: only one console instance is allowed to own the URL

The bookmarkable-URL feature is correct and worth keeping for the console
`PostAuthHome` actually mounts. It was never meant to apply to the *second*,
pushed console reachable from Settings or a notification tap — that one was
deliberately built to rely on the back gesture instead of an exit affordance
(see the comment on `TrainerConsoleShell.onExitConsole`). It has no business
touching the router's location at all, and doing so is what let it collide
with the instance underneath it.

`TrainerConsoleHome` now takes a `syncUrl` flag (default `false`).
`_selectRoute` only calls `go()` when it's set. `PostAuthHome` is the only
caller that passes `syncUrl: true`, because it's the only instance that is
*itself* the router's current page for `/` or `/console/:section` — every
other entry point (`/trainer-console`, the notification-tap
`TrainerConsoleGate` in `main.dart`) leaves it `false`, so switching sections
there is purely local state, exactly like it was before URLs existed for the
console.

The general lesson: a `GoRouter.go()` call embedded inside a widget that can
be mounted from more than one place in the route tree is only safe if that
widget can tell whether *it* is the thing currently occupying the location it
is about to rewrite. Threading that answer down as an explicit parameter,
rather than assuming `context` always means "the page the user thinks they're
on," is the only way `go()`'s pattern-based page reuse and a pushed
"second instance" of the same widget can coexist.
