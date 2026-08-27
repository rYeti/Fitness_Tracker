# Frontend design review: two codebases wearing one brand

A full pass over `fittnes_tracker/lib` against the design tokens and UI/UX
conventions in `CLAUDE.md`. Written to be read on its own.

Line references are to the commit that introduces this document.

---

## The short version

The frontend is not one codebase with uneven quality. It is **two design
systems that happen to share a colour file**, plus **one class of defect that
both inherit from the tokens themselves**.

| | Trainer Console | Trainee app |
|---|---|---|
| Shared primitives | `ConsoleCard`, `ConsoleSkeleton`, `ConsoleErrorState`, `ConsoleEmptyState`, `StatusBadge`, `StatTile`, `ClientAvatar` | none |
| Loading state | skeletons in 8 screens | 45 bare `CircularProgressIndicator`s |
| Error state | `ConsoleErrorState` with retry | 0 shared error widgets, 0 `onRetry` |
| Accessibility labels | 39 across 15 tappables | 7 across 20 (food), 1 across 4 (weight), 0 (settings, onboarding) |
| Colour source | `ForgeColors` | `Colors.red` / `.green` / `.orange` × 68 |
| Breakpoints | `> 1024` in 8 screens | none |
| Spacing scale | drifted (see §3) | drifted (see §3) |

The console is architecturally right and dimensionally sloppy. The trainee app
is dimensionally no worse but has no design system at all. And underneath both,
the brand palette fails WCAG AA in the exact place `CLAUDE.md` predicted it
would.

---

## 1. The primary button fails contrast, and always has

`CLAUDE.md` says, under Accessibility: *"verify Forge Orange on white/charcoal
combinations specifically, since brand orange on light backgrounds is a common
contrast failure point."* It is. Measured:

| Pair | Where | Ratio | AA body (4.5) | AA large/icon (3.0) |
|---|---|---:|---|---|
| `#FFFFFF` on `#FF6B3E` | **every ElevatedButton and FAB** | **2.83** | FAIL | FAIL |
| `#FF6B3E` on `#FFFFFF` | orange text/icons on cards | **2.83** | FAIL | FAIL |
| `#FF6B3E` on `#F5F5F5` | orange on light page bg | **2.59** | FAIL | FAIL |
| `#FF6B3E` on `#1E1E1E` | dark surface | 5.89 | pass | pass |
| `#FF6B3E` on `#2C2C2C` | dark card | 4.94 | pass | pass |
| `#FF6B3E` on `#333333` | on the charcoal app bar | 4.47 | FAIL | pass |

This is not a screen-level mistake. It is baked into
`theme_provider.dart:100` (`elevatedButtonTheme`) and `:135`
(`floatingActionButtonTheme`), so **every primary action in both surfaces
inherits it**. White-on-orange at 2.83:1 does not clear even the 3:1 large-text
bar. The dark theme is fine; the light theme is the whole problem.

Why no test caught it: contrast is a property of a *pair*, and nothing in the
codebase ever holds both halves at once. The theme declares a background, the
widget declares a foreground, and Flutter composites them at paint time. There
is no type that says "these two must be 4.5:1 apart."

### The fix that keeps the brand

Do not change `ForgeColors.forgeOrange` — it is correct on dark, it is the
brand, and `design_tokens.dart` exists specifically to stop it drifting. Add a
*paired* token instead:

```dart
/// Forge Orange is a 2.83:1 pair with white and cannot carry text or an
/// icon on a light surface. This is the same hue darkened until white
/// clears AA on it (4.77:1) and it clears AA as text on #F5F5F5 (4.38:1).
/// Dark surfaces keep the pure brand orange.
static const forgeOrangeOnLight = Color(0xFFBF502E);
```

Then in the light theme only, `ElevatedButton`/FAB background and any
orange-on-light foreground use `forgeOrangeOnLight`. The alternative —
`#333333` on `#FF6B3E`, at 4.47:1 — still misses AA and loses the white-on-
orange look, so darkening the orange is the cheaper trade.

## 2. Status tones fail the same way, and `StatusBadge` half-knows it

`StatusBadge` (`status_badge.dart`) is one of the better widgets in the repo:
it pairs colour with an icon *and* a label, it wraps itself in `Semantics`, and
it already noticed that flat tone colours read badly on `#121212` — so dark mode
gets `Color.lerp(color, Colors.white, 0.35)` and a stronger background wash.

That instinct was right and applied in exactly one direction. Light mode paints
the raw tone on a 14% tint of itself, at 11px:

| Tone | Text on its own tint (light) | Needs |
|---|---:|---|
| ok `#43A047` on `#E5F2E5` | **2.86** | 4.5 |
| warn `#FFA000` on `#FFF2DB` | **1.85** | 4.5 |
| bad `#E53935` on `#FBE3E3` | **3.46** | 4.5 |

Amber on its own tint at 1.85:1 is close to invisible. The symmetric fix is the
lerp the widget already performs, pointed the other way for light:

```dart
final foreground = isDark
    ? Color.lerp(color, Colors.white, 0.35)!
    : Color.lerp(color, Colors.black, tone == StatusTone.warn ? 0.40 : 0.30)!;
```

That yields ok 5.21:1, warn 4.71:1, bad 5.00:1 — all clear. Warn needs the
deeper lerp because amber starts far brighter than the other two.

The macro colours have the same shape of problem when used as *text* on white
(protein 4.23, carbs 3.68, fat 3.30) but are fine as chart fills and progress
segments, which is mostly how they are used. Worth an audit rather than a
blanket change: `CLAUDE.md` fixes those three hues everywhere, so a
`macroOnLight` variant is the honest route if any of them carries a number.

## 3. Input borders are invisible, in both themes

| Border | Against | Ratio | WCAG 1.4.11 needs |
|---|---|---:|---|
| `#E0E0E0` | `#FFFFFF` | **1.32** | 3.0 |
| `#404040` | `#2C2C2C` | **1.35** | 3.0 |

`theme_provider.dart:141` and `:275`. Non-text UI components that convey state —
and an input's border is the only thing marking where the field *is* — need
3:1. Both are roughly a quarter of that. `#949494` on white (3.03) and
`#7A7A7A` on the dark card (3.25) are the minimum viable replacements.

