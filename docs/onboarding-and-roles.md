# Onboarding and roles

## Where it stands

Profile setup is a three-page personal-fitness intake — profile (name, age,
height, sex), goals (activity level, cutting/bulking, current and goal weight)
and a daily calorie target.

It used to run **before** authentication, gated on a device-wide
`onboarding_complete` pref, with no way past it. That meant the app asked for a
goal weight and a daily calorie target before it had any idea who it was talking
to — and a trainer, who has no such goals, had to invent them just to reach the
login screen. The role could not be consulted, because it comes from
`api/TrainerClient/status`, which needs a token, which needs login.

It now runs **after** authentication, and only for trainees.

## How it works now

**Pre-auth** (`WelcomeScreen`) is what ForgeForm is, plus Sign in / Create
account. It collects nothing. On web it's skipped in favour of the login screen
directly — that surface is the Trainer Console, and a consumer pitch for calorie
tracking has no place in front of it.

**Registration picks the role.** The register screen offers an account type —
"For myself" or "Coaching clients" — defaulting to trainee, and sends it as
`accountType`. Registering as a trainer is what provisions the trainer licence,
and holding a licence is what makes someone a trainer, so this is the only moment
the Trainer Console becomes reachable at all. The choice is permanent: an
existing account cannot be converted, and the trainee app shows no trainer
affordance anywhere. See `docs/trainer-licensing.md` → "Becoming a trainer" for
why the old self-serve route was removed.

A trainer is still also a ForgeForm user: they land in the console — on every
platform, not just the web — but reach their own training through
`onExitConsole` ("My training") without signing out. That choice lasts the
session; the next launch opens the console again. See "Why a new trainer still
landed on the dashboard" below for what that sentence used to be worth.

**Post-auth**, `PostAuthHome` → `ProfileSetupGate` decides. Setup is shown only
when both hold:

* **The role is resolved.** `AccessProvider.roleResolved` is separate from
  `initialized`, which flips as soon as *cached* flags load — and on a first
  sign-in there is no cache, so gating on that alone would flash the trainee
  questionnaire at a trainer.
* **The user is not a trainer.** If the role can't be resolved at all (offline,
  no cache) setup is skipped rather than risked. Asking a trainer for their goal
  weight is worse than a trainee setting goals later in Settings, and they get
  prompted on the next launch with network.

"Set up later" records completion so the app doesn't nag; goals stay editable in
Settings.

Completion is per account (`ProfileSetupPrefs`), so onboarding on a phone isn't
re-asked on the web, and two people sharing a device are each asked once. The
old device-wide `onboarding_complete` is still honoured as "this account is
done", so nobody who already finished gets asked again after updating — but it
is never written, because writing it would mark every other account on the
device complete too.

Because there is a real account behind it, the starting weight record is queued
for sync (`WeightSyncStatus.pending`) instead of being marked already-synced to
keep it local, which is what the pre-auth version had to do.

`PostAuthHome` is the single place deciding where an authenticated user lands.
Cold start, login and register each used to push `HomeScreen` directly, which
meant a trainer signing in on web got the trainee app.

## Why a new trainer still landed on the dashboard

Everything above was already written, and already true on paper, when a trainer
registering an account still found themselves on the trainee dashboard. The
account type was sent, the licence was minted, `api/TrainerClient/status`
answered `isTrainer: true` — and the app opened on calories and body weight.

Two separate defects produced the same symptom. Neither was a type error,
neither failed a test, and the doc you are reading described the behaviour
everyone believed was implemented.

### The landing rule was written as a platform branch

`PostAuthHome._home()` began:

```dart
// Off the web the console is reached from Settings, so nothing here has to
// wait on the role check.
if (!kIsWeb || _showTraineeApp) return const HomeScreen();
```

The comment is an accurate description of a decision that was reasonable when
the console was a web-only surface, and it is also the whole bug. `PostAuthHome`
is documented — here and in `CLAUDE.md` — as *the single place deciding where an
authenticated user lands*, and the rule it was actually enforcing is "web
trainers get the console." ForgeForm ships to five targets. On four of them the
role was never consulted at all, so a trainer's landing screen was decided by
the platform they happened to register on, and the console was reachable only by
a trainer who already knew to look in Settings for it. The one thing a new
trainer cannot be expected to know is where the product they just signed up for
lives.

The fix is one line: drop the `!kIsWeb`, and let the role decide on every
platform. The console shell was already responsive — `trainer_console_shell.dart`
switches to a bottom tab bar below 1024px — so nothing else had to move.

The general shape: **when a rule is stated in terms of the user
(`if (isTrainer)`) but implemented in terms of the environment (`if (kIsWeb)`),
the two agree only for as long as the environment happens to correlate.** The
correlation here was "the console is a web thing," and it stopped holding the
moment desktop and mobile could render the console — which they could, months
before anyone noticed the landing rule hadn't been told.

### The role check waited for the wrong signal

`TrainerConsoleGate` showed a spinner while `!access.initialized`, then branched
on `access.isTrainer`. `initialized` means *the cached flags have been read off
disk* — it flips before `api/TrainerClient/status` is called, by design, so a
returning user's UI is right immediately. On a **first** sign-in there is no
cache, so at that moment:

