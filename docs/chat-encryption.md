# Chat encryption: what the database is no longer allowed to know

Chat message bodies used to be plaintext in Postgres, and a 140-character
preview of each one was handed to Google on its way to a lock screen. This
document is about closing both, what closing them cost, and the handful of
decisions that are not obvious from reading the diff.

It assumes `docs/chat-architecture.md`. The outbox, the client-generated
`messageId`, the ack, and the two delivery paths are all load-bearing here, and
none of them is re-explained.

Line references are to the commit that introduced this document.

---

## 1. Nothing was broken, which is why nothing found it

Every other document in this directory opens with a defect. This one cannot,
and that is the point worth starting on.

The chat feature worked. Fifty-two backend tests and ninety-odd Dart tests
passed. The schema was sound, the ack was returned, the outbox replayed, the
timestamps parsed as instants. `ChatMessages.Body` was an unbounded `text`
column holding exactly what the trainer typed, and not one test, type, or
compiler pass had an opinion about that — because there is nothing incorrect
about storing a string in a string column.

> **A privacy boundary is not a correctness property, and no type system checks
> one.** A green suite tells you the data arrived intact. It has no vocabulary
> for who else could read it on the way.

That asymmetry shows up again in what the old code was proud of.
`PushNotificationService.Preview` truncated a body to 140 characters, with a
careful comment explaining that FCM caps a payload at 4KB and a lock screen shows
two lines regardless. It was thoughtful, well-tested code whose entire function
was to take message content and give it to a third party. The test named
`A_message_with_no_body_still_says_something` asserted the server wrote
`"Sent a message"` into an empty preview — a test whose premise is that the
server reads the message.

The whole change is smaller than it looks in the diff, and the interesting part
is not the cryptography. It is that four separate places had quietly grown a
dependency on the server being able to read a message, and only one of them
looked like it.

| Where | What it read the body for | What it does now |
| --- | --- | --- |
| `ChatService.ToDto` | Copying it to the DTO | Copies the ciphertext, unchanged |
| `ChatRepository.GetConversationsAsync` | The conversation-list preview | Moves the ciphertext; the client decrypts it |
| `ChatHub.SendMessage` → `ChatPushDispatcher` | Handing it to the push service | Forwards the envelope, unread |
| `PushNotificationService.Preview` | Writing the notification text | Deleted; the recipient's device writes it |

---

## 2. The technique, and the one thing it is not

Each user holds an ECDH P-256 key pair. The private half is generated on the
device, written to the platform keystore, and never sent anywhere. The public
half is published through `api/chat/keys`. To talk to someone, a device derives
a shared secret from its own private key and the other party's public key, and
encrypts each message with AES-256-GCM under a fresh IV.

The property that makes this cheap is that both sides derive the *same* secret
from opposite halves. A message is encrypted once and both the sender and the
recipient can read it — no second copy encrypted to yourself, no per-recipient
fan-out, no envelope layer. For a product where every conversation has exactly
two participants, that is a very large simplification for free.

What it is *not* is a ratchet. Signal-style protocols derive a new key per
message so that compromising one key does not expose the conversation before it.
This does not: one long-lived pair of keys protects every message between two
people for as long as neither reinstalls. That is a real and permanent
difference in what an attacker gets from a stolen device, and it is the
deliberate shape of the technique the feature was asked for.

Two smaller deviations from textbook practice are worth recording explicitly,
because they look like oversights and are not:

**The derived bits go straight into the AES key.** `deriveBits(256, peerKey)`
returns the raw X coordinate of the ECDH shared point, and
`webcrypto_chat_crypto.dart` feeds it to `AesGcmSecretKey.importRawKey` as-is.
The textbook step here is a KDF — HKDF over the shared secret with a salt and an
info string — because a curve point's X coordinate is not a uniformly random
256-bit value. In practice, for P-256 into AES-GCM, the gap is theoretical. The
reason it is not closed is compatibility: adding a KDF changes every derived key
at once, so it is a flag day for every message already sent. If it is ever
worth doing, it is worth doing as `ChatEncryption.ecdhP256AesGcm` version 2,
with version 1 kept readable — which is exactly what the version field exists
for.

