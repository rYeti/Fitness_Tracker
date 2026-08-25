# Play release notes

The short, user-facing blurb shown on the Google Play store listing for each
release. Newest first.

`CHANGELOG.md` is the full engineering record and has no length limit; this
file is what users actually read, so keep each section to the handful of
changes someone would notice using the app.

Two rules the release workflow enforces:

- The blurb for the next release goes under `## Unreleased`, and publishing
  renames that heading to the version it went out as. A `## <version>` section
  is therefore what those users are reading on the store right now — never edit
  one, and never add to it. A release with nothing under `## Unreleased` fails
  rather than reshipping the last blurb.
- Each section must fit **500 characters** — Play's per-locale limit. Over that
  the release fails rather than being truncated mid-sentence in front of users.

Sections are published verbatim, so write them as plain prose and bullets: no
Markdown links, headings or emphasis, none of which Play renders.

See `docs/android-release.md`.

## 1.0.2+13

Trainer accounts now open the Trainer Console when you sign in or register,
instead of the tracker's dashboard. Your own training is still there under
"My training".

Trainer Console fixes:

- The Nutrition tab no longer lists every meal twice. Calorie totals are
  unchanged.
- Snacks now show the snack icon and sit between lunch and dinner.

## 1.0.2+12

Trainer Console fixes:

- Session Review no longer lists sessions from plans a client has moved off, or
  exercises that were removed from a workout, and set counts are no longer
  inflated. Adherence figures are correct again.
- The Nutrition tab loads again for every client, and shows the right day for
  clients outside UTC.
- Tap a meal to see every food in it with its own weight, calories and macros.

## 1.0.2+11

Fixes for meal templates:

- Meal Templates no longer crash when you open them.
- Snack templates now appear in the Food tab after you log them.
- Gram portions work again on templates that had been synced.

Templates affected by any of these are repaired automatically the next time
they load — nothing to redo by hand.
