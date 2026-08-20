# Onboarding and roles

## Where it stands

Onboarding is a four-page personal-fitness intake — profile (name, age,
height, sex), goals (activity level, cutting/bulking, current and goal weight)
and a daily calorie target. It writes a local profile, a calorie goal and a
starting weight record.

It runs **before authentication**, gated only on the local
`onboarding_complete` pref.

Two fixes have landed:

- **"Already have an account? Sign in"** on the welcome page. Previously the
  only way to reach the login screen was to complete the whole questionnaire,
  so anyone reinstalling, moving to a new phone, or holding a gym-created
  trainer account had to invent a goal weight first. The flag is set on
  successful auth rather than on tapping the link, so backing out of login
  leaves onboarding intact for a genuinely new user.
- **Web skips onboarding entirely.** The browser is the Trainer Console's
  surface; a phone-shaped fitness intake in front of the login screen was
  simply wrong there. A trainee who registers on web sets goals in Settings
  instead.

`PostAuthHome` is now the single place deciding where an authenticated user
lands. Cold start, login and register each used to push `HomeScreen` directly,
which meant a trainer signing in on web got the trainee app — the landing
logic only ran on a cold start with an existing token.

## The part still outstanding

**A trainer still sees a trainee's onboarding on mobile.** The "Sign in" link
routes around it, but a trainer who genuinely is new — no account yet — still
gets asked for their cutting goal.

This cannot be fixed by branching inside onboarding. `isTrainer` comes from
`api/TrainerClient/status`, which needs a token, which needs login. **At the
moment onboarding runs, the role is not knowable.** Any attempt to special-case
trainers earlier in the flow is guessing.

### The shape of the real fix

Move profile setup to *after* authentication, where the role is known:

1. App opens → welcome/value screen → Login or Register. No data collection.
2. After auth, `AccessProvider` resolves the role.
3. Trainee → the goals flow, now able to write server-side rather than only
   into local Drift tables for an account that may not exist yet.
4. Trainer → straight to the console. Never asked for a goal weight.

### Why it's more than moving widgets

- **Onboarding currently writes local-only state.** It saves a profile, a
  calorie goal and a weight record marked `synced` so it is never pushed. Once
  it runs post-auth, that data belongs to a real account and the "never sync"
  shortcut stops being correct.
- **`onboarding_complete` is device-local.** It should become per-account, or
  a user who onboards on their phone gets asked again on the web.
- **Existing users must not be re-onboarded.** Anyone with `onboarding_complete`
  already set needs to be treated as done, whatever the new flow decides.
- **A trainer may also train.** "Is a trainer" shouldn't permanently forfeit
  the ability to set personal goals later from Settings.

### Suggested sequencing

1. Make `onboarding_complete` per-account, keyed on user id, honouring the
   existing device-level flag as already-complete for current installs.
2. Move the goals flow behind auth, reached only when the signed-in user is a
   trainee and hasn't completed it.
3. Reduce the pre-auth screen to welcome + Login/Register.
4. Let the goals flow write through to the server, and drop the
   `synced`-on-insert workaround for the starting weight record.
