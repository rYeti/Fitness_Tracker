# Changelog

Engineering record of what changed in each release. Newest first.

There is no length limit here. The short blurb users actually see on the store
listing lives in `PLAY_NOTES.md` — a release needs a section in both.

Work in progress goes under `## Unreleased`. The release workflow renames that
heading to the version it went out as, so a `## <version>` section is history:
it is what those users have, and nothing new belongs in it. See
`docs/android-release.md`.

## 1.0.2+14

- Chat messages now show the time they were sent, and the day dividers in a thread name the right day. A message whose timestamp the server could not supply was being drawn as `01/01/0001` — the shape a missing date takes when a non-nullable field has to hold something — and a malformed one replaced the entire conversation with a load error. Timestamps are also read as the instants they are rather than as local wall-clock digits, so a payload without a timezone designator can no longer shift every message in the app by the reader's UTC offset. The day divider read its calendar fields off a UTC instant while the code deciding whether to insert one read local fields, so either side of local midnight the pill could announce a different day than the messages under it. Bubbles now carry a time, and a screen reader hears the full date and time on each one; a pending or failed message deliberately shows none, because the moment the user pressed send is not a sent time. See `docs/chat-timestamps.md`.
- The Trainer Console now opens in a fraction of the time. Four things were making a trainer watch a skeleton, and they compounded. The roster and the dashboard summary each looped over every client and read that client's *entire* training history — every session, exercise and logged set they had ever recorded — in order to count four weeks of them and find one date; because the two run in parallel, a single dashboard paint read the whole roster's history twice. Both are now one set of aggregate queries whose cost does not grow with the roster: for a trainer with 25 clients, 102 queries become 8. The other console reads had the same shape and are now bounded too — one day's workout history no longer reads a career, session review pages in the database instead of building every past session and keeping ten, and exercise names come from the exercises actually referenced rather than from loading the entire exercise catalogue. Reads no longer go through EF's change tracker, and three composite indexes cover the pairs these queries filter on. See `docs/trainer-console-loading.md`.
- The console no longer loads all five of its sections when it opens. They were built together, so Dashboard, Messages, Workout Builder, Nutrition and Session Review each fired their own requests on the first frame — five screens' worth of network for the one the trainer was looking at. Each section now loads when it is first opened and stays loaded after that, so switching tabs is still instant. Chat is the exception and loads up front on purpose: it is what joins this device to every conversation, and deferring it would blank the unread badge.
- The dashboard now draws each part as it arrives instead of waiting for all of it. The client list and the summary tiles were behind one loading flag, so the list waited on the slower of the two and a single failed request blanked the whole page — including the invite button, the one thing an empty console is for. Client Detail behaves the same way now: a failing nutrition endpoint costs its own card rather than hiding the client's training.
- The client list is fetched once per console open rather than twice. The client switcher and the dashboard were reading it from two different endpoints, which could also disagree with each other.
- Fixed the dashboard reporting zero sessions and zero average adherence every Sunday, and the twelve-week attendance chart being shifted a week on that day. The week's start was computed in a way that lands on tomorrow when today is a Sunday.
- Fixed the strength progression chart on Client Detail showing blank exercise names. It looked names up by the wrong identifier, and a missing name rendered as an empty string rather than an error, so the failure looked like a design choice.
- The access token is now read from the device keystore once rather than on every outgoing request, and the trainer-status check reuses its connection instead of opening a new one each time.

## 1.0.2+13

- The web bundle no longer fetches its rendering engine from Google's CDN at startup. `flutter build web` defaults to loading CanvasKit from `gstatic.com` at runtime rather than using the copy it just placed in the build output, so the uploaded bundle — the one the Trainer Console is served from — could not start on any machine that could not reach that domain, a corporate proxy with a strict allowlist included. Nothing caught it because no check the repo had ever loaded the bundle in a browser: `flutter analyze` reads source, `flutter test` runs widgets in a Dart VM with no bootstrap and no network, and `flutter build web` exits zero having written a URL into a JavaScript file. The build is now self-contained.
- Added end-to-end tests that run a real browser against the built web bundle in CI, which is how the above was found. Flutter web paints the entire app into a canvas, so the tests query the accessibility tree — the only surface a browser can see — which makes semantic labels on interactive widgets a testability requirement as well as an accessibility one. The suite also pins two rules that were previously only written down: that a signed-out visitor on web lands on login rather than the consumer welcome screen, and that unknown deep links are rewritten to the app shell while missing assets still 404. See `docs/e2e-playwright.md`.
- Registering a trainer account now opens the Trainer Console instead of the trainee dashboard, on every platform rather than only in a browser. Two things sent new trainers to the dashboard: the post-auth landing rule was written as a platform check (`kIsWeb`) rather than a role check, so off the web the role was never consulted and the console was reachable only from Settings; and the console's role gate treated "nobody has asked the server yet" as "not a trainer", which is exactly the state a brand-new account is in for the first second of its life. The gate now waits for the role to actually be answered — a cached answer for the same account counts, so returning users still see their own app immediately. Leaving the console for your own training is unchanged ("My training", no sign-out). See `docs/onboarding-and-roles.md`.
- Fixed cached access flags (trainer role, premium, assigned trainer) being restored for the wrong account when more than one person signs in on the same device. They were stored per device rather than per account, so the previous user's answers stood in for the next one's until the server replied — briefly granting a stranger's Pro, among other things. They are now keyed to the account they describe and ignored for anyone else.
- Fixed switching accounts on a device bringing workouts back wrong: exercises and sets duplicated, and exercises you had deleted restored. None of it was caused by the switch — those rows were already on the server. Removing an exercise from a workout that had already synced never reached the server at all (saving a workout did not mark it for re-upload, so the deletion sat in a queue nothing read), and retried uploads could leave a second copy of an exercise or a whole prescription behind. The app never noticed because it skips downloading any workout it already has; signing out clears the device, so the next sign-in was the first time it ever read the server's copy back. Deletions and edits now reach the server, repeat uploads no longer create a second copy, and the download folds together any duplicates already stored — so affected accounts read correctly with no re-save and no cleanup. See `docs/sync-account-switch-duplication.md`.
- Fixed the app taking hours to fetch an account's data after signing in again. The daily background task only uploads, but it stamped the same "last synced" marker the startup download checks, so a background upload could suppress the download for six hours. The two are now tracked separately.
- Signing out now clears this device's copy of your account immediately, rather than at the next sign-in. If anything has not reached the server yet, ForgeForm tries to upload it first and then says how many changes would be lost and lets you cancel.
- Deleting a workout you had ever scheduled failed on the server with an error the app never surfaced, so the workout came back on the next full download. It now deletes, along with any sessions of it you never performed; a workout with training logged against it is kept, and the app is told why instead of retrying forever.
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
