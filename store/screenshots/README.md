# Store screenshots — runbook

`capture-app.mjs` drives the **real Flutter web bundle** in a real browser,
signed in as the seeded trainee, and photographs the actual screens. The PNGs
in `out/` are captures of the running app, not artwork.

## The whole stack, from nothing

Four processes have to be up. The app is local-first — every trainee screen
reads a drift/sqlite database on the device, and a fresh browser profile starts
that database empty. What fills it is `SyncService.pullAll()` on sign-in. So
there is no shortcut past the API: no server, no data, no screenshots.

```bash
# 1 — database
pg_ctlcluster 16 main start
su postgres -c "psql -c \"CREATE USER forge WITH PASSWORD 'forge' SUPERUSER;\""
su postgres -c "createdb -O forge forgeform"

# 2 — API on :5080 (applies migrations on boot)
cd FitTracker.Api
export ConnectionStrings__DefaultConnection="Host=127.0.0.1;Port=5432;Database=forgeform;Username=forge;Password=forge"
export Jwt__Key="review-only-signing-key-not-a-secret-0123456789abcdef0123456789abcdef"
export Jwt__Issuer=ForgeForm Jwt__Audience=ForgeForm
export Cors__AllowedOrigins__0="http://127.0.0.1:4173"
export ASPNETCORE_URLS="http://127.0.0.1:5080"
dotnet run --no-launch-profile &

# 3 — seed it (the repo's own seeder; do not invent fixture data)
node e2e/tools/seed-review-data.mjs --api http://127.0.0.1:5080

# 4 — build the bundle pointed at that API, and serve it
cd fittnes_tracker
flutter build web --release --no-web-resources-cdn \
  --dart-define=FORGE_API_URL=http://127.0.0.1:5080/
node ../e2e/tools/serve-web.mjs &        # :4173

# 5 — top up the account so Progress has history, then capture and frame
cd ../store/screenshots
node seed-screenshot-extras.mjs --api http://127.0.0.1:5080
node capture-app.mjs     # photographs the app      -> out/ios, out/play
node compose.mjs         # frames them + Play assets -> out/store/ios, out/store/play
```

`compose.mjs` also emits the two Play assets that are not screenshots: the
mandatory 1024×500 feature graphic and the 512×512 icon.

`out/store/` is what gets uploaded. `out/ios` and `out/play` are the bare
captures it is built from — keep them, they are the evidence that the frames
contain real app pixels.

`--no-web-resources-cdn` is required, not optional: without it the bundle
fetches CanvasKit from `gstatic.com` at boot and never starts on a machine that
cannot reach it. `--dart-define=FORGE_API_URL=` is the supported way to point a
build at a local API — never edit `serverUrlDefault`. Both rules come from
`docs/e2e-playwright.md`.

## Output

| Store | Slot | Pixels | Directory |
| --- | --- | --- | --- |
| App Store | iPhone 6.9" / 6.7" | 1290 × 2796 | `out/ios/` |
| Google Play | Phone | 1080 × 1920 | `out/play/` |

The CSS viewport times `deviceScaleFactor` lands exactly on each store's pixel
size (430×932 @3 and 360×640 @3), so nothing is ever resampled.

| # | File | Screen |
| --- | --- | --- |
| 1 | `01-food-day` | A logged day — calorie total, macro split, meals by category |
| 2 | `02-gym-today` | Today's scheduled session, ready to start |
| 3 | `03-progress-nutrition` | Progress → Nutrition over the selected range |
| 4 | `04-dashboard` | The daily overview |
| 5 | `05-food-search` | The food picker for one meal |
| 6 | `06-active-workout` | A set being logged — 82.5 kg × 8 |
| 7 | `07-progress-gym` | Workout frequency and streaks (captured, not composed — see below) |

## Four things that will bite you

**The browser locale.** Chromium here reports a locale `intl` cannot parse and
the app throws `Incorrect locale information provided` before it ever mounts
`<flutter-view>`. That surfaces only as a boot timeout, with the real cause in
a `pageerror` nobody is listening to. The context sets `locale: 'en-US'`.

**Shot order.** The Dashboard reads aggregates that are only correct once
`pullAll()` has finished writing the local database. Shooting it first — the
obvious order — photographs a dashboard of zeroes on a fully populated account.
It goes fourth, after three other screens have given the pull time to land.

**Pushed routes are a one-way door.** `page.goBack()` does not pop them, and the
food-search screen exposes *no* back control to the accessibility tree — its
entire semantics tree is the list of foods. The only reliable exit is a reload,
which is what `returnToShell` does. Shots that push a route are ordered last so
a failed exit cannot cost a tab-level shot.

**Nav tooltips land in the frame.** Clicking a destination leaves the pointer on
it, and Material shows the destination's tooltip — a grey pill floating above
the nav bar, in the screenshot. `unhover` parks the pointer at the top of the
viewport and waits for it to fade.

## Run it from a clean database

The top-up is idempotent where it can be, but the account it works on is not:
the base seeder adds 15 more scheduled workouts every time it runs, and meals
accumulate foods. Captures worth uploading come from a fresh database, seeded
once. That is why step 1 recreates it.

## Two things that will surprise you about the data

**The auth endpoint is rate limited to 5 requests a minute.** Running the base
seeder and the top-up back to back trips it, and so does polling the login route
in a `until` loop while waiting for it to clear — the poll spends the permits it
is waiting for. Wait, then run once.

**A capture session can outlive a UTC midnight.** Seed in the evening and by the
time the browser opens, "today" is a day nothing was seeded for: the Dashboard —
which reads today, and is store frame 1 — shows zeroes on an otherwise full
account. `seed-screenshot-extras.mjs` fills today explicitly for this reason.

## Still open, and honestly so

**Exercise Progress stays on "No workout data yet", and no amount of seeding
fixes it.** `SyncService` pushes `workoutSetTable` rows to the server and never
pulls them back — `_pullScheduledWorkouts` restores sessions and their
exercises, but nothing creates a local set row from a server one. A fresh
browser profile can only show sets it logged itself on that device.

That is a finding about the app, not about screenshots: **a user who reinstalls,
or signs in on a second device, gets their workouts, meals and weights back but
not their logged sets.** Exercise Progress and the "previous set" reference both
start empty. Worth fixing on its own merits; it is why `07-progress-gym` is
captured but is not one of the composed store frames.

**Today renders empty, and no amount of seeding fixes it either.**
`GET api/Meal/all` returns 4 meals with 7 food entries for today, exactly like
every other day, and the Food tab still shows "No foods added yet" for today
alone. Every earlier day renders correctly. Unconfirmed suspicion: the meal
shells the screen creates for the current day collide with the pulled rows in
`_deduplicateMealsByContent`, and the empty local row wins. That is why the
food-day capture steps back one day, and why the Dashboard — which reads today
and cannot be stepped back — is captured but not composed into a frame.

**The paywall's padlocks are visible** on the Progress range selector (All Time,
Custom). Truthful, and worth a deliberate decision: some teams prefer not to
lead with locked features in store artwork.

## Corrections to earlier notes in this file

`GET /api/Meal` returning 500 was **my malformed call**, not a defect in the
build: the route takes a required `?date=`, and omitting it bound
`0001-01-01`, which underflows `MealDayWindow.ForRange`. The endpoint now
answers a missing date with 400 (`MealController`, and
`MealControllerDateBindingTests`). The earlier note here implying the endpoint
was broken was wrong.

The Calorie Trend's flat line was the base seeder logging identical meals every
day, not a charting bug. The top-up now varies five of the last seven days.
