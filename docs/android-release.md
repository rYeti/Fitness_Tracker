# Releasing to Google Play

`.github/workflows/android-release.yml` builds the signed app bundle and
uploads it to Google Play. Once the secrets below exist, releasing is:

```bash
# 1. write the notes under `## Unreleased` in CHANGELOG.md  — engineering record
# 2. write the notes under `## Unreleased` in PLAY_NOTES.md — what users read
git commit -am "Notes for the next release"
git push origin main
# 3. Actions -> Android Release -> Run workflow
```

You do **not** touch the build number. The workflow computes it, publishes,
and then commits the version and the stamped headings back — see
[Why the build number is CI's job](#why-the-build-number-is-cis-job) for what
went wrong when this was manual.

Both note sections are mandatory, and the preflight step checks them before
installing anything, so a forgotten one costs seconds rather than a confusing
rejection from Play.

The one thing still yours to decide is the version *name*: bump `1.0.2` to
`1.0.3` in `pubspec.yaml` when a release deserves it. Leave the `+N` alone.

## The three files a release touches

### `fittnes_tracker/pubspec.yaml` — the version, and the only place it lives

```yaml
version: 1.0.3+12
#        ^^^^^ versionName    ^^ versionCode — written by CI
```

The **name** is yours; the **build number** is a record of what last published,
written by the release workflow after a successful upload. Editing it by hand
does nothing useful: the next release is computed as one above the highest
`play/*` tag anyway, and `flutter build appbundle --build-number` overrides
whatever the file says.

`android/app/build.gradle.kts` does **not** need editing: it sets
`versionCode = flutter.versionCode` and `versionName = flutter.versionName`,
both of which the Flutter Gradle plugin derives from the pubspec line and the
`--build-number` flag. Same for iOS.

The git tag carries the version name only — `1.0.3+12` is tagged `v1.0.3`.

### `CHANGELOG.md` — the engineering record

The full account of what changed, at whatever length it takes. Nothing here is
published anywhere, so there is no limit on it; the preflight step only checks
that a non-empty `## Unreleased` section exists, as a guard against releasing
with no notes written at all.

### `PLAY_NOTES.md` — the blurb users read on the store listing

The workflow extracts the `## Unreleased` section and publishes it verbatim as
the `en-US` release notes:

```markdown
## Unreleased

- Fixed the calorie ring not refreshing after editing a meal.
```

Two rules the preflight step enforces:

- **The section must exist and be non-empty.** On a successful publish the
  workflow renames the heading to the version it went out as, so
  `## 1.0.3+12` is history — it is what those users are reading on the store
  right now. Nothing new belongs in a stamped section, and a release with
  nothing under `## Unreleased` fails instead of reshipping the last blurb.
- **It must fit in 500 characters** — Play's per-locale limit. The check is a
  hard failure rather than a truncation, because truncating cuts a sentence in
  half in front of real users. If a blurb is over, cut it down; the detail it
  loses is already in `CHANGELOG.md`.

Play renders the notes as plain text, so write prose and bullets — Markdown
links, headings and emphasis all show up as literal punctuation.

To publish notes in more locales, write additional `whatsnew-<locale>` files;
the workflow currently generates only `whatsnew-en-US`, from `PLAY_LOCALE`.

## Two rules Play enforces that bite hardest

- **`versionCode` must increase on every upload, forever.** Reusing a number is
  rejected. Numbers are burned even by uploads you later discard — including
  ones you upload as a draft and never roll out. This is the rule the workflow
  now handles for you: it releases one above the highest `play/*` tag, and
  tags the release it just published.
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

## Getting a release to production

As of this writing, no release from this workflow has ever gone straight to
production — every `play/*` tag was published to **internal**, either by a
tag push (which always targets `internal`) or by a manual dispatch that left
the track at its `internal` default. Production is still served by whatever
was last uploaded through the Play Console by hand.

Two ways to move a build forward:

- **Promote in the Console.** Release → Testing → Internal testing → the
  release you want → *Promote release* → pick the target track. This is a
  Console action; nothing in this repo does it for you.
- **Dispatch straight to production.** Actions → Android Release → Run
  workflow → set `track` to `production`. The build number is still computed
  automatically, so this is safe to do for any commit — it does not require a
  prior internal release of the same build.

**A track left un-promoted is not neutral — it ages.** Play requires an app's
`targetSdk` to clear an annual bar (the deadline lands **31 August**) to keep
being served to *new* installs; existing installs and updates are unaffected.
If production is left pointed at an old bundle while `targetSdk` moves forward
only on newer internal builds, production quietly falls out of compliance on
that date — the app stays listed and keeps updating existing users, and simply
stops appearing for anyone who doesn't already have it. There is no warning
inside this repo when that happens; the Play Console's Release → Overview
page and its policy-notification emails are the only place it shows up.
`app/build.gradle.kts` pins `targetSdk` explicitly for this reason, and the
release workflow logs the resolved value in its preflight step — check that
number against the one live on production, not just the one being built.

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

Only needed to skip the manual upload described above. Worth doing: the manual
prerequisite is already satisfied for this app, so this is all that stands
between a tag push and a release appearing on the internal track.

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

That's a working release path, not a broken one, and it's the right one while
the service account doesn't exist yet. It is also the only path for an app Play
has never seen: **Play refuses API uploads until one bundle has been uploaded
through the Console by hand.** `com.forgeform.app` has already had one, so that
prerequisite is behind us and the automated path is available as soon as the
secret is added — no change to the workflow, it starts publishing on its own.

One catch, and the run summary spells it out: a run that doesn't publish
records nothing, because nothing was burned. If you take the artifact and
upload it in the Console yourself, that `versionCode` **is** burned and the
repo has no idea. Record it by hand, or the next release will pick the same
number and be rejected:

```bash
git tag play/1.0.2+12 && git push origin play/1.0.2+12
```

and set `version: 1.0.2+12` in `pubspec.yaml`, renaming the `## Unreleased`
heading to `## 1.0.2+12` in both note files — exactly what the workflow would
have done.

## Troubleshooting

### `Version code N has already been used`

Play is refusing the upload because a bundle with that `versionCode` has
already reached it. Under the current workflow this should be impossible for a
run that publishes — the number comes from the `play/*` tags. It means one of:

- **The bundle was uploaded through the Console by hand** and nothing recorded
  it. Fix the record, then re-run:
  ```bash
  git tag play/1.0.2+12 && git push origin play/1.0.2+12
  ```
- **A publish succeeded but its stamping step failed.** The run will have gone
  red with an error that starts by saying the release shipped; do what it says.
- **The `play/*` tags weren't fetched.** Check that `actions/checkout` still
  has `fetch-depth: 0`; a shallow clone brings no tags, and the computed number
  falls back to `pubspec.yaml` + 1.

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

## Why the build number is CI's job

Written after three release runs built the same bundle and Play rejected two of
them. Line references are to the commit that introduced this section.

### What happened

On 21 August a release run succeeded. It built `1.0.2+11`, uploaded it to the
internal track, and published a three-bullet blurb about meal-template fixes.
That is the whole of the good news.

| Run | Version built | Outcome |
| --- | --- | --- |
| #5, Aug 21 18:08 | `1.0.2+11` | published to internal |
| #6, Aug 21 21:05 | `1.0.2+11` | `Version code 11 has already been used` |
| #7, Aug 22 15:59 | `1.0.2+11` | `Version code 11 has already been used` |

Between those runs, two more efforts landed on `main` — the Trainer Console
nutrition fixes and the Session Review filtering work. Both were released. Both
were rejected, each after a full ten-minute run: checkout, Java, Flutter, the
test suite, an R8 release build, a 97 MB bundle uploaded as an artifact, and
only then the one line from Play that mattered.

Nothing was broken. Every check passed, every test was green, the bundle was
signed correctly. The version is a string in a YAML file, so there was nothing
for the Dart analyzer or the compiler to disagree with, and no test can assert
against a number whose correctness is defined by a server at Google.

### The preflight step could not have caught it, by construction

That is the part worth sitting with, because the preflight step was written
*specifically* to catch release mistakes early, and it was thorough: it checked
that the version had a `+N`, that a `v*` tag matched it, that both note files
had a section for it, that the Play blurb fit in 500 characters, that all four
signing secrets existed, that the service-account JSON was really JSON.

Every one of those is a check of **the repo against itself**. The fact that
decided whether the upload would succeed — the set of `versionCode`s Google has
permanently burned — was never in the repo at all. The preflight step was
exhaustive within a boundary it did not know it had.

This generalises past releases: a validation step can only compare things it can
see. When correctness depends on state owned by something outside the process,
there are exactly two honest options — read that state, or record every
interaction with it locally so the record can be trusted as a proxy. Guessing,
or checking nine adjacent things very carefully, is not a third option.

We took the second. Every successful publish now pushes a `play/<version>` tag,
and preflight releases one above the highest of them:

```
play/1.0.2+12  play/1.0.2+13  play/1.0.3+14      ← what Play has taken
                                        │
                                        └── next release: 15
```

Querying the Play Developer API for the true highest `versionCode` was the
alternative, and it is strictly more correct: it also sees uploads made by hand
in the Console, which tags cannot. It was rejected for cost. It needs a
service-account JWT exchanged for an access token, an edit created and
abandoned on every run, and a network round-trip that can fail on a path where a
failure looks like a release failure. The tags are free, they live where the
release history already lives, and they cover the mistake that actually
happened. The one gap — a manual Console upload — is a documented two-line fix
above, and the run summary prints it whenever a run builds without publishing.

### The second bug, which nobody typed

There was a quieter failure underneath, and it is the more instructive one.

`CHANGELOG.md`'s `## 1.0.2+11` section held three bullets when run #5 published
it. By the time run #7 failed it held eleven. Over two days, three separate
pieces of work had been written into a section that was already on real users'
phones. `PLAY_NOTES.md` had the opposite problem: its `## 1.0.2+11` section was
never touched, so the store listing still described meal-template fixes while
the changelog claimed a Session Review overhaul under the same heading.

No one decided to do this. The heading was simply the newest one in the file,
which is exactly what "newest first" trains you to write under. The file gave
no signal — none is possible — that this particular heading had already shipped
and had become a historical record rather than a scratchpad.

So the fix is not "remember to add a new heading." It is to make the boundary
between *draft* and *published* something the process moves, not something a
person remembers:

```
   while you work        at publish time
   ──────────────        ───────────────
   ## Unreleased    ──►  ## 1.0.2+12     (renamed by the workflow, committed back)
                         ## 1.0.2+11     frozen; what those users have
                         ## 1.0.2+10     frozen
```

A published section no longer exists under the name anyone writes into, and the
name everyone writes into never has a version on it to make it look finished.

This also happens to be a stronger guard than the one it replaces. The old rule
— headings keyed to the exact full version — stopped a release *reusing* the
previous blurb, because a stale heading simply wouldn't be found. The new rule
stops that too (a published section has been renamed away), and additionally
stops the case the old rule allowed: writing new work into a heading that had
already gone out.

The `## Unreleased` convention is old and unglamorous, and there was a real
reason not to use it here — a section keyed to the exact version is a lovely,
self-evident guarantee. It stopped being available the moment CI started
computing the number, because a number invented at 16:04 cannot be in a heading
committed at 09:00. Automating one thing invalidated the mechanism protecting
another, and that connection was not obvious from either change on its own.

### The shape of the mistake

Three things worth carrying forward, none of them specific to Android:

1. **A number that must be unique against an external system should never be
   typed by a human.** The failure mode is not "someone was careless"; it is
   that the correct value is unknowable from where the person is standing.
2. **Validation is bounded by what it can observe.** Enumerate what a check
   step actually has access to before trusting it to be exhaustive — "the
   preflight covers releases" was true and useless.
3. **Append-only files with a live heading at the top get written into after
   they ship.** If a section becomes immutable at some moment, something
   automatic has to mark that moment. A convention that relies on noticing is
   not a convention.

And one operational note that falls out of the design: if the publish succeeds
but the stamp-back fails, the run goes **red with a message that begins by
saying the release shipped**. A green run that published and a red run that
published look nothing alike in a person's memory a week later, so the error
text carries the fact, not the exit code.

## Not covered

- **iOS / App Store.** This workflow is Android only. iOS needs a macOS
  runner, an Apple Developer account, certificates and provisioning profiles,
  and upload via `altool`/Fastlane — a separate piece of work.
- **Localised release notes.** Only `en-US` is generated, from `PLAY_NOTES.md`.
  Other locales fall back to whatever the Console has.
