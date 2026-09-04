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

## Unreleased

Added vitamin and mineral tracking, with data for thousands of German staple foods. Trainers can pin the nutrients that matter for a client and track them against daily targets, and can now delete a client's whole workout plan, not just one day. Fixed vitamin/mineral amounts sometimes showing far smaller than they actually were, workout and plan deletes not always reaching the server, and adding a food to a meal template from Recently Added, which was greyed out and could only log to today.

## 1.0.2+20

Fixed a bug where chat messages sent from the Trainer Console could get stuck and never actually reach a client — most noticeably when messaging more than one client, or messaging a client who hadn't opened chat before. Messages should now always get through.

## 1.0.2+18

Fixed a bug where the Trainer Console could still show duplicate or already-deleted exercises and sets in a client's workout. Also made the exercise editor easier to use on a phone screen: the exercise list is no longer pushed off the bottom by other fields, and removing a set no longer occasionally shows the wrong value on a remaining one.

## 1.0.2+17

Trainers can now build and edit your workouts right from the Trainer Console — exercises, sets and reps — and notes your coach leaves on an exercise now show up in your workout screen. Also fixed a bug where the console could show a client duplicate meals, sessions, or exercises.

## 1.0.2+16

Fixed a bug where reinstalling the app or signing in on a new device could
leave gaps in your training and nutrition history: sets logged against an
exercise you had since swapped out of a workout, and meals that once
included a food you later deleted, would not come back. That history now
comes back correctly.

## 1.0.2+15

Your chat messages are now end-to-end encrypted. Messages are scrambled on your
device and can only be read by you and the person you are talking to — not by
our servers, and not by anyone with a copy of the database. Notifications still
show a preview, because your own phone unscrambles it.

There is no backup of your key, so if you reinstall or sign in on a new device,
older messages cannot be unscrambled there.

The food search now shows the foods you eat at that meal first.

## 1.0.2+14

The Trainer Console now opens far faster: it no longer reads a client's whole training history to draw the dashboard, and it loads only the section you are looking at. Your client list appears as soon as it is ready.

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
