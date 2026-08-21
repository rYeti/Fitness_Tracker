# Releasing to Google Play

`.github/workflows/android-release.yml` builds the signed app bundle and
uploads it to Google Play. Once the secrets below exist, releasing is:

```bash
# 1. bump `version:` in fittnes_tracker/pubspec.yaml, e.g. 1.0.2+11 -> 1.0.3+12
# 2. add a `## 1.0.3+12` section to CHANGELOG.md — those are the Play notes
git commit -am "Release 1.0.3+12"
git tag v1.0.3
git push origin main v1.0.3
```

Both edits are mandatory, and the workflow's preflight step checks them before
installing anything, so a forgotten one costs seconds rather than a confusing
rejection from Play.

## The two files a release touches

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

### `CHANGELOG.md` — the release notes Play shows

The workflow extracts the section whose heading is exactly the full pubspec
version, `+buildNumber` included, and publishes it as the `en-US` release
notes:

```markdown
## 1.0.3+12

- Fixed the calorie ring not refreshing after editing a meal.
```

So the heading has to match `version:` character for character. Two rules the
preflight step enforces:

- **The section must exist.** A version bump with no patch notes fails rather
  than publishing a release with blank notes.
- **It must fit in 500 characters** — Play's per-locale limit. The check is a
  hard failure rather than a truncation, because truncating cuts a sentence in
  half in front of real users. Keep the section to user-visible highlights; the
  longer engineering detail belongs in the commit history.

Note that some older sections in `CHANGELOG.md` are over that limit, so they'd
need trimming before they could be released as-is. Release notes are only ever
read from the section matching the version being released, so past sections are
left alone.

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

| Secret | What it is |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | The upload keystore, base64-encoded |
| `ANDROID_KEYSTORE_PASSWORD` | Its store password |
| `ANDROID_KEY_ALIAS` | Key alias inside the keystore |
| `ANDROID_KEY_PASSWORD` | Password for that key |
| `PLAY_SERVICE_ACCOUNT_JSON` | Service-account JSON, pasted whole |

### Encoding the keystore

Must be one line with no wrapping, or the base64 decode in CI fails:

```bash
base64 -w0 upload-keystore.jks   # Linux
base64 -i upload-keystore.jks    # macOS
```

The values must match what's in your local `fittnes_tracker/android/key.properties`
(gitignored, and it should stay that way — CI regenerates it from these secrets
and deletes it afterwards).

### Service account for Play

1. Play Console → Setup → API access → link a Google Cloud project.
2. Create a service account in that project, then create a **JSON key** for it.
3. Back in Play Console, grant it access to this app with the
   *Release manager* role (or at minimum "Release to testing tracks" and
   "Release to production").
4. Paste the entire JSON file into `PLAY_SERVICE_ACCOUNT_JSON`.

Permissions can take a few minutes to propagate; a fresh service account often
fails its first run with a 401.

## First upload has to be manual

Google Play will not accept an API upload for an app whose first bundle has
never been uploaded through the Console. If `com.forgeform.app` has had at
least one manual release, this doesn't apply.

## Troubleshooting

### `ANDROID_KEYSTORE_BASE64 is not set` / `Repository secret ... is not set`

The secret does not exist in this repository. This is not related to the
workflow's triggers — the workflow runs fine on a manual dispatch; it just has
nothing to sign with. Check, in Settings → Secrets and variables → Actions:

- The secrets are under **Secrets**, not **Variables** — they are separate tabs
  and a value in the wrong one reads back as empty.
- They are **repository** secrets, not **environment** secrets. An environment
  secret is only visible to a job that declares `environment:`, which this job
  does not; it would read back empty here.
- The names match the table above exactly, including case.
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
"First upload has to be manual"), or the service account's permissions haven't
propagated yet. A fresh service account often fails its first run.

## Not covered

- **iOS / App Store.** This workflow is Android only. iOS needs a macOS
  runner, an Apple Developer account, certificates and provisioning profiles,
  and upload via `altool`/Fastlane — a separate piece of work.
- **Localised release notes.** Only `en-US` is generated, from `CHANGELOG.md`.
  Other locales fall back to whatever the Console has.
