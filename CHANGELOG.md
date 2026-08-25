# Changelog

Engineering record of what changed in each release. Newest first.

There is no length limit here. The short blurb users actually see on the store
listing lives in `PLAY_NOTES.md` — a release needs a section in both.

Work in progress goes under `## Unreleased`. The release workflow renames that
heading to the version it went out as, so a `## <version>` section is history:
it is what those users have, and nothing new belongs in it. See
`docs/android-release.md`.

## Unreleased

- Food added to a meal after that meal had already synced was never uploaded — not to the server, not to another device, and not to a reinstall. The app only ever uploads meals it considers unsynced, and nothing in it marked a meal changed once it had been pushed: `markMealPendingUpdate` and `markMealPendingDelete` existed with no callers at all. Adding or removing food now puts the meal back in the queue.
- Removing a food from a meal now reaches the server. The local row was deleted and nothing was ever sent, so the server — and the trainer's Nutrition tab — kept showing food the client had deleted. Removals of already-uploaded food are queued (`MealFoodDeletionTable`, schema 38) so they survive being offline, and the pull no longer restores a food whose removal is still queued.
- Uploading a meal's foods now reconciles against what the server already holds instead of appending. A re-pushed meal — after a reconcile pass cleared its local link, or from a second device — used to add its foods a second time and inflate the day's calories. Foods the server already has are adopted rather than re-sent, matched by food *and count* so a genuine second portion still uploads. This is the duplication path `docs/trainer-nutrition-duplicate-meals.md` left open; part two of that document covers all three.
- API: `PUT api/Meal/{id}` now returns the meal's food entries instead of an empty list, which is what the client reconciles against.

