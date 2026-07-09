# Changelog

Patch notes for Google Play Store releases. Newest first.

## Backend (no client update required)

- Fixed the "forgot password" email failing intermittently — the CI deploy workflow was overwriting the Gmail API credentials on every push to `main` because `gcloud run deploy --set-env-vars` replaces the whole env var set rather than merging. Gmail credentials are now passed through CI as secrets so they survive every deploy.

## 1.0.2+4

### Fixed

- Fixed a bug where users could get randomly logged out, even with a valid session. Sessions now renew automatically in the background instead of requiring a full re-login.

## 1.0.2+3

### Fixed

- Fixed a bug where removing an exercise from a workout during editing wasn't actually saved — the deleted exercise would come back.

### Improved

- The workout-complete checkmark now uses a distinct success green instead of the neutral dark color, making it clearer when a workout is finished.