**There is no additional authenticated data.** Binding each ciphertext to its
`messageId` via AES-GCM's `additionalData` would stop the server moving a
ciphertext to a different message, and costs almost nothing on the send path.
It was left out because the conversation-list preview does not carry a message
id — `ChatConversationDto` has no room for one — so the AAD would have to be
either absent or different there, and a scheme where the AAD is sometimes
skipped is worse than one where it never applies.

---

## 3. The client does not know who it is

This is the constraint that shaped key storage, and it is entirely local to this
codebase.

`docs/chat-architecture.md` §5 explains that the Flutter client has no user id.
`AuthResponseModel` carries a token, a username, an email, names and an expiry —
no id. That is why `ThreadMessage.isMine` is computed as
`senderId != otherPartyId`: a thread has two parties, so "not them" is "me", and
the whole repository layer stays role-agnostic as a result.

It is an elegant trick, and it makes the obvious key-storage design impossible.
The obvious design files the private key under the owning user — `chat_identity_key:<userId>` —
so that signing in as somebody else on the same device cannot pick up the
previous account's identity. There is no `userId` to file it under.

Three ways out, and the one taken:

| Option | Cost |
| --- | --- |
| Key by username, from the cached user JSON | Works today, silently wrong the day usernames become editable |
| Decode the JWT's `sub` claim on the client | Puts token parsing in the chat feature, and a second place that must agree with the server about claim shape |
| Ask the server | One round trip, at a moment that already makes several |

`GET api/chat/keys/me` returns `{ userId, publicKeyJwk }`. The `publicKeyJwk`
half is what the route looks like it is for; the `userId` half is what it is
actually for.

The storage layout that falls out of this is worth stating, because it is not
what the plan for this work originally said:

```
chat_identity_key       the private JWK          ← the background isolate reads this
chat_identity_owner     which account it belongs to
chat_identity_public    the matching public JWK
chat_peer_key:<id>      one cached peer public key per conversation
```

The private key is stored under a **fixed** name, not a per-user one, with the
owner recorded beside it. `ChatKeyStore.ensureRegistered` compares that owner
against the id the server just reported and wipes everything on a mismatch. This
is not merely equivalent to keying by user id — it is better, for a reason that
only became visible when the push work landed: the background isolate has to
find the private key with no network and no way to ask who is signed in. A
storage key that depends on an answer only the server has is a storage key that
isolate cannot compute.

> **When a lookup key depends on a value you have to fetch, you have made the
> cache useless to anyone who cannot fetch.**

### Why the key survives sign-out

`SecureTokenStorage.clear()` deletes the token, the refresh token and the cached
user. It deliberately does not touch any of the four entries above.

If it did, signing out and back in on the same device — the most ordinary thing
a user does — would generate a new key pair, publish it, and render every
message that account had ever exchanged permanently unreadable. Sign-out is not
a request to destroy your correspondence.

The cost is a shared device: someone who signs out leaves their private key in
the keystore. It is not reachable by the next account, which regenerates on the
owner mismatch, and it is not reachable by another app. But it is there, and the
honest description is that this design protects your messages from the server
and from the network, not from someone holding your unlocked phone.

---

## 4. Decryption returns null, and that is a feature

`ChatCrypto.decrypt` never throws. A wrong key, a rotated peer, malformed
base64, a GCM tag that does not verify — all of them return `null`.

The reason is `ChatRepository.loadThread`, which maps over a whole history. A
throw halfway down that list is not one unreadable message; it is an empty
conversation and an error state, because the exception propagates out of the
loop and into the screen's error handler. One bad row would cost the user every
row.

This is the same decision `ChatTimestamps.parseInstant` made, for the same
reason, and it is worth noticing that the second instance was easier to get
right because the first one existed. `docs/chat-timestamps.md` §3 argues that a
timestamp that cannot be parsed should come back as `null` rather than as the
year 1, so that one malformed `sentAt` cannot fail `loadThread`. Encryption
arrived at an identical boundary — the same method, the same list, the same
blast radius — and the precedent made it a five-second decision instead of a
debugging session.

There is a second reason not to distinguish the failures. Telling a caller
*which* way decryption failed tells an attacker the same thing, and there is
nothing different for the app to do about any of them. The user gets one
message, because there is one situation: this device cannot read this.

