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
node compose.mjs         # wraps them in store art  -> out/store/ios, out/store/play
```

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

## Still open, and honestly so

These are real captures of seeded review data, and two things about that data
are not yet right. Neither is a photography problem.

(`05-food-search` was on this list until
`claude/food-search-meal-organization-5m043l` merged. It now correctly shows
"Eaten at this meal" above "Other foods" — recaptured against main at
`30291b7`.)

**Progress → Gym still reads 1 total workout and a 0-day current streak.**
`seed-review-data.mjs` marks one session complete at `daysAgo(i - 2)` with
`i === 0` — two days in the *future*, which is why the 7-day window read zero
before. `seed-screenshot-extras.mjs` now posts eight more completed sessions
across the last ten days, and the tiles barely moved. The screen also still says
"No workout data yet — Complete Workouts" under Exercise Progress. The likely
reason is that these tiles count *logged sessions with sets*, not scheduled
workouts carrying `isCompleted: true`, but **I did not confirm that**, so treat
it as unfinished. That is why Progress → Gym is captured (`07-progress-gym`) but
is not one of the six composed frames.

**The Calorie Trend renders as a flat line at 2186.** The base seeder logs an
identical set of meals every day. `seed-screenshot-extras.mjs` adds a different
extra snack on five of the last seven days and the API accepts them, but the
chart is unchanged. Cause not established — `GET /api/Meal` returns 500 on this
build, which is itself worth a look, and it blocked the obvious diagnostic.

**The paywall's padlocks are visible** on the Progress range selector (All Time,
Custom). Truthful, and worth a deliberate decision: some teams prefer not to
lead with locked features in store artwork.
