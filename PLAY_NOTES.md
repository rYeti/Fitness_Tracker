# Play release notes

The short, user-facing blurb shown on the Google Play store listing for each
release. Newest first.

`CHANGELOG.md` is the full engineering record and has no length limit; this
file is what users actually read, so keep each section to the handful of
changes someone would notice using the app.

Two rules the release workflow enforces:

- Each heading is the full `pubspec.yaml` version, `+buildNumber` included, and
  must match the version being released exactly. That is what stops a release
  shipping the previous version's notes.
- Each section must fit **500 characters** — Play's per-locale limit. Over that
  the release fails rather than being truncated mid-sentence in front of users.

Sections are published verbatim, so write them as plain prose and bullets: no
Markdown links, headings or emphasis, none of which Play renders.

See `docs/android-release.md`.

## 1.0.2+11

Fixes for meal templates:

- Meal Templates no longer crash when you open them.
- Snack templates now appear in the Food tab after you log them.
- Gram portions work again on templates that had been synced.

Templates affected by any of these are repaired automatically the next time
they load — nothing to redo by hand.
