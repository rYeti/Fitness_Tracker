# Notifications: setup, and why it is shaped this way

Two different mechanisms, one operating-system permission, and a handful of
places where doing the obvious thing is wrong. This covers what to configure and
what not to copy from Google's own instructions.

For the design reasoning behind chat push — why it is a second delivery path,
why the send is not awaited, why the token is keyed the way it is — see
`docs/chat-architecture.md` part three.

---

## The two mechanisms

| | Local notifications | Push notifications |
| --- | --- | --- |
| Package | `flutter_local_notifications` | `firebase_messaging` |
| Raised by | the app itself, on this device | our server, via FCM |
| Works when the app is closed | only for something scheduled earlier | yes — this is the whole point |
| Used for | the workout-plan-expiry reminder | chat messages |
| Needs Firebase | no | yes |

They are unrelated in code and **share one thing**: on Android 13+ both need the
`POST_NOTIFICATIONS` runtime permission. One grant covers both, one denial
silences both.

---

## Setting up Firebase

### What you need from the console

Exactly two things. Everything else on Google's setup page is either already done
in this repo or wrong for it.

1. **`google-services.json`** — Firebase console → add an Android app → package
   name **`com.forgeform.app`**.

   That must match `applicationId` in `android/app/build.gradle.kts` exactly.
   A mismatch is not a warning: `Firebase.initializeApp()` throws at launch.

   Save it to `fittnes_tracker/android/app/google-services.json` and **commit
   it**. It is client configuration, it ships inside the APK, and it contains no
   secret. Committing it is what lets CI and every other machine build.

2. **A service-account key** — Project settings → Service accounts → *Generate
   new private key*.

   **This one is a secret.** It can send notifications as your project. Base64 it
   and store it in GitHub, never in the repo:

   ```
   base64 -w0 service-account.json
   ```

   Repository secrets (Settings → Secrets and variables → Actions):

   | Secret | Value |
   | --- | --- |
   | `FCM_SERVICE_ACCOUNT_BASE64` | the base64 blob above |
   | `FCM_PROJECT_ID` | the project **id**, not the project number |

Nothing in Firebase Auth, Firestore, Analytics, Crashlytics or Hosting is used.
Only Cloud Messaging.

### Why base64

`deploy.yml` passes every setting to Cloud Run in one `--set-env-vars` string,
and **`gcloud` splits that on commas**. A service-account JSON is full of commas
and would arrive as a dozen malformed variables. Base64 has no commas.

This is the same reason the CORS origins are passed as indexed keys rather than a
list — the constraint was already documented in that workflow before push existed.

### Do not follow Google's Gradle steps

The console walks you through three Gradle edits. All three are wrong here,
because they assume a native Android app and an older project layout:

| Google says | Here |
| --- | --- |
| Add the plugin to the **project-level** `build.gradle.kts` | Already declared in `android/settings.gradle.kts` — this repo uses Flutter's `pluginManagement` layout and has no project-level buildscript |
| Add `id("com.google.gms.google-services")` to the app's `plugins {}` block | **Would break the build.** It is applied *conditionally* in `android/app/build.gradle.kts`, guarded on the config file existing |
| Add the Firebase BoM and `firebase-analytics` to `dependencies` | **Wrong for Flutter.** `firebase_core` and `firebase_messaging` bring their own native dependencies; adding these by hand pulls in Analytics and invites version conflicts |

**The conditional apply is load-bearing.** `com.google.gms.google-services` fails
the build outright when `google-services.json` is missing. Applied
unconditionally, nobody without that file could build the Android app at all —
and no workflow builds Android on a pull request, so the breakage would first
appear when someone cut a release tag.

---

## When the permission is asked

At **sign-in**, from `PushService.registerForCurrentUser()`.

Not at startup, and the reason is worth keeping. `init()` runs from `main()`, so
requesting there prompts a brand-new install on its very first launch — before
sign-in, with nothing on screen to explain what the notifications are for. That is
the same mistake `NotificationService` was restructured to stop making: it used to
initialise from `main()` and raise the dialog there, and because that call was
awaited, a first launch sat on the splash screen until the user answered.

So:

- `init()` is permission-free and safe to call at startup.
- `registerForCurrentUser()` asks, then gets the token, then registers it.
- The plan-expiry reminder asks again in `schedulePlanExpiryWarning()` for anyone
  who is somehow still ungranted — the OS shows the dialog once per install, so a
  second call is harmless.

Denial is a normal outcome and nothing depends on it. A token is still obtained
and still registered, so switching notifications back on in system settings
starts them working with no further action from the app.

---

## Running without Firebase

Every layer degrades instead of failing, which is deliberate — the config file is
per-developer setup, not something the repo can guarantee.

| Layer | Without configuration |
| --- | --- |
| Gradle | plugin not applied, build succeeds, logs a line saying why |
| `PushService.init()` | catches, leaves `isAvailable` false, returns |
| `main.dart` | skips the FCM wiring entirely — **this guard matters**, wiring against an uninitialised Firebase throws |
| API | registers `DisabledPushSender`, logs a startup warning, serves everything else normally |
| Chat | works end to end. It just does not notify. |

Web takes the same path on purpose: web push needs a service worker and a VAPID
key, and the Trainer Console must not trip over their absence.

---

## Verifying it works

In order, because each step rules out a different thing:

1. **Before adding `google-services.json`**, `flutter run` still builds and
   starts. That is the degradation above working.
2. After adding it, `flutter run` and sign in. The permission dialog appears **at
   sign-in**, not at first launch.
3. Force-close the app. Have the other account send a message. The notification
   arrives with the sender's name and a preview, and tapping it opens chat.
4. With the thread open, a new message raises **no** banner — only the bubble and
   the tab badge. The OS suppresses it for a foregrounded app, and the in-app
   badge is the notification.
5. Sign out. A message to that account produces nothing on this device.
6. After deploying, the Cloud Run boot log does **not** contain
   `no Fcm:ServiceAccountJsonBase64 configured`.

Step 6 is the one that is easy to skip and easy to get wrong: everything else can
pass while production is silently mute, because the client half and the server
half are configured in completely different places.

---

## iOS

Not set up. iOS has never been built in this repo — the bundle id is still
`com.example.fittnesTracker`, the display name is still "Fittnes Tracker", there
is no Podfile, and the deployment target is 12.0 where Firebase needs 15+.

The server and Dart layers are already platform-agnostic, so adding iOS later is
client configuration plus an APNs key uploaded to the same Firebase project — not
a redesign. `DevicePlatform` on the server already has the enum value waiting.