### The one failure that is recoverable, and how it recovers

Most decryption failures are permanent: the key that could read that body does
not exist anywhere any more. One is not, and it is the one that would otherwise
be worst.

When a peer reinstalls, they publish a new public key. This device is still
holding the one it cached, so *every* message they send from that moment on
fails to decrypt — not one bubble, all of them, for ever. Nothing else in the
system would go and look, because the cached key is not stale in any way a cache
can detect. It is simply wrong.

So `_decrypt` retries exactly once per peer per session: on the first failure it
calls `ChatCrypto.forget`, which drops both the derived secret and the stored
public key, and tries again against a freshly fetched one. `ChatCrypto.forget`
has to clear both layers — dropping the derived secret while leaving the stale
public JWK behind re-derives the identical useless secret, which is a cache
invalidation that looks like it worked.

The bound matters as much as the retry. The common cause of a decryption failure
is a message genuinely encrypted to a key nobody has any more, and retrying per
message would turn scrolling through old history into one network round trip per
bubble.

### The eighth screen state

`docs/chat-architecture.md` §10 catalogues seven states a chat screen has. There
are eight now. `ThreadMessage.isUndecryptable` draws a muted, italic
"Message can't be decrypted on this device" behind a lock icon.

Two details in it are not decoration:

The flag is separate from `body == null`. A null body already meant something —
an attachment-only message, in the schema if not yet in the UI — and a message
with nothing to say is not the same as a message that cannot be read. So
`ChatMessage.decrypted` sets the flag only when a body went in and nothing came
out.

The same words go into the `Semantics` value. A screen reader gets neither the
lock icon nor the italics, so a bubble whose semantic value is the empty string
presents an unreadable message as an empty one. This is the repo's
colour-is-never-the-only-signal rule arriving somewhere it was not written for —
the general form is that *every* purely visual signal needs a spoken counterpart,
and italics and icons are exactly as invisible to a screen reader as colour is.

`ConversationRow` needed the same treatment and has a third case rather than a
second. A row whose preview it cannot decrypt must not say "No messages yet",
because something *was* said. It is told apart from a genuinely empty thread by
the timestamp: a conversation that has never been used has no `lastMessageAt`
either.

---

## 5. Re-encrypting on replay is correct, not merely tolerable

`ChatRepository.replayPending` resends a pending outbox row with its original
`messageId`. The outbox stores the **plaintext**, and replay encrypts it again
from scratch rather than resending a stored ciphertext.

The first reaction to that is usually that it is wasteful, and the second is
that it might be dangerous. It is neither, and there are three separate reasons
it is the right way round:

1. **An IV must never be reused with the same key.** AES-GCM is not merely
   weakened by IV reuse; it is broken by it, and the failure is invisible —
   both messages still decrypt perfectly. Storing one envelope and resending it
   is safe only as long as nothing ever re-encrypts the same row, which is a
   property no one will remember to preserve.
2. **The peer may have reinstalled between the two attempts.** The first attempt
   encrypted to a key that no longer exists. Re-encrypting picks up the key they
   actually hold now; resending the stored ciphertext would faithfully deliver
   something unreadable.
3. **The server already decided this is safe.** `ChatRepository.AddMessageAsync`
   dedupes on `(Id, TrainerClientId)` and returns the stored row. Whichever
   attempt landed is the one kept, and a second attempt carrying a different
   ciphertext is simply discarded.

This is the outbox's original argument — the client cannot tell "never arrived"
from "arrived, ack lost", so it always resends and lets the server decide —
arriving intact in a place it was not written for. The encryption change did not
need a new delivery guarantee. It needed the existing one to still be true, and
it is.

### The ack carries ciphertext

One trap, and it is the kind that passes every test written before it. The hub's
ack is a faithful copy of what the server stored, so `ack.Body` is the ciphertext
that was just sent. Building the sender's own bubble from it puts base64 on the
screen.

`_attemptSend` builds it from the plaintext it is still holding —
`ack.decrypted(body)` — and `FakeChatCrypto` in the test fakes is deliberately
*not* an identity transform for exactly this reason. An identity-transform fake
makes this bug invisible: ciphertext and plaintext are the same string, every
assertion passes, and the user sees `enc:...` in production.

