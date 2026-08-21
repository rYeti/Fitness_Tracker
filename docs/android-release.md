# Releasing to Google Play

`.github/workflows/android-release.yml` builds the signed app bundle and
uploads it to Google Play. Once the secrets below exist, releasing is:

```bash
# 1. bump `version:` in fittnes_tracker/pubspec.yaml, e.g. 1.0.2+11 -> 1.0.3+12
# 2. add a `## 1.0.3+12` section to CHANGELOG.md  — the engineering record
# 3. add a `## 1.0.3+12` section to PLAY_NOTES.md — what users read on Play
git commit -am "Release 1.0.3+12"
git tag v1.0.3
git push origin main v1.0.3
```

All three edits are mandatory, and the workflow's preflight step checks them
before installing anything, so a forgotten one costs seconds rather than a
confusing rejection from Play.

## The three files a release touches

### `fittnes_tracker/pubspec.yaml` — the version, and the only place it lives

```yaml
version: 1.0.3+12
#        ^^^^^ versionName    ^^ versionCode
```

`android/app/build.gradle.kts` does **not** need editing: it sets
`versionCode = flutter.versionCode` and `versionName = flutter.versionName`,
both of which the Flutter Gradle plugin derives from that one line. Same for
iOS. Change it in `pubspec.yaml` and nowhere else.

The git tag carries the version name only — `1.0.3+12` is tagged `v1.0.3`. The
`+12` is not part of the tag, but it still has to increase (see below).

### `CHANGELOG.md` — the engineering record

The full account of what changed, at whatever length it takes. Nothing here is
published anywhere, so there is no limit on it; the preflight step only checks
that a `## <version>` section exists, as a guard against releasing with no
notes written at all.

### `PLAY_NOTES.md` — the blurb users read on the store listing

The workflow extracts the section whose heading is exactly the full pubspec
version, `+buildNumber` included, and publishes it verbatim as the `en-US`
release notes:

```markdown
## 1.0.3+12

- Fixed the calorie ring not refreshing after editing a meal.
```

Two rules the preflight step enforces:

- **The section must exist, keyed by the exact version.** This is what stops a
  release from silently shipping the previous version's notes — a stale blurb
  simply won't be found.
- **It must fit in 500 characters** — Play's per-locale limit. The check is a
  hard failure rather than a truncation, because truncating cuts a sentence in
  half in front of real users. If a blurb is over, cut it down; the detail it
  loses is already in `CHANGELOG.md`.

Play renders the notes as plain text, so write prose and bullets — Markdown
links, headings and emphasis all show up as literal punctuation.

To publish notes in more locales, write additional `whatsnew-<locale>` files;
the workflow currently generates only `whatsnew-en-US`, from `PLAY_LOCALE`.

## Two rules Play enforces that bite hardest

- **`versionCode` must increase on every upload, forever.** It comes from the
  `+N` suffix in `pubspec.yaml` (`1.0.2+11` → `11`). Reusing a number is
  rejected. Numbers are burned even by uploads you later discard — including
  ones you upload as a draft and never roll out.
- **The upload key can never change.** If the keystore is lost, no future
  update can be published to the existing listing without Google's key-reset
  process. Keep the `.jks` backed up somewhere other than CI.

## Where releases land

A tag push publishes to the **internal** track — visible to internal testers
within minutes, no review, not public. Promote to production from the Play
Console when you're happy.

To target another track directly, run the workflow manually
(Actions → Android Release → Run workflow) and pick the track and status.
Nothing auto-ships to production.

## Required repository secrets

Settings → Secrets and variables → Actions.

| Secret | What it is | |
| --- | --- | --- |
| `KEYSTORE_BASE64` | The upload keystore, base64-encoded | required |
| `KEYSTORE_PASSWORD` | Its store password | required |
| `KEY_ALIAS` | Key alias inside the keystore | required |
| `KEY_PASSWORD` | Password for that key | required |
| `PLAY_SERVICE_ACCOUNT_JSON` | Service-account JSON, pasted whole | optional — see below |