This one is easy to dismiss because the fields are `filled: true`, so the fill
does some of the work. It doesn't: the light fill is `Colors.white` on a
`#F5F5F5` page — a 1.05:1 pair. In light mode a text field is currently
delimited by essentially nothing.

## 4. The spacing scale drifted, and the console drifted hardest

`CLAUDE.md`: *"Base unit: 4px grid, spacing scale 4 / 8 / 12 / 16 / 24 / 32 /
48px. No arbitrary one-off values (e.g. 13px, 21px)."*

There are ~176 off-grid spacing values. The distribution is telling: `14` (44
uses), `6` (40), `10` (40), `2` (20), `18`, `13`, `11`, `9`, `7`. And the worst
offenders are in the Trainer Console, not the trainee app:

```
session_review_screen.dart:333   EdgeInsets.fromLTRB(16, 14, 16, 11)
session_review_screen.dart:407   EdgeInsets.fromLTRB(11, 12, 14, 12)
session_review_screen.dart:848   EdgeInsets.symmetric(horizontal: 11, vertical: 7)
trainer_console_shell.dart:236   SizedBox(width: 13)
console_widgets.dart:120         EdgeInsets.only(bottom: 11)
conversation_row.dart:50         EdgeInsets.fromLTRB(13, 12, 16, 12)
```

`fromLTRB(16, 14, 16, 11)` is three different scales in one call. The same
drift hit type and icons: 53 font sizes below 12px including `9.5`, `10.5`,
`11.5`; icon sizes of `13`, `19`, `21`, `22` sitting alongside the 16/20/24 the
rest of the app uses.

The cause is legible from the pattern: these screens were built to match
`Trainer Console.dc.html` closely, and the mockup's rendered pixel values were
transcribed rather than snapped to the nearest scale step. `CLAUDE.md` calls the
mockup *"authoritative on layout, spacing, states, and interaction intent — but
adapt freely… It is a reference, not a pixel-exact spec."* Pixel-matching a
reference is how you end up with an 11px bottom pad.

Nothing here is user-visible in isolation. Collectively it is exactly the
"unprofessional but you can't say why" symptom — vertical rhythm that never
quite lands.

## 5. Reduced motion is honoured in exactly one place

There are 10 animation sites (`AnimatedContainer`, `AnimatedSize`,
`AnimationController`, `TweenAnimationBuilder`, `AnimatedBuilder`) across
`barcode_scanner_view`, `food_detail_view`, `scheduled_workouts_view`,
`create_view`, `profile_setup_screen`, `paywall_screen`.

Exactly one place in the entire codebase reads the setting:

```
meal_detail_sheet.dart:48    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
```

`CLAUDE.md` lists reduced-motion under conventions, and the accessibility
section is marked *"non-negotiable, not a later pass."* The
`barcode_scanner_view` scan line is the sharpest case — a continuously looping
`AnimationController` is precisely what the OS setting exists to stop, and it
sits in front of a user trying to aim a camera.

The pattern `meal_detail_sheet` already established is the one to lift into a
helper — something like a `ForgeMotion.duration(context, 200)` returning
`Duration.zero` when `MediaQuery.disableAnimationsOf(context)` is true — so the
next animation gets it for free rather than by remembering.

Two durations also exceed the ≤300ms chrome rule: `active_workout_view.dart:123`
at 800ms and `create_view.dart:395` at 500ms.

## 6. The trainee app has no design system

This is the largest finding and the least visible in any single file.

