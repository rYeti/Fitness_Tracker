# Changelog

Patch notes for Google Play Store releases. Newest first.

## Unreleased

- Added a curated database of verified foods (sourced from the German BLS 4.0 nutrient database) — these now appear above crowdsourced search results with a "Verified ✓" badge when adding food. Stored locally only: never synced, never in recents, survives logout.
- Added an adaptive calorie target on the progress dashboard: after at least 2 weeks of weight and food logs, the app estimates your actual daily energy expenditure and lets you apply it as your daily calorie goal with one tap.
- Added data export in Settings: workouts, weight history, and nutrition as CSV, plus a full JSON backup of all local data.
- Added optional RPE tracking (6–10) per set, with a toggle in Settings.
- Added set types (normal, warm-up, drop set, failure) and per-side logging (left/right/both) for sets in the active workout screen.
- Trimmed the Premium feature list on the paywall: data export and custom foods are free — data ownership is never gated behind Premium.

## 1.0.2+9

- The paywall now shows free trial and introductory pricing on eligible plans, instead of just the regular price.
- Fixed a display bug where the "Premium" lock could visually cover more of the Appearance settings section than intended when scrolled to certain positions.

## 1.0.2+8

- Replaced the hosted Premium paywall with a custom-branded upgrade screen.
- Added a "Restore purchases" option in Settings, with clear success/failure feedback.

## Backend (no client update required)

- Fixed a bug where trainer-side authorization checks (`IsActiveTrainerOfAsync`) were comparing the wrong ID, potentially letting the check silently fail across the app.
- Started backend groundwork for Trainer Console chat (SignalR hub, message model/repository, JWT auth over the hub's WebSocket connection) — not yet exposed to the client app.
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