| | value | what it means |
| --- | --- | --- |
| `initialized` | `true` | prefs were read |
| `isTrainer` | `false` | **nobody has asked yet** |
| `roleResolved` | `false` | the server has not answered |

The gate read row two as "this user is not a trainer" and rendered its fallback:
the trainee app. When the status call landed a second later the widget did
rebuild into the console on web — a flash rather than a wrong destination — but
combined with the platform branch above, a trainer registering on a phone was
simply left on the dashboard, because the gate was never in the tree at all.

`isTrainer` is a `bool`. It has exactly two values, and it is being asked to
carry three states: yes, no, and *nobody has asked yet*. The third collapses
into the second silently, at the one moment in an account's life when it is the
true one. `ProfileSetupGate` had already been bitten by this — `roleResolved`
exists precisely because gating the trainee questionnaire on `initialized` would
flash it at a trainer — but the knowledge lived in one widget instead of in the
provider's API, so the console gate re-made the same mistake from scratch.

`AccessProvider` now exposes the missing state as a signal of its own:

```dart
bool get roleKnown => _roleResolved || _roleFromCache;
```

Read it as "the role question has been *answered* for this account, by someone."
It is deliberately weaker than `roleResolved` (which keeps its exact meaning:
the server has been asked this session), because a cached answer for the same
user is a real answer — a returning trainee must not sit behind a spinner
waiting on the network to be shown their own app. The gate waits on `roleKnown`;
`ProfileSetupGate` still waits on `roleResolved`. Two questions, two signals.

### The cache could also answer confidently and wrongly

Making `roleKnown` mean anything exposed a third problem underneath. The cached
flags — `access_is_trainer`, `access_is_premium`, `access_is_trainer_client`,
the trainer's id and name — were stored per *device*, not per *account*. Sign in
as a trainee, sign out, register a trainer on the same phone, and `initialize()`
restored the trainee's `isTrainer: false` for the new account. Not an absent
answer that `roleKnown` would make the UI wait for: a confident wrong one, with
no way to tell it from a right one.

The flags are now stamped with the account they describe
(`access_cached_user_id`) and restored only on a match. A mismatch is treated as
no cache at all, which is exactly what it is. The same fix keeps a previous
user's `access_is_premium` from briefly granting Pro to whoever signs in next,
which the invariants in `docs/trainer-licensing.md` care about rather more.

Existing installs have flags but no stamp, so the first launch after this update
discards them and waits for the server once — self-healing from the launch after
that. The one visible cost is a trainer whose first post-update launch is
offline: with no cache to fall back on and no server to ask, they get the trainee
app until a launch with network. Serving them a device-wide guess is what this
change is for, so that trade is deliberate.

The general shape: **cached state derived from an identity must be keyed to that
identity, or it will be served to the next identity as fact.** A cache without a
key isn't a cache of "the user's role" — it's a cache of "the last role we saw,"
and those differ precisely when a device changes hands, which is also when the
account is new and everything else is at its most fragile.

### Why nothing caught it

- **The compiler had nothing to say.** Every value involved is a correctly-typed
  non-null `bool`. "Unknown" was never a value the type system could see was
  missing, because the type was never asked to represent it.
- **The tests were green because they all started from the end state.** Every
  existing gate test constructed `AccessProvider.withState(...)` with the role
  fully resolved — the state a user is in a second after sign-in, and for the
  rest of the session. The buggy window is the first frame after registration,
  which no test had ever asked for. A widget test is only as good as the states
  it is willing to construct, and "half-loaded" is the state nobody thinks to
  write down.
- **The docs asserted the intended behaviour, so nobody re-derived it.** This
  file said trainers land in the console. It had said so since before the
  console could run anywhere but a browser. Documentation records intent; it
  cannot notice when the code stops matching, and a confident doc is a good
  reason not to go looking.

The tests now pin the two states that were missing: a gate handed an unanswered
role must spin rather than fall through
(`test/trainer_console/trainer_console_gate_test.dart`), and `initialize()` must
not restore another account's flags (`test/trainer_console/access_provider_test.dart`).
`PostAuthHome` itself is not widget-tested — it builds the real console with
live repositories, the Riverpod auth container and the database, so a test would
exercise the network rather than the decision. The decision it makes is one
line, and the gate it delegates to is covered.

One consequence worth knowing: `HomeScreen._runInitialSync()` no longer runs at
launch for a trainer, since they no longer pass through `HomeScreen` to get
anywhere. Their own trainee-side sync happens when they open "My training".

## Still open

- **Server-side profile push is only as good as the existing sync.**
  `syncUserSettings()` and `syncWeightLogs()` run from `HomeScreen`'s initial
  sync, so setup data reaches the server on the next sync rather than
  immediately. Fine today; worth making explicit if setup ever needs to be
  authoritative at that moment.
- **A trainer has no way to set personal goals.** Being a trainer skips setup
  entirely, and nothing offers it later. Settings can edit goals, but there's no
  prompt. If trainers train too, that's a gap worth closing.