The names are exact — the workflow reads these and only these. The four signing
secrets carry no `ANDROID_` prefix, which is the mismatch that made the first
release attempt fail with "not set" against secrets that existed all along.

### Encoding the keystore

Must be one line with no wrapping, or the base64 decode in CI fails:

```bash
base64 -w0 upload-keystore.jks   # Linux
base64 -i upload-keystore.jks    # macOS
```

The values must match what's in your local `fittnes_tracker/android/key.properties`
(gitignored, and it should stay that way — CI regenerates it from these secrets
and deletes it afterwards).

### Service account for Play (to publish automatically)

Only needed to skip the manual upload described above.

1. Play Console → Setup → API access → link a Google Cloud project.
2. Create a service account in that project, then create a **JSON key** for it.
3. Back in Play Console, grant it access to this app with the
   *Release manager* role (or at minimum "Release to testing tracks" and
   "Release to production").
4. Paste the entire JSON file into `PLAY_SERVICE_ACCOUNT_JSON`.

Permissions can take a few minutes to propagate; a fresh service account often
fails its first run with a 401.

## Running without Play API access

`PLAY_SERVICE_ACCOUNT_JSON` is optional. Without it the workflow still runs the
tests, builds and signs the bundle, and attaches it to the run as the
**app-release-aab** artifact — it just skips the upload, and says so in the run
summary rather than looking like it published. Download the artifact, upload it
in the Play Console, and paste the notes from `PLAY_NOTES.md` into the release.

That is not only a fallback. **Google Play refuses API uploads for an app whose
first bundle has never been uploaded through the Console by hand**, so this is
the only way the first release of `com.forgeform.app` can happen. Set the
service account up afterwards; the workflow starts publishing on its own the
moment the secret exists, with no change to the file.

## Troubleshooting

### `Repository secret ... is not set`

A secret of that exact name is not readable from this workflow. Nothing is
wrong with the triggers — the workflow runs fine on a manual dispatch; it just
has nothing to sign with. In Settings → Secrets and variables → Actions, check:

- **The name matches the table above exactly**, including case and prefix. A
  secret named something close but not identical is invisible to the workflow,
  which is what happened on the first attempt: the repository held
  `KEYSTORE_BASE64` while the workflow asked for `ANDROID_KEYSTORE_BASE64`.
- They are under **Secrets**, not **Variables** — separate tabs, and a value in
  the wrong one reads back as empty.
- They are **repository** secrets, not **environment** secrets. An environment
  secret is only visible to a job that declares `environment:`, which this job
  does not; it would read back empty here.
- The run was on this repository and not a fork. Secrets are never passed to
  workflow runs from a forked repository.

Repository secrets are available to every branch and tag, so where you run the
workflow from does not matter.

### The workflow doesn't run when I push to `main`

That's deliberate, not a fault: every upload permanently burns a `versionCode`
and testers see the build immediately, so releasing is an explicit act. Push a
`v*` tag, or use Actions → Android Release → Run workflow. `deploy.yml` is the
one that ships on every push to `main`, and it only ships the API.

### `Package not found` or `401` from the Play upload step

Either the app has never had a bundle uploaded through the Console by hand (see
"Running without Play API access"), or the service account's permissions
haven't propagated yet. A fresh service account often fails its first run.

### The run was green but nothing appeared on Play

Check the run summary. With no `PLAY_SERVICE_ACCOUNT_JSON` secret the workflow
builds and signs but does not upload, which is a warning rather than a failure
— the signed bundle is waiting in the run's artifacts.

## Not covered

- **iOS / App Store.** This workflow is Android only. iOS needs a macOS
  runner, an Apple Developer account, certificates and provisioning profiles,
  and upload via `altool`/Fastlane — a separate piece of work.
- **Localised release notes.** Only `en-US` is generated, from `PLAY_NOTES.md`.
  Other locales fall back to whatever the Console has.
