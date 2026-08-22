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

A trainer is still also a ForgeForm user: they land in the console, but reach
their own training through `onExitConsole` without signing out.

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

## Still open

- **Server-side profile push is only as good as the existing sync.**
  `syncUserSettings()` and `syncWeightLogs()` run from `HomeScreen`'s initial
  sync, so setup data reaches the server on the next sync rather than
  immediately. Fine today; worth making explicit if setup ever needs to be
  authoritative at that moment.
- **A trainer has no way to set personal goals.** Being a trainer skips setup
  entirely, and nothing offers it later. Settings can edit goals, but there's no
  prompt. If trainers train too, that's a gap worth closing.
