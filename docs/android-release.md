# Releasing to Google Play

`.github/workflows/android-release.yml` builds the signed app bundle and
uploads it to Google Play. Once the secrets below exist, releasing is:

```bash
# bump `version:` in fittnes_tracker/pubspec.yaml first, e.g. 1.0.3+12
git tag v1.0.3
git push origin v1.0.3
```

The workflow checks the tag against `pubspec.yaml` and fails immediately if
they disagree, so a forgotten version bump costs seconds rather than a
confusing rejection from Play.

## Two rules Play enforces that bite hardest

- **`versionCode` must increase on every upload, forever.** It comes from the
  `+N` suffix in `pubspec.yaml` (`1.0.2+11` → `11`). Reusing a number is
  rejected. Numbers are burned even by uploads you later discard.
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

## Not covered

- **iOS / App Store.** This workflow is Android only. iOS needs a macOS
  runner, an Apple Developer account, certificates and provisioning profiles,
  and upload via `altool`/Fastlane — a separate piece of work.
- **Release notes.** The upload action can send changelogs from
  `distribution/whatsnew/whatsnew-<locale>`. Add that directory if you want
  notes attached automatically; otherwise edit them in the Console.