> **A fake that is too convenient stops being a test double and starts being an
> agreement with yourself.**

---

## 6. The push notification had to be rebuilt, and it got worse

This is the part of the change with a genuine cost, and it should not be
soft-pedalled.

Push used to send an FCM `notification` payload. The Android OS draws those
itself, with no involvement from the app, whether the app is backgrounded,
closed, or has never been opened since boot. `FirebasePushSender` had a comment
saying precisely that, and it was right.

Writing a notification requires reading the message. So that option is gone.

What replaces it is the arrangement WhatsApp uses: the server sends a **data-only**
payload carrying the ciphertext, and the recipient's own device decrypts it and
raises a local notification. The lock-screen preview survives, and the server
still never sees a word of it.

```
before   hub ──► ciphertext ──► FCM notification{title, body} ──► OS draws it
                                        ▲
                                  server wrote this, so server read the message

after    hub ──► ciphertext ──► FCM data{ciphertext, iv, …} ──► app decrypts ──► app draws it
```

**The cost:** a data message is delivered to the *app*, not to the OS. Android
may defer it under Doze or App Standby, and an app the user has force-stopped
receives nothing at all. `Priority.High` buys back most of that gap, and it is
now doing real work rather than shaving seconds. But a notification payload had
none of these caveats, and this one does. That trade is the price of the server
not knowing what the message says, and it is worth being able to state plainly
when someone asks why a notification was late.

### Everything the background isolate does not have

`_firebaseBackgroundHandler` used to be an empty function with a comment
explaining that the OS had already done the work. It is now the delivery path.

A background isolate starts empty. No service locator, no registered
`ApiClient`, no open Drift database, no providers, no widget tree. Three things
in the design exist only because of that:

- **Peer public keys are cached in the keystore, not in Drift.** The plan for
  this work said a Drift table. That would have meant opening the same SQLite
  file from two isolates to draw a notification, and it would have put the cache
  behind the sign-out wipe. `flutter_secure_storage` is readable from anywhere
  and survives.
- **`ChatKeyStore.cacheOnly` exists.** The ordinary store falls back to the
  network on a cache miss, which in that isolate means reaching for a service
  locator that has nothing in it. The cache-only constructor makes the miss a
  clean `StateError` that `decrypt` turns into `null` and the notification turns
  into the sender's name — the same fallback as any other decryption failure,
  reached deliberately rather than by exception.
- **`presentChatNotification` is a top-level function that takes its plugin as
  an argument.** `NotificationService` is a singleton the isolate cannot reach,
  and both callers have to agree on the notification id and channel or a
  backgrounded message and a foregrounded one stack instead of replacing each
  other.

The foreground handler needed one deletion that is easy to miss.
It began `if (notification == null) return;`, which was correct when every chat
push had a notification block. There is no notification block on a chat push any
more, so that line would have dropped every chat notification there is —
silently, and only on a device with the app open.

### The message that does not fit

FCM caps a payload at 4KB. The old code handled a long message by truncating it
to 140 characters, which is not available either: chop a byte off an AES-GCM
ciphertext and the tag fails, and the client correctly reads that as tampering.

So a body over the budget is **omitted entirely** rather than shortened, and the
device shows the sender's name with a neutral "New message" — the same thing it
shows when it has no key for that peer. A ciphertext is atomic in a way a
preview never was, and there is no partial version of it to fall back on.

---

## 7. One build step, and why it is not optional

`webcrypto` is pinned to `^0.5.7` rather than the current `0.6.x`. 0.6 builds
BoringSSL through the `hooks` / `native_toolchain_cmake` native-assets path,
which changes what a release build requires; 0.5.x is an ordinary Flutter
plugin, and it is the version the guide this follows uses.

It does need one thing, and it is the kind of requirement that produces a
confusing CI failure the first time somebody adds a test:

```yaml
- run: flutter pub run webcrypto:setup
- run: flutter test
```

`flutter test` runs on the **host** Dart VM, not on a device or in a browser, so
there is no platform crypto for the package to call — it goes through `dart:ffi`
to a BoringSSL library that has to be compiled into `.dart_tool/webcrypto/`
first. Nothing else needs the step: `flutter run`, the release builds, and
`flutter test -p chrome` all reach a real platform implementation. Both
workflows that run `flutter test` carry it.