**No shared states.** The console has `ConsoleSkeleton`, `ConsoleErrorState`,
`ConsoleEmptyState` (`console_widgets.dart:95`, `:152`, `:200`). The trainee app
has none of the three. Its loading state is 45 bare spinners — `settings_screen`
alone has 6 — against a convention requiring *"skeleton/shimmer placeholders
matching the final layout's shape, not a bare spinner, for anything above ~300ms
of expected latency."* Its error state is, across Dashboard, Weight, Food, Gym,
Settings and Premium, **zero** `onRetry` affordances. Empty states are the one
bright spot: the copy exists and reads correctly ("No weight records yet", "No
workouts in this plan yet").

**No colour discipline.** 68 raw palette references — `Colors.red` ×27,
`Colors.green` ×20, `Colors.orange` ×12 — concentrated in
`progress_dashboard_view` (13), `edit_view` (13), `food_detail_view` (10),
`scheduled_workouts_view` (8). Every one is semantically a status tone that
should be `ForgeColors.statusOk/Warn/Bad` via `StatusBadge`. `Colors.red` is
`#F44336`; `statusBad` is `#E53935`. They are close enough that nobody notices
and different enough that the app has two reds.

**Duplicated primitives.** `ClientAvatar` exists
(`client_avatar.dart`) and is used only inside the console; the trainee app
re-implements initials-in-a-circle inline via `CircleAvatar` in 6 files.
`LinearProgressIndicator` appears inline in 7 files with no shared `ProgressBar`,
against *"One shared widget per repeated pattern… never re-implement the same
visual pattern inline in multiple screens."* Eight status-coloured `Container`s
sit outside `StatusBadge`.

**Thin accessibility.** `semanticLabel` appears **zero** times repo-wide. Of 83
`IconButton`s, 39 carry a `tooltip` — so roughly half the icon buttons announce
nothing. By area, labels-per-tappable: console 39/15, chat 9/5, gym 31/64, food
7/20, weight 1/4, settings 0/2, onboarding 0/1.

**No breakpoints.** `1024` is the only breakpoint literal in the codebase, in 8
console files. The `<600px` mobile breakpoint the conventions define is used
nowhere, and the literal itself is copy-pasted 8 times rather than living beside
`ForgeColors`.

## 7. What is genuinely good

Worth stating plainly, because a review that only lists defects misrepresents
the codebase:

- **`design_tokens.dart` earns its keep.** Only 25 hardcoded `Color(0x…)`
  literals survive outside it and the theme — for a 196-file Flutter app that is
  unusually clean, and the doc comment explaining *why* it exists (the
  `#FF6B35`/`#FF6B3E` typo) is the reason it stayed clean.
- **Localisation is near-total.** 1,427 `AppLocalizations`/`l10n.` references;
  only `gym_tracking_screen.dart` and `onboarding_screen.dart` have none.
- **`StatusBadge` and `StatTile` are modelled correctly** — tone enum rather
  than per-screen colour, icon *and* label so colour is never the only signal,
  `compact` documented as still safe because the label carries the meaning.
- **The console's state handling is complete** — every data-bound screen has a
  designed loading, empty and error path, which is the convention most projects
  skip.
- **Destructive actions are confirmed** — 31 `AlertDialog`s against 32
  delete/remove sites.

---

## The general lesson

Two failure shapes here outlive this particular audit.

**A design token is not a design decision.** `ForgeColors.forgeOrange` is a
correct, well-guarded, single-source-of-truth constant that produces an
inaccessible button, because a colour is only meaningful as half of a pair and
the token records only one half. Tokens that will be used as foregrounds need
their approved backgrounds recorded with them — `forgeOrange` and
`forgeOrangeOnLight` are the same brand decision at two contrast budgets, and
the file is the only place that can say so. Nothing downstream will.

**A convention document does not propagate backwards.** Every rule in
`CLAUDE.md`'s UI/UX section is followed by the Trainer Console and ignored by
the trainee app, because the conventions were written when the console was
written. The line *"and should be extended to the trainee-facing app where
reasonable"* is doing an enormous amount of unbudgeted work. The extraction that
actually closes the gap is small — lift `ConsoleSkeleton`/`ConsoleErrorState`/
`ConsoleEmptyState`/`ClientAvatar`/a `ProgressBar` out of
`feature/trainer_console/presentation/widgets/` into `core/widgets/`, drop the
`Console` prefix, and the trainee app inherits four screen states and a colour
discipline it currently has to reinvent per screen.

Suggested order, highest user impact first:

1. **Contrast** (§1–§3) — token-level, ~30 lines, fixes every screen at once.
2. **Reduced motion** (§5) — one helper plus 10 call sites.
3. **Promote the console widgets to `core/widgets/`** (§6) — unlocks 4–8.
4. **Replace the 68 raw palette colours** with `StatusBadge`/`ForgeColors`.
5. **Tooltips on the 44 unlabelled `IconButton`s**, weight/settings/onboarding first.
6. **A `Breakpoints` class** beside `ForgeColors`; add the `<600` case.
7. **Skeletons and retry** for the trainee app's heaviest reads.
8. **Snap the spacing/type/icon scales** (§4) — lowest risk, do it last.

---

## 8. What the rendered app showed that the source did not

Everything above came from reading source and computing. To check it against
reality, the web bundle was built (`flutter build web --release
--no-web-resources-cdn`) and driven with Playwright through the existing
`e2e/` harness at 1440×900, 800×1000 and 390×844.

**What this method can and cannot do.** Flutter web paints the whole app into
a canvas. There is no DOM, no computed styles, no element boxes — so Playwright
cannot read a contrast ratio, a padding value or a font size. What it *can* do
is produce the real rendered pixels, which can then be sampled directly, and
enumerate the accessibility tree. Both turned out to be worth doing. Nobody
should mistake a green Playwright run on this app for a design sign-off.

**Coverage caveat:** no backend was running, so only the three pre-auth screens
(Login, Register, Forgot Password) are reachable. The Trainer Console, the
dashboard and the nutrition screens sit behind auth and are not covered here.

### 8a. The contrast failures are real, measured off the pixels

Sampling the rendered PNG rather than the token file, taking the darkest pixel
in each glyph region as the true colour core (thin text is antialiased, so a
naive sample reads a blend):

| Element | Glyph | On | Ratio | |
|---|---|---|---:|---|
| Login button label | `#FFFFFF` | `#FF6B3E` | **2.83** | FAIL |
| "Forgot password?" | `#FF6B3E` | `#FFFFFF` | **2.83** | FAIL |
| "Register" link | `#FF6B3E` | `#FFFFFF` | **2.83** | FAIL |
| Account-type selected segment | `#FFFFFF` | `#FF6B3E` | **2.83** | FAIL |
| Username placeholder | `#666666` | `#F1F1F1` | 5.08 | pass |
| Body copy | `#333333` | `#FFFFFF` | 12.63 | pass |
| Character counters | `#353535` | `#FFFFFF` | 12.27 | pass |

The button fill measured exactly `#FF6B3E` — `ForgeColors.forgeOrange`, straight
through the theme to the screen. §1's arithmetic and the rendered pixels agree
to two decimal places, at four independent sites.

Two predictions were **wrong** and are corrected here: the placeholder text and
the character counters both clear AA comfortably. §3's concern about the input
*fill* being near-invisible does not extend to the text inside it.

The input border did verify: measured `#E7E7E7` against `#FFFFFF`, ≈1.24:1.
In the render there is no perceptible box around a text field at all — only a
fill.

### 8b. The login and register screens have no desktop layout

This is the finding no grep would ever have produced, and it is arguably worse
than the contrast bugs.

At 1440px, the Login button spans **x=28…1411 — 1,384px, 96% of the viewport**.
The username field is 1,382px. On Register, every field including *Email* is
1,382px wide, 95% of the screen.

There is no `maxWidth` container, no centred column, nothing. These screens are
a mobile layout stretched to fill a desktop monitor. At 390px they look correct
and considered; at 1440px they are a single column of full-bleed inputs with a
large empty region below.

That matters more than it would in most apps, because `CLAUDE.md` makes the
browser the trainer's primary surface — *"on web… straight to login"*. The
first thing a trainer sees on their workstation is a phone form scaled up.

This also explains the §6 breakpoint finding from the other direction: `1024`
appears only inside the Trainer Console. The auth screens, which are the web
entry point, have no breakpoint at all.

### 8c. Unlabelled controls, confirmed by enumeration

Per `e2e/README.md`, *"an element with no semantic label… is invisible to this
suite"* — the same tree a screen reader consumes. Enumerating it:

| Screen | Controls with no accessible name |
|---|---|
| Login | 1 button (password visibility toggle) + 1 `img` |
| Register | 2 buttons (both password toggles) |
| Forgot Password | 0 |

A password visibility toggle that announces as "button" is precisely the defect
`semanticLabel` exists to prevent, and it is repeated three times across two
screens. Forgot Password having none shows the codebase is capable of it — the
gap is inconsistency, not incapability.

### 8d. Two documented constraints, still true

Both `CLAUDE.md` notes reproduced exactly:

- **WASM stays unavailable.** The build's dry run reports
  `flutter_secure_storage_web… dart:html unsupported`. The floor holds; don't
  add `--wasm`.
- **`purchases_flutter` fails on web at runtime.** The console shows
  `Failed to fetch dynamically imported module:
  cdn.jsdelivr.net/npm/@revenuecat/purchases-js-hybrid-mappings`. Non-fatal —
  the app boots and login renders — but paywall paths remain unusable in a
  browser.

Neither is a regression. Both are documented behaviour confirming the docs are
accurate, which is worth recording.

### 8e. One piece of doc drift

`e2e/playwright.config.ts` explains its 390px project with *"The console
collapses to a single pane below 600px."* The shell actually switches at
`width > 1024` (`trainer_console_shell.dart:77`). The test is unaffected — 390
is below both — but the stated reason is wrong, and anyone adding a tablet
project would be misled. Worth correcting when §6's `Breakpoints` class lands.

### The lesson from doing both

The two methods found disjoint sets of defects. Source reading found every
contrast failure and could quantify each one exactly; it could not see that a
form is 1,384px wide. Rendering found the layout defect immediately and would
never have found the `#E0E0E0` border ratio, because a human eye reads "there's
no border there" and moves on without a number.

The pairing matters more than either half: the render says *where* to look, the
source says *what the value is and where it comes from*. A design review that
runs only one of them will confidently miss half its findings — and the half it
misses is invisible precisely because that method cannot see it.

---

## 9. Running the API: what the authenticated screens showed

§8 could only reach Login, Register and Forgot Password, because no backend
was running. This section covers the rest. The ASP.NET API was brought up
against a local PostgreSQL, seeded with a realistic roster through its own
endpoints, and every reachable screen was driven with Playwright at 1440 /
800 / 390 in both themes.

**Nothing was created against, and no traffic sent to, the production API.**
`auth_provider.dart:244` hardcodes the Cloud Run URL, so the review build was
pointed at `localhost` and the constant reverted afterwards.

### 9a. First, a correction

§8c reported that the Trainer Console's mobile bottom navigation exposed
unnamed controls. **That was wrong, and the fault was in the probe, not the
app.** Dumping the tree properly at 800px:

```
role="tablist"
role="tab" label="Home"       role="tab" label="Chat"
role="tab" label="Workouts"   role="tab" label="Nutrition"
role="tab" label="Review"
```

The earlier query selected `flt-semantics[role="button"]`; tabs are not
buttons, so the selector excluded exactly the elements it claimed were
missing. A screen-reader user navigates the console on mobile without
difficulty. The lesson is worth keeping: **an accessibility check that filters
by role can manufacture the defect it reports.**

### 9b. The trainer and the client see different calorie targets

The sharpest defect found, and it needed both surfaces rendered against one
account to see at all.

On the same day, for the same person:

| Surface | Shows |
|---|---|
| Trainee app, Food screen | **1733 / 2000 kcal** |
| Trainer Console, Nutrition | **Target 0 kcal** |

Both defaults agree that a calorie goal starts at 2000 — `UserSettings.cs:13`
(`DailyCalorieGoal { get; set; } = 2000`) server-side, and
`food_tables.dart:35` (`withDefault(const Constant(2000))`) in the client's
local Drift table. But the console's read does not:

```csharp
// TrainerConsoleService.cs:482
var calorieGoal = settings?.DailyCalorieGoal ?? 0;
```

For a client who has never opened settings, no `UserSettings` row exists yet,
and the `?? 0` substitutes a value that contradicts both defaults. The
consequences run further than one number: the calorie ring renders with **no
filled arc at all** (sampled: only `#EAEAEA` track and `#333333` text — zero
brand-orange pixels), and the "Calories vs. target" chart classifies every day
against a target of zero.

Neither side is wrong when read alone, which is why no test catches it. The
defect is the *disagreement*, and a disagreement has no single home in the
code. The one-line fix is `?? 2000`; the durable fix is one shared constant,
since the value is currently written out in three places.

### 9c. "Avg adherence" means two different things, eight pixels apart

The dashboard shows a KPI tile reading **Avg adherence 100%** directly above
client cards reading **92%**, **80%** and **No data**.

Both numbers are computed correctly, and the code says why:

| Figure | Window | Source |
|---|---|---|
| Client card adherence | trailing **28 days** | `TrainerConsoleService.cs:67` |
| KPI "Avg adherence" | **current week only** | `TrainerConsoleService.cs:101–104` |

The comments are thoughtful — a Monday-morning roster would otherwise show
every client at 0%, and a client with an empty week shouldn't drag the average
down. Both decisions are right. **The defect is presentational:** two windows
share one word, sit adjacent, and nothing on screen distinguishes them. A
trainer reads an average of 100% over clients scoring 92 and 80.

The fix is copy, not logic — name the window on both ("Avg adherence, this
week" / "28-day adherence"). Session Review compounds it with a third count:
"10 sessions, 9 completed, 1 missed" for a client the roster scored 11/12.

### 9d. The accessibility gap, finally measured

§6 inferred this from grep counts. Rendering settles it. Unnamed interactive
controls in the accessibility tree, per screen:

| Surface | Screen | Unnamed controls |
|---|---|---:|
| **Console** | Dashboard, Messages, Builder, Nutrition, Session Review | **0** each |
| Trainee | Food | **20** |
| Trainee | Gym | 2 |
| Trainee | Dashboard | 1 |
| Trainee | Progress | 1 |
| Trainee | Profile | 0 |

The 20 on Food are, by position: two app-bar icons, one `+` per meal category,
and a **pencil and a trash icon on every food row**. A screen-reader user
hears "button" for every edit and every *delete* — an unlabelled destructive
action, repeated once per food logged.

What makes it a near-miss rather than neglect: the food rows themselves are
labelled beautifully — `"Greek Yoghurt 0% / 59 kcal · Protein: 10g · Carbs: 4g
· Fat: 0g"`. Someone thought carefully about the content and never came back
for the icons.

The same controls fail two more rules at once: they measure **40×40** against
the 44×44 minimum, and the pencil/trash pair sits at x=1328 and x=1368 —
**adjacent with no gap**, against the 8px minimum.

The two surfaces also disagree about what a tab is. The console uses
`role="tab"` inside a `role="tablist"`. The trainee app uses `role="button"`
with the position hand-written into the label (`"Dashboard\nTab 1 of 5"`) —
doing manually, and only in the label, what the semantic role provides for
free.

### 9e. Dark theme verified — the light theme really is the problem

§1 claimed from arithmetic that dark mode passes and light mode carries the
failures. Measured off the rendered dark screens:

| Pair | Measured | Predicted in §1 |
|---|---:|---:|
| `#FF6B3E` on `#2C2C2C` | **4.94** | 4.94 |
| `#FFFFFF` body text on `#2C2C2C` | 13.97 | — |

The prediction and the pixels agree to two decimal places again. Dark mode is
sound; every contrast fix in §1–§3 is a light-theme change.

Rendering did add one thing arithmetic missed. Card-versus-background
separation:

| Theme | Page | Card | Separation |
|---|---|---|---:|
| Dark | `#1E1E1E` | `#2C2C2C` | 1.19 |
| **Light** | `#FFFFFF` | `#FFFFFF` | **1.00** |

In light mode the cards are *the same colour as the page*. The only thing
making a card look like a card is its 2dp drop shadow — which is precisely the
M2 elevation §C2 proposes replacing with tonal surfaces. That change cannot
simply delete the shadow: at 1.00 separation there would be nothing left. The
spec'd `#F5F5F5` page background has to arrive in the same commit.

### 9f. The full-bleed layout is systemic

§8b found Login and Register rendering ~1,384px-wide fields at 1440px. The
profile-setup questionnaire does the same. Three screen families, one cause:
no `maxWidth` container anywhere on the trainee/auth surface. The Trainer
Console, by contrast, constrains its content properly — further evidence for
§C's "two design philosophies" reading.

The console's own gap is the **600–1024px band**: at 800×1000 it renders the
phone layout — bottom tab bar, no sidebar, ~250px of dead space — because
`>1024` is the only breakpoint in the codebase. The card grid reflows to two
columns, so it is specifically the navigation chrome that never adapts.

### 9g. Two API robustness notes, found by accident

Neither is a design finding, both are real:

- **`GET /api/TrainerConsole/{id}/nutrition-summary` 500s on a missing
  `date`.** The parameter is `[FromQuery] DateTime date` — non-nullable, no
  validation — so an absent value binds to `DateTime.MinValue` and the
  seven-day window underflows: `ArgumentOutOfRangeException` from
  `AddTicks`, returned as an unhandled 500 with a stack trace. A missing
  required parameter should be a 400. `docs/chat-timestamps.md` already
  records this family of bug: *a pre-epoch date is missing data, not history.*
- **`FitTracker.Api/obj/` is tracked in git.** Any contributor running
  `dotnet build` dirties `project.assets.json` and the generated nuget props.
  It should be ignored.

### 9h. Notes for anyone testing this app in a browser

Two behaviours cost real time and are worth writing down. **Typing into a
Flutter canvas drops characters**, and a dropped character in a password field
is indistinguishable from a wrong password — both surface as a 401. The
harness now types, reads the value back, and retypes on mismatch. Separately,
the API rate-limits auth at **5 requests per window**, which also presents as
a failed login. Between them, "the login is broken" was the wrong conclusion
three times.

### What the second method was worth

§8 closed by saying source reading and rendering find disjoint defects. The
authenticated pass sharpens that: the three most valuable findings here —
the calorie-target disagreement (9b), the two-window adherence label (9c), and
the light-theme card separation (9e) — are all **contradictions between two
correct things**. A grep sees one side. A unit test sees one side. Only
rendering both surfaces, against one account, with real data in the database,
puts the two halves on screen at the same time where the contradiction is
obvious.

That is the argument for seeding realistically rather than minimally. With an
empty database every one of these reads as a harmless zero.

---

## 10. Corrections

Planning the fixes meant reading the widgets properly rather than inferring
them from a screenshot. That disproved three claims made above. They are
corrected here rather than quietly edited, because the *reason* each was wrong
is the useful part.

### 10a. The calorie ring is not broken

§9b called the unfilled ring a consequence of the calorie-goal defect. It
isn't. `calorie_ring.dart` already handles a missing goal deliberately:

```dart
final hasGoal = kcalGoal > 0;
final progress = hasGoal ? kcalConsumed / kcalGoal : 0.0;
...
final label = !hasGoal ? l10n.calorieRingNoGoal(kcalConsumed) : ...
```

It draws no arc, swaps the "Goal 2000" caption for a plain `kcal`, hides the
remaining/over line entirely, and announces *"2512 kcal logged, no goal set"*
to a screen reader. Every one of those is the right behaviour. What I
photographed as a defect was a widget correctly reporting that there was
nothing to measure against.

### 10b. The chart legend is not lying either

§9's note that "the legend describes a distinction the chart never draws" was
wrong for the same reason. `isOverBudget` is:

```dart
bool get isOverBudget => goal > 0 && totalCalories > goal;
```

With no goal, no day *can* be over budget, so every bar is correctly the
within-target orange. The chart is consistent with itself.

### 10c. Food's app-bar icons are labelled

§9d listed "two app-bar icons" among the unnamed controls on the Food screen.
Both actually carry tooltips — `mealTemplates` and `refresh`
(`food_tracking_screen.dart:233,240`). The two unnamed controls at that height
are the **date-navigation arrows** (`:275,286`), which have none. The count of
20 stands; two of them were misattributed.

### What survives

The calorie-goal defect itself (§9b) is untouched and still real: the API's
`?? 0` makes the console believe a client has no goal when both the server
model and the client default to 2000. What narrows is the blast radius. Three
widgets handle "no goal" gracefully, so the visible damage is one string —
`targetCalories: 'Target {goal} kcal'` rendering **"Target 0 kcal"** where the
ring, eight centimetres away, already knows to say *"no goal set"*.

### The lesson

All three errors share a shape: **I inferred widget behaviour from a rendered
screenshot instead of reading the widget.** The screenshot showed an empty
ring, uniform bars and unlabelled icons — all true observations, all attributed
to the wrong cause. Rendering tells you *what a screen looks like*; only the
source tells you *why*, and a review that skips the second step will
confidently file correct behaviour as a bug.

That cuts against the conclusion of §8, which argued for rendering as the
method source reading can't replace. Both halves of that are true, and the
order matters: **render to find where to look, read to find out what is
actually wrong.** Stopping after the first step produces exactly these three
findings.

---

## 11. Remediation: what was actually fixed

Sections 1–10 are the review. This section is the record of acting on it —
seventeen commits on `claude/frontend-design-review-nfidbk`, what each measured
before and after, and the four times the work itself proved a finding wrong.

The review's own conclusion (§10) was *render to find where to look, read to
find out what is actually wrong*. Fixing added a third step that neither of
those covers, and it is the one worth taking away: **a green test proves the
thing you asserted, not the thing you shipped.** Two fixes here passed a new,
purpose-built test suite while rendering as complete no-ops. Only re-sampling
the pixels caught them.

### 11a. Contrast: the numbers, before and after

The light theme carried every failure §1–3 found. It now clears WCAG AA at
every pair, verified two ways — arithmetic in `test/core/contrast_test.dart`,
and pixel sampling of the rebuilt web bundle.

| Pair | Before | After | Mechanism |
|---|---:|---:|---|
| white on primary (every filled button, FAB) | 2.83 | **5.32** | `forgeOrangeOnLight` `#B24B2B` |
| orange as text/icon on a card | 2.83 | **5.32** | same token |
| orange on the page background | 2.59 | **4.88** | same token |
| `StatusBadge` ok on its own tint | 2.86 | **5.21** | light lerp toward black, 0.30 |
| `StatusBadge` warn on its own tint | 1.85 | **4.71** | light lerp 0.40 — amber starts far brighter |
| `StatusBadge` bad on its own tint | 3.46 | **5.00** | light lerp 0.30 |
| `StatusBadge` bad, **dark** | 4.34 | **5.6** | dark lerp deepened 0.35 → 0.45 |
| light input border on its fill | 1.32 | **3.22** | `borderLight` `#808080` |
| dark input border on its fill | 1.35 | **3.25** | `borderDark` `#7A7A7A` |
| a light card against the page behind it | 1.00 | **1.09** | page moved to the spec'd `#F5F5F5` — and seven console Scaffolds stopped overriding it (§11b) |

Two of those rows were not in the review at all, and both were found by the
test rather than by reading:

- **The dark `StatusBadge` was also failing.** §2 measured the light lerp and
  stopped there. Asserting both brightnesses in the same loop immediately
  showed `bad` at 4.34 in dark — a pre-existing failure the review missed
  because it only looked where it expected to find something.
- **The first `forgeOrangeOnLight` was wrong.** `#BF502E` cleared 4.75 on white
  and **4.36** on `#F5F5F5`. My own doc comment recorded 4.38 while the
  assertion demanded 4.5 — I had written down a failing number and not
  noticed it was failing. Deepened to `#B24B2B`.

A third came from sizing a colour against the wrong surface. `borderLight`
was chosen at `#949494` for 3.03 on white — but four screens fill their fields
through `onboardingFieldDecoration`, which uses a tinted `#E8E8E8`, where the
same border measures **2.48**. The test now asserts both fills, because a
border checked against one fill is a border unverified on the other.

### 11b. The two fixes that did nothing

Both shipped green. Neither changed a pixel.

**`ColorScheme.background` is not what a page is painted with.** Fix 4 set the
light page background to `#F5F5F5` there. Material 3 deprecated that field and
`Scaffold` reads `scaffoldBackgroundColor`; every page stayed `#FFFFFF`, so
cards still measured 1.00 against the page — the exact defect being fixed —
while a test asserting `surfaceLight` against `backgroundLight` passed, because
*those two tokens* are a fine pair. The assertion was true and irrelevant.

**Four screens never consult `inputDecorationTheme`.** The border fix went into
the theme. Login, register, settings and onboarding build their decoration
through `onboardingFieldDecoration`, which constructs its own `OutlineInputBorder`
and never reads the theme at all. The token changed, the theme changed, and the
screens most likely to be a user's first did not.

**And seven console screens named their own page colour.** This one was found
last, by re-sampling the rebuilt bundle rather than by reading anything. Every
Trainer Console screen set its Scaffold background to
`colorScheme.surfaceContainerLowest`, which in a light Material 3 scheme is
`#FFFFFF` — the same white the cards are. The dashboard measured **1.00:1**
card-against-page in the rendered screenshot, the exact defect §4 identified,
on the surface `CLAUDE.md` calls the trainer's workstation. Removing the
override took it to **1.09:1**.

Three instances, one shape: **the token was right and something downstream
never asked for it.** A deprecated field, a decoration helper that builds its
own border, and seven Scaffolds that name their own colour. None is detectable
by reading the theme, because in each case the theme is correct.

`test/core/contrast_test.dart` now asserts that the theme *applies* the token,
not merely that the token pairs are sound:

```dart
expect(
  themeProvider.lightTheme.scaffoldBackgroundColor,
  ForgeColors.backgroundLight,
  reason: 'Scaffold reads scaffoldBackgroundColor, not colorScheme.background',
);
```

That is a small assertion carrying a general rule. A design-token test has two
halves — *is this pair legible*, and *does the product use this pair* — and
only the first one is easy. The second is the one that catches a deprecation.

The console case needed the assertion pointed the other way round, at the pair
that must *not* work:

```dart
expect(
  _contrastRatio(light.surfaceContainerLowest, light.surface),
  lessThan(1.05),
  reason: 'if these ever differ enough to separate, this test can go — '
      'until then, a screen setting it as its page colour is a bug',
);
```

A theme-level guarantee needs a test that fails when a screen opts out of it,
and opting out is not something a screen announces.

### 11c. Routing: two bugs I introduced, both found by a browser

Step 11 (`go_router` + `usePathUrlStrategy`) was flagged in the plan as the
highest-risk item, for a documented reason: `CLAUDE.md` records that the
authenticated landing path has already produced one bug — *"that bug dropped
web trainers into the trainee app"* — and it did so because the landing
decision got duplicated. I then reproduced that exact mistake twice.

1. **`/console/:section` had no auth check.** The signed-out branch lived on
   the `/` builder only, so a signed-out visitor deep-linking to
   `/console/nutrition` still got `PostAuthHome`; `ProfileSetupGate` waited
   forever for a user id that never arrived and the page sat on a spinner.
   Fixed with a single top-level `redirect` — the one construct in `go_router`
   that *cannot* be duplicated per route.
2. **The redirect captured auth state at build time.** `AppRouter.build` took
   a `bool hasToken`, which is the state at app start. After a successful login
   it still read false, so every console navigation bounced back to `/` and the
   address bar never moved. It now takes `bool Function() isSignedIn`.

Neither is visible in a diff and neither breaks a test: the first needs a
signed-out deep link, the second needs a session that changes state mid-run.
Both took about a minute to find by driving a real browser at the built bundle.
This is the clearest case in the whole exercise for the review's §8 argument —
rendering is not a nicer way to check what you already know, it reaches a
different class of defect.

### 11d. Extraction: the numbers, and where it stopped

The plan's step 13 was "split the five god files". Measuring them changed the
scope, and the measurement is the argument:

| File | Lines | Classes | `State` classes | Tests referencing it |
|---|---:|---:|---:|---:|
| `active_workout_view.dart` | 2,831 | 4 | 1 | **0** |
| `create_view.dart` | 2,058 | 9 | 4 | **0** |
| `edit_view.dart` | 1,762 | 2 | 1 | **0** |
| `progress_dashboard_view.dart` | 1,621 | 7 | 1 | **0** |
| `food_add_screen.dart` | 1,582 | 2 | 1 | **0** |

These are not files containing many things that want separating; each is
mostly *one enormous `State`*. Splitting them means decomposing a stateful
widget with no test coverage — on the screens for logging a live workout and
building one. The only safety net is `flutter analyze` proving it compiles,
and compiling is not the property at risk.

That hazard was not hypothetical. Earlier in this same branch, a regex meant
for `create_view`'s animation controller matched **the wrong `initState`** —
the file has four — and inserted a `didChangeDependencies` into a class with
no controller. It compiled far enough to fail somewhere else entirely.

So the scope narrowed to what is safe without tests: **extract the pure
helpers, and test them on the way out.** Two extractions landed, both chosen
because they are pure, error-prone, and had already been wrong:

| Extracted to | From | Tests |
|---|---|---:|
| `feature/food_tracking/domain/food_search_ranking.dart` | `food_add_screen.dart` | 30 |
| `feature/progress/domain/progress_ranges.dart` | `progress_dashboard_view.dart` | 19 |

Both share the property that makes untested pure logic dangerous: **a wrong
answer is a plausible one.** A missing entry in a diacritic fold map, a
Levenshtein bound off by one, a range that spans 8 days instead of 7, a week
key that collides across years — none of these crash, none fail to compile,
and each produces a number or an ordering the user cannot check. Two of the
five functions in `progress_ranges.dart` carry a comment describing a bug of
exactly that kind that reached production.

Writing the tests surfaced one thing worth recording as behaviour rather than
fixing: `nameScore`'s word-boundary band returns a flat **15** regardless of
where the match sits or how long the name is, so `"Whole milk"` and
`"Coconut milk drink powder"` tie on the query `milk`. Every other band pays
for distance. The sensible order is recovered downstream by the sort's
shorter-name tiebreaker — by accident, not design. It is pinned as a test with
that explanation, because a refactor is the wrong place to retune ranking.

**Splitting the `State` classes is still worth doing.** It is deferred, not
dismissed, and the order is the point: those screens need tests first, and
that is its own piece of work rather than a step in this one.

### 11e. Scale snapping: two populations, one of them not a mistake

The review counted "~176 off-grid spacing values". Sorting them showed that
figure is really two different things:

| Values | Count | What they are | Action |
|---|---:|---|---|
| `5, 7, 9, 11, 13, 18` | 19 | genuinely arbitrary — literally what `CLAUDE.md` names | **snapped** |
| `2, 6, 10, 14` | 144 | half-steps: an icon-to-label gap, a badge's inner padding | left alone |
| `8.5, 9.5, 10.5, 11.5` (font) | 22 | arbitrary fractional sizes | **rounded** |
| `10, 11` (font) | 30 | badge and caption sizes | left alone |

Snapping the 144 would not be a cleanup, it would be a redesign.
`SizedBox(width: 2)` between an icon and its label is a deliberate hairline;
forcing it to 4 doubles it, at 144 sites, on screens with no tests. **144
consistent fine adjustments across a product is a convention someone applied,
not 144 independent errors** — and normalising them would leave the product's
spacing measurably *less* consistent than it is today.

The same reasoning spares the 30 sub-12px font sizes: `CLAUDE.md`'s rule is
"text under 12px **body**", and a `StatusBadge` label is a chip, not body text.

This leaves a real gap between the code and the conventions, and closing it
belongs at the conventions end: **`CLAUDE.md`'s spacing scale should record the
2px half-step.** That is a recommendation, not a change made here — the
conventions are the owner's, and editing them to match the code is backwards.

### 11f. What is now covered that was not

| | Before | After |
|---|---:|---:|
| Tests | 317 | **365** |
| Contrast pairs asserted | 0 | 14 sites, several looping over both themes |
| Reduced-motion sites honoured | 1 of 10 | **10 of 10** |
| Raw `Colors.red/green/orange` | 68 | 0 |
| Shared widgets in `core/widgets/` | 0 | 9 |
| Breakpoint literals (`1024`) | 8 copies | 1 (`Breakpoints`) |
| Console sections with a URL | 0 of 5 | **5 of 5** |
| Pure helpers extracted and tested | 0 | 10 functions, 48 tests |

### 11g. The lesson, restated

§8 argued for rendering; §10 argued for reading the source; this section adds
the third leg, and the three only work together:

> **Render to find where to look. Read the source to find out what is actually
> wrong. Then re-render to prove the fix reached the screen.**

Skip the first and you never see the 1,384px-wide login form. Skip the second
and you file three correct behaviours as bugs, as §10 did. Skip the third and
you ship three green no-ops, as §11b did — a background that was never painted,
a border on four screens that never read the theme, and a page colour seven
console screens overrode with white.

The unifying property is that **none of the defects in this review were
type errors.** Not one would be caught by a compiler, an analyzer, or a widget
test asserting that something rendered. Contrast is a property of a *pair*
that no single file holds; a URL is a property of *navigation over time*;
reduced motion is a property of a *setting nobody has turned on*. Each needs a
place where the whole property can be named, and the durable output of this
work is not the fixed colours — it is the three files where those properties
finally have somewhere to live: `test/core/contrast_test.dart`,
`lib/core/forge_motion.dart`, and `lib/core/app_router.dart`.

---

## 12. The trainee pass, at the depth the console got

§9 drove every screen once and reported the trainee half as a single
number each — "Food 20, Gym 2, Dashboard 1, Progress 1". Nobody could act on
that, because a count is not a control. Nine months of remediation later the
console had been fixed thoroughly and the trainee app had been fixed where it
happened to overlap.

This section redoes the trainee half properly, and makes it repeatable: the
sweep is now `AUDIT=1 npx playwright test audit.spec.ts` against a seeded API,
walking both surfaces at 1440 / 800 / 390 and writing an accessibility tree, a
screenshot and a summary table per screen.

### 12a. The method's own bugs came first

Three of this pass's measurements were wrong before they were right, and all
three were wrong in the flattering direction:

| What | Symptom | Cause |
|---|---|---|
| Names | every control on every screen "unnamed" | keyed off `aria-label` on `flt-semantics`; Flutter puts a button's name in its **text content** and a field's on the child `<input>` |
| Theme | every desktop console screen "dark" | sampled the pixel at x=2, which is the charcoal sidebar in *both* themes |
| Data | 0 workouts, 2,000 kcal, 85kg | captured before `SyncService.pullAll()` landed, i.e. photographed the defaults |

And one in the harness itself: `signIn` waited for the login button to become
detached, which resolves **immediately** when the locator matches nothing. It
"passed" in 200ms without ever signing in, and every screenshot underneath was
of the login screen.

This is §10's lesson arriving a second time by a different road. There it was
"I inferred widget behaviour from a rendered screenshot instead of reading the
widget." Here it is: *a measurement you have not falsified is a guess with a
number attached.* Each of the four was caught by asking the boring question —
does this number move when the thing it measures moves? — rather than by
noticing anything suspicious about the result. Three of them looked entirely
plausible.

### 12b. What the numbers were, and are

Unnamed interactive controls, and the widest control as a fraction of the
viewport at 1440px:

| Screen | Unnamed before | after | Widest before | after |
|---|---:|---:|---:|---:|
| trainee Dashboard | 1 | **0** | 0.978 | **0.561** |
| trainee Food | 0 | 0 | 0.978 | **0.561** |
| trainee Gym | 2 | **0** | 0.956 | **0.539** |
| trainee Progress | 1 | **0** | 0.500 | 0.500 |
| trainee Profile | 0 | 0 | 0.978 | **0.561** |
| Login | 1 | **0** | 0.333 | 0.333 |
| Register | 2 | **0** | 0.333 | 0.333 |
| console (all five) | 0 | 0 | 0.15 | 0.15 |

§9's Food count of 20 is genuinely 0 now — `0d7a206` fixed it. Its Gym 2,
Dashboard 1 and Progress 1 were all still there, unchanged, because nobody had
ever been told which controls they were. They are the Gym date-navigation
arrows, the Dashboard's SpeedDial, and the Progress refresh action.

Two findings the review recorded are **fixed and can be closed**: the trainee
tabs no longer use `role="button"` with `"Dashboard\nTab 1 of 5"` written into
the label — Material 3's `NavigationBar` emits a real `role="tablist"` with
labelled `role="tab"` children — and the auth screens now constrain their
width (0.333, from 0.96).

### 12c. The 44x44 that measured 40

The best finding in this pass is not a missing label. It is that several call
sites had **already been fixed**, in a way that reviewed correctly and did not
work:

```dart
IconButton(
  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
  ...
)
```

Measured in a browser: **44x40**. Three separate mechanisms trim it afterwards,
none of them visible at the call site:

1. `ThemeData.visualDensity` defaults to `adaptivePlatformDensity`, which is
   *compact* on web and desktop.
2. `ThemeData.materialTapTargetSize` defaults to `shrinkWrap` on web — so the
   padding that makes a minimum real is removed, on the one platform whose
   pointer is not a finger, in the same bundle a phone browser loads.
3. `IconButton.constraints` **overrides** `iconButtonTheme`'s `minimumSize`. The
   local fix was the thing keeping the systemic one out.

A rule about a physical dimension cannot be enforced by a constant that reads
like the rule. It has to be measured on the rendered thing, once, or it is
decoration.

### 12d. A regression of mine, found by looking

`ForgeNavBar` applied `NavigationDestinationLabelBehavior.onlyShowSelected` at
every width. That is a phone constraint — five labels genuinely do not fit at
390px — and at 1440px each destination gets 288px, so four of five labels were
hidden for no reason at all. The console never showed it, because its wide
layout is a sidebar and never reaches that widget. It was invisible in review
and obvious in a screenshot.

### 12e. What is still open

Stated as a measurement, which is the whole point of this section:

- **Food: 15 controls under 44x44 at 390px**, 14 of them the per-row edit and
  delete buttons at 44x40. The three theme fixes in §12c moved every other
  screen and did not move these, so something else in that row is binding.
- **800px:** trainee content still measures 0.92–0.96 of the viewport, because
  `contentMaxWidth` is 840 and the constraint does not bind below it. That is
  correct behaviour rather than a defect, but it means the 600–1024 band is
  the phone layout stretched, and `Breakpoints.mobile` is still used nowhere.
- **Macro colours as text** (§2: protein 4.23, carbs 3.68, fat 3.30) remain
  unaudited. The review's own advice was to check whether any of them carries
  a number before adding a `macroOnLight` variant; that check has not been
  done.

### The lesson from this one

§9 produced a number per trainee screen and stopped. The number was correct.
It was also useless, because "Gym: 2" cannot be fixed — and four years of
green test runs later, Gym still had exactly 2. A finding is only actionable
at the granularity of the thing you would change.

The counterpart lesson is §12a's: the sweep that produces those numbers is
itself code, and it is code with no tests and a strong bias toward reporting
whatever it happens to measure. Falsify each metric once — change the thing,
watch the number move — before believing any of them.