- Trainer Console: the Nutrition tab no longer shows a client's day twice over — two breakfasts, two lunches, two dinners, two snacks. The database has never limited a client to one meal row per category per day, and the app's sync could genuinely write a second one (a reconcile pass clearing a meal's server link when the row only looked gone, a response lost after the row was written, a second device, or the old `Snack`/`Snacks` category spelling failing to match itself). None of it was visible in the app, which renders four fixed meal sections and reads the first row of each, and the day's calorie and macro totals are computed from the foods themselves, so folding the rows back together leaves them unchanged. Creating a meal is now idempotent per day and category, so no new rows accumulate, and the console folds rows that already exist back into one meal — no re-sync or cleanup needed on affected accounts. See `docs/trainer-nutrition-duplicate-meals.md`.
- Trainer Console: Snacks in the Nutrition tab now carry the snack icon and sort between lunch and dinner instead of last. The screen matched the lowercase `snack` its API documents while the app writes `Snacks`, so the category fell through to the unknown-category handling everywhere except its label.

## 1.0.2+12

- Trainer Console: Session Review no longer lists sessions from workout plans the client has moved off. Activating a new plan only deactivates the old one — every date it ever generated stays scheduled — so the trainer's history was padded with dates nobody had asked the client to train on, each shown as Missed. Sessions the client actually completed, skipped or logged against are kept regardless of what became of the plan. The same filter now applies to average adherence, per-client roster adherence and the 12-week attendance chart, all of which were counting those dates as planned-and-not-completed and so understating adherence.
- Trainer Console: Session Review no longer shows exercises that are no longer in the workout, previously listed as Skipped. Removing an exercise from a workout failed server-side for any workout that had ever been scheduled (a restricted foreign key from the logged-session tables), so the exercise stayed in the workout on the server and was stamped onto every session generated afterwards, invisible in the app but visible to the trainer. Removal now works: sessions that logged nothing against the exercise lose it outright, and where sets were logged the exercise is retired from the workout instead of deleted, so the history keeps its name. See `docs/trainer-session-review.md`.
- Trainer Console: Session Review no longer inflates how many sets an exercise prescribes. Saving a workout pushes its whole prescription, and the API appended it instead of replacing it, so an exercise saved three times reported three times as many sets. The API now replaces, and Session Review collapses duplicate set numbers so already-affected workouts read correctly without being re-saved.
- Trainer Console: tapping a meal in the Nutrition tab now opens it, listing every food in that meal with its own serving weight, calories and macros. The meal row only ever had space for a one-line list of names, so which item carried the calories wasn't visible anywhere. The nutrition endpoint now returns per-food nutrition alongside the names it already sent; a meal with no per-food detail stays a plain, non-tappable row.
- Fixed the Trainer Console's Nutrition tab failing with "Could not load this client's nutrition" for every client on every date, and Client Detail failing with it. The nutrition endpoint passed the requested day to Postgres without a UTC kind, which Npgsql rejects outright for a `timestamp with time zone` column, so the request 500'd before it read anything. Client Detail loads its three panels together, so the same error blanked that screen too.
- Fixed the trainer-facing nutrition day being off by one for any client not in UTC. Meals are logged against the client's local midnight and stored converted to UTC, so a German client's Tuesday sits at 22:00 Monday in the database; the summary read midnight-to-midnight in UTC and so reported the wrong day's food. Days are now matched against the day they were logged on. Clients at UTC+13/+14 (New Zealand in summer, Samoa, Kiribati) still read one day early.
- The 7-day nutrition trend now loads in a single query instead of seven sequential ones.
- Trainer Console nutrition and client-detail failures are now logged with their cause instead of being swallowed, which is why the above went unnoticed.

## 1.0.2+11

- Fixed a crash opening Meal Templates ("type 'Null' is not a subtype of type 'int'") caused by templates pulled from the server missing an internal field. Already-affected templates on your device are repaired automatically the next time they load.
- Fixed Snack meal templates silently failing to appear in the Food tab after being logged — Snack templates used a different internal category than the rest of the app, so logged food was saved but never shown. Existing Snack templates are migrated automatically.
- Fixed a synced meal template's "total batch weight" being dropped when synced to or from the server, which silently disabled the gram-portion picker (falling back to "log full template only") for any template that had gone through a sync.

## 1.0.2+10

- Fixed the dashboard's daily calorie total and the progress screen's calorie-trend chart not updating after editing or deleting a food entry — both were only ever refreshed on cold start, not when returning from the Food tab.

## 1.0.2+9

- Added a curated database of verified foods (sourced from the German BLS 4.0 nutrient database) — these now appear above crowdsourced search results with a "Verified ✓" badge when adding food. Stored locally only: never synced, never in recents, survives logout.
- Added an adaptive calorie target on the progress dashboard: after at least 2 weeks of weight and food logs, the app estimates your actual daily energy expenditure and lets you apply it as your daily calorie goal with one tap.
- Added data export in Settings: workouts, weight history, and nutrition as CSV, plus a full JSON backup of all local data.
- Added optional RPE tracking (6–10) per set, with a toggle in Settings.
- Added set types (normal, warm-up, drop set, failure) and per-side logging (left/right/both) for sets in the active workout screen.
- Trimmed the Premium feature list on the paywall: data export and custom foods are free — data ownership is never gated behind Premium.
- The paywall now shows free trial and introductory pricing on eligible plans, instead of just the regular price.
- Fixed a display bug where the "Premium" lock could visually cover more of the Appearance settings section than intended when scrolled to certain positions.

## 1.0.2+8

- Replaced the hosted Premium paywall with a custom-branded upgrade screen.
- Added a "Restore purchases" option in Settings, with clear success/failure feedback.

## Backend (no client update required)

- Fixed a bug where trainer-side authorization checks (`IsActiveTrainerOfAsync`) were comparing the wrong ID, potentially letting the check silently fail across the app.
- Started backend groundwork for Trainer Console chat (SignalR hub, message model/repository, JWT auth over the hub's WebSocket connection) — not yet exposed to the client app.
- Continued Trainer Console chat backend: added a chat history endpoint, fixed messages losing their trainer/client link when persisted, and made sends idempotent by deduping on a client-generated message ID (so a dropped ack and retry can't create a duplicate message) — still not exposed to the client app.
- Fixed a privacy bug where custom exercises created by one user could show up in other users' exercise lists.
- Fixed several account-security gaps where a user could potentially view or modify another user's workouts, scheduled workouts, or workout plans.
- Fixed a bug where trying to update someone else's weight entry returned a server error instead of being cleanly blocked.
- Fixed a bug where generating a trainer invite code could fail with a server error.
- The "forgot password" flow no longer fails if the confirmation email can't be sent — you'll still get a clean response either way.
- Added stricter validation on workout, meal, and profile data submitted to the server (realistic ranges for reps, weight, calories, macros, etc.).
- Fixed the "forgot password" email failing intermittently — the CI deploy workflow was overwriting the Gmail API credentials on every push to `main` because `gcloud run deploy --set-env-vars` replaces the whole env var set rather than merging. Gmail credentials are now passed through CI as secrets so they survive every deploy.
- Added trainer console endpoints for client workout history, nutrition summaries, and workout plan management (backend only — no client app changes yet).
- Fixed a bug where trainer console workout plan templates failed to load from the server instead of returning results.

## 1.0.2+6

- Redesigned the Premium upgrade screen and added a free trial option.

## 1.0.2+5

### Fixed

- Your login session is now stored more securely on your device.
- Removed debug logging that could include sensitive account details.
- Added clearer validation messages when registering or updating your profile (required fields, email format, minimum password length, minimum age).

## 1.0.2+4


- Fixed a bug where users could get randomly logged out, even with a valid session. Sessions now renew automatically in the background instead of requiring a full re-login.

## 1.0.2+3


- Fixed a bug where removing an exercise from a workout during editing wasn't actually saved — the deleted exercise would come back.

### Improved

- The workout-complete checkmark now uses a distinct success green instead of the neutral dark color, making it clearer when a workout is finished.