The web target has its own constraint, worth knowing before anyone picks a
host. On web the package wraps `window.crypto`, which browsers expose **only in
a secure context**. HTTPS and `localhost` both qualify, so the Trainer Console
and the Playwright suite are fine — but a preview deployment served over plain
HTTP would not fail gracefully. It would throw `UnsupportedError` and chat would
not work at all.

---

## 8. What this does not protect against

The server hands out the public keys.

Nothing in this design stops it handing out its own instead. A server that
returned an attacker-controlled public key from `GET api/chat/keys/{id}` would
receive messages it could decrypt, re-encrypt them to the real recipient, and
neither party would notice. Every key-distribution scheme without out-of-band
verification has this property, including the guide this one follows.

The standard mitigation is a safety number: a fingerprint of both public keys,
displayed in the app, that two people compare over some other channel. It is
maybe a hundred lines and a screen.

It is **not built**, and that is a decision rather than an omission. For this
product the realistic adversary is a database dump, a backup left somewhere, or
a subpoena — all of which this design defeats completely — rather than the
operator of the API actively attacking their own users with a modified server
build. If that threat model ever changes, the mitigation is known and the place
to put it is `ChatKeyController`.

Also, explicitly, still true after this change:

- **Metadata is not protected.** Who talks to whom, how often, at what times,
  and how long each message is are all visible in `ChatMessages`. Encrypting
  bodies does not encrypt a social graph.
- **Messages before this change are still plaintext.** They are marked
  `EncryptionVersion = 0` and stay readable, because this server cannot encrypt
  what it was never given a key for. Inventing a key here to backfill them would
  put it in the one place the whole feature says it must not be.
- **The local outbox stores plaintext.** It is on the user's own device, behind
  the OS sandbox, and it is wiped on sign-out. It is also what makes §5's
  re-encryption possible.

---

## What all of this has in common

Four of the decisions above — the storage key that the background isolate can
compute, `decrypt` returning null, re-encrypting on replay, the fake that is not
an identity transform — are the same shape. Each one is a place where the
obvious implementation works perfectly in the situation you are thinking about
while you write it, and fails in a situation that arrives later: a different
isolate, a longer list, a second attempt, a second developer.

None of them is a cryptography problem. The cryptography is four calls to a
library and it either works or it does not. The work was in the seams around it,
which is where this feature always lives.

> **Encryption is not a layer you add to a system. It is a constraint you impose
> on it, and the interesting part is everything that turns out to have been
> depending on the constraint being absent.**

---

## 9. The constraint that was never checked against the product it shipped in

Everything above this line was written the day chat encryption shipped, and
none of it was wrong. It was incomplete in a way nothing above it could have
caught, because the gap was not in the cryptography — it was in a premise
about the *product* that the cryptography section never had reason to state.

### The bug

A trainer opens the Trainer Console on a desktop for the first time, having
already used chat on their phone. Every message in every thread — including
ones they sent from that phone, minutes earlier — renders as "Message can't be
decrypted on this device." Not just on the desktop. On the phone too, the next
time either party's app talks to the server. The conversation is not merely
unavailable on the new device; it is gone, permanently, everywhere.

### Why the compiler and the tests had nothing to say about it

`UserChatKey.UserId` was the primary key. `UserChatKeyRepository.UpsertAsync`
did exactly what its own doc comment said: replace the existing row, because
"a reinstall cannot recover the old private key, so refusing the new public
key would leave that user permanently unable to send anything readable." That
reasoning is correct for a reinstall. `ChatKeyControllerTests` had a test
titled `Republishing_replaces_the_previous_key`, asserting `Assert.Single`,
and it passed, because replacing the row is precisely what the code was asked
to do and precisely what it did.

The type system enforced the schema faithfully: one key pair, one row, one
owner. Nothing about `Guid UserId` as a primary key is a type error. No test
exercised two *devices* registering for the same account, because nothing in
`docs/chat-encryption.md` §3 or the original design ever named "device" as a
concept distinct from "account" — the document's own vault layout comment
says the private key entry is "deliberately not keyed by user id," which is
true and unrelated to the bug, and reads, if you are not looking for it, as
though device identity had already been considered and rejected. It had been
considered for a different question: what the *client* can compute offline.
Whether the *server* could hold more than one key per account was never asked,
because the product this was designed against was implicitly single-device.

> **A green suite proves the code does what the tests describe. It has no
> opinion on whether the tests describe the product.** `docs/chat-encryption.md`
> §3 already contains the sentence that should have been the warning sign:
> "signing in on a second device… means messages from before that point cannot
> be decrypted there." *There* was doing more work than anyone reading it at
> the time noticed — it silently assumed the other devices would be unaffected,
> which was true for the single-device product this was written against and
> false the moment `CLAUDE.md`'s own "Web support" and "Desktop support"
> sections made the Trainer Console a second device for the same account.

### The two-line reason the blast radius was everywhere, not just the new device

A new device having no history is the *expected* cost of no key backup — that
part of the design was always going to be true and is still true today. The
part that made this a bug rather than an accepted limitation is `_decrypt`'s
own recovery path, from §4: the one-time forget-and-refetch after a decryption
failure. It exists so a peer's reinstall doesn't permanently break a thread.
It has no way to tell "the peer reinstalled" apart from "the peer registered a
second device that just overwrote the first's key" — both look identical from
outside: the cached public key stopped matching. So the very mechanism meant
to *heal* a broken thread was what spread the break to the peer's own device:
the peer's app dutifully forgot the old (working) key, fetched the new one,
and could no longer read anything it had cached the old key to decrypt. Two
correct, well-tested pieces of logic — replace-on-publish and
forget-and-retry-once — combined into a failure neither one owns alone.

### The fix, and what it cost

`UserChatKeys` (one row per user) became `UserChatDeviceKeys` (one row per
`(user, device)`) plus `ChatMessageKeys` (one wrapped content key per target
device per message). A message is now encrypted once, under a random content
key, and that content key is wrapped — once per device of *both* parties, the
sender's own included — under a secret derived from the message's own
ephemeral ECDH key pair and each device's public key. Registering a device is
additive: nothing about another device's row changes, and nothing a peer had
already cached stops working, because reading a version-2 message no longer
touches a cached peer key at all. `_decrypt`'s forget-and-retry survives only
for version 1, gated explicitly on `encryptionVersion == 1` — it would
otherwise spend a network round trip discovering that a version-2 failure
means what it always means: no wrapped key for this device, because the
message predates it.

The cost is real and was a deliberate trade, not an oversight: a message still
carries one ciphertext but now up to *N* small wrapped-key entries, one per
registered device of both parties, and the push payload budget
(`PushNotificationService.MaxDataBytes`) had to widen and change what it
measures — the whole assembled data dictionary, not the ciphertext alone —
because the wrap material is exactly as necessary as the ciphertext it
protects and exactly as useless without it. `UserChatDeviceKeys` is pruned to
the ten most-recently-seen devices per account specifically so this list
cannot grow without bound; the messages already wrapped for a pruned device's
row stay wrapped and simply stop growing new entries for it.

### The general lesson

Every other document in this directory that describes a bug found it by
tracing a value through code that handled it wrong. This one is different: the
code that caused it was correct on its own terms, twice over — a replace that
was the right behavior for a reinstall, and a retry that was the right
behavior for a rotated key. The defect was a premise neither piece of code
stated or was responsible for stating: that "the account" and "the device"
were the same thing. Nothing types that premise. Nothing tests its negation
unless someone thinks to write a test for two devices, and nobody did, because
the document describing the feature had already, reasonably, scoped itself to
one.

> **A design constraint inherited from an earlier, narrower version of the
> product does not announce itself when the product grows past it.** The
> single-device assumption was never wrong when it was written — chat shipped
> before the Trainer Console was a second client surface for the same account.
> It became wrong silently, on a date with no diff attached to it, the moment
> another part of the codebase made a promise (a trainer can use the console
> on desktop and stay signed in on their phone) that this feature's own data
> model could not keep. The fix is not "test more." It is: when a document
> states a limitation as a fact about the product ("this device," "the peer"),
> treat every place elsewhere in the codebase that changes what "a device" or
> "an account" means as a reason to reread it.
