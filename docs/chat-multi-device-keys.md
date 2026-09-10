# Multi-device keys: the second sign-in nobody had tested for

Signing in on a second device used to silently take over the first device's
chat identity. This is the account of what that actually broke, why fifty-two
backend tests and ninety-odd Dart tests had nothing to say about it, and the
rule the fix leaves behind.

It assumes `docs/chat-encryption.md`. The ECDH key exchange, `ChatKeyStore`,
the one-shot decryption-failure recovery, and ChatCrypto's null-on-failure
contract are all load-bearing here, and none of them is re-explained.

Line references are to the commit that introduced this document.

---

## 1. The bug report was one screenshot, and it undersold itself

A trainer's phone showed "Message can't be decrypted on this device" on a
handful of bubbles in an otherwise-working thread. The obvious hypothesis —
the one every decryption-failure bug in this codebase has had until now — is
that the peer reinstalled. `ChatRepository._decrypt` already has a recovery
path built for exactly that: forget the cached peer key, fetch it again, retry
once.

It didn't recover. The peer hadn't reinstalled. The trainer had opened the
Trainer Console in a second browser tab a few days earlier.

Tracing it back: `UserChatKey` — the table holding everyone's published ECDH
public key — has `UserId` as its primary key.

```csharp
entity.HasKey(k => k.UserId);
// "a user has exactly one current chat key, and a table that allowed two
// would need a rule for which of them a sender should encrypt to."
```

That comment is correct about the schema it is describing and wrong about the
world. A user does not have exactly one current chat key the moment they have
two devices. `PUT api/chat/keys/me` upserts by `UserId` alone, so the second
device's publish did not add a row — it *overwrote* the first device's.

> **A single-row table encodes an assumption as a schema, and a schema doesn't
> raise an exception when the assumption stops holding. It just starts being
> wrong.**

## 2. Why the compiler, and both test suites, had nothing to say

Every layer here type-checks. `UserChatKey.UserId` is a `Guid`, `PublicKeyJwk`
is a `string`, the foreign key is valid, the migration applied cleanly. A
single upsert-by-user-id is not a bug in isolation — it is exactly what the
original single-device design called for, and the fifty-two backend tests
covering it (key publish, key lookup, the trainer/client pairing gate) all
still pass today, unmodified in what they assert.

The Dart side is the same story. `ChatKeyStore.ensureRegistered` had two
branches: the account changed (regenerate), or the server's key is `null`
(republish). Both are real states, both are handled, both are tested
(`chat_key_store_test.dart`'s "regenerates when a different account signs
in" and "republishes when the server has lost the key" predate this work and
still pass). What was missing wasn't a bug in either branch — it was a third
branch nobody had written the `if` for: *the server has a key, and it isn't
ours.*

> **A green suite tells you every state you wrote a test for behaves the way
> you wrote the test to expect. It has no way to tell you about the state you
> never considered a state at all.**

`docs/chat-encryption.md` §8 has an explicit, itemized list of what the
design does not protect against — metadata, pre-existing plaintext, outbox
plaintext, attachment sizes. Multi-device is not on it. It isn't an accepted
risk that got written down and later exploited; the possibility of a second
device was never on the page to begin with. `README.md` advertises "cloud
synchronization for multi-device access" as a product feature two paragraphs
above where the chat design doc says a private key has "no backup and no
recovery" — both sentences are true, and nobody had put them next to each
other before this bug report did.

## 3. What actually happened, traced through both directions

Notation: **A** is the first device, still signed in; **B** is the second,
just signed in; **P** is the peer on the other side of the conversation.

**The publish.** B's `ensureRegistered()` calls `GET api/chat/keys/me`, gets
back A's public key (non-null, so the "republish" branch never fires), finds
no private key in *its own* vault (it's a different browser/device), and
falls through to `_generate()` — mint a fresh key pair, `PUT` it. The
`UserChatKeyRepository.UpsertAsync` finds the existing row by `UserId` and
overwrites `PublicKeyJwk` in place. A's row is gone. There was never a
moment where the server held both.

**A, reading.** Every message P sends from now on is encrypted to whatever
key P has cached for this account — which, the first time P's cache gets
refreshed, becomes B's. A is still holding the private key that matches
*its own* now-overwritten public key. `_decrypt`'s recovery path fires
(`plaintext == null`, `_refetchedPeers.add(peer)` succeeds), calls
`ChatCrypto.forget(peer)`, refetches P's key — and gets back the same key P
already had, because P's key never changed. The one-shot retry is spent
disproving a hypothesis that was never true, and the *actual* problem — A's
own identity was displaced — has no code path that ever checks for it.

**A, sending — the quiet one.** A's `encrypt()` only needs P's public key,
untouched by any of this. The send acks. `ChatRepository._attemptSend`
builds A's own bubble from the plaintext it already holds, not by decrypting
the ack — so A sees an ordinary, delivered-looking message. P, decrypting it
against B's key (the one P now has cached), gets nothing. A has no way to
learn this happened: nothing about *sending* a message that becomes
unreadable to its recipient looks any different from sending one that
doesn't, from the sender's side of an authenticated-encryption scheme by
design — a wrong key is supposed to be indistinguishable from a right one to
whoever doesn't hold it.

**P, and the part that made this destructive rather than merely
inconvenient.** P caches one key per peer (`chat_peer_key:<userId>`,
singular, exactly as singular as `UserChatKey` was). The first message B
sends triggers P's own recovery path: `forget` drops the cached key,
refetches, gets B's. From that instant, P holds only B's key. Every message
A sent before B ever existed — the entire history of the conversation up to
that point — fails to decrypt on the next `loadThread`, permanently, on
*P's* device. Nothing about B signing in touched A's messages. What touched
them was P's own single-slot cache doing exactly the job it was built to do,
against a key rotation that was never a rotation.

| Direction | What happens | Visible to whom |
|---|---|---|
| P → A (after B's sign-in) | Decrypts against A's key, fails | A: "can't be decrypted" |
| A → P | Encrypts to P's key (unaffected), sends fine, renders from local plaintext | Nobody — looks delivered |
| P → A, retried | `forget(P)` refetches P's *own* key, unchanged, retry fails again | A: still can't read it |
| A's *entire prior history* → P | P's cache flips to B's key on first B→P message | P: history goes dark |

The word "silent" earns its place three separate times in that table, in
three different mechanisms, for three different reasons — a UI that has no
event to render, a recovery path built for a different failure, and a cache
whose only bug is that it was never told two keys might both be valid at
once.

## 4. The design: wrap once, not encrypt twice

The fix is not "let two rows exist and pick one." Picking one is the
disease, restated. A message has to become readable by *every* current
device of *both* parties, and it has to do that without either re-encrypting
the body per device (a thread can be read on a phone that's been offline for
a week and a laptop that hasn't) or growing past FCM's 4 KB data-payload
budget, which is what data-only push already lives inside
(`docs/chat-encryption.md` §6).

The shape that satisfies both constraints already exists in this codebase,
one feature over: `docs/chat-attachments.md` §B.1 seals an attachment's bytes
once under a random per-file key, and lets that key travel — small, and
cheap to re-wrap — separately from the bytes it protects. A chat body is the
same problem at a smaller scale. `ChatEncryption.ecdhP256AesGcmWrapped`
(version 2) seals the plaintext once under a random 256-bit content key, then
wraps that content key — one AES-GCM operation each, a few hundred bytes
total — once per recipient *device*:

```json
{"v":2,"s":"<senderDeviceId>",
 "ct":"<b64 AES-GCM(contentKey, plaintext)>",
 "w":{"<deviceId>":{"i":"<b64 wrapIv>",
                     "k":"<b64 AES-GCM(ECDH(myPriv,devicePub), contentKey)>"}}}
```

The content IV travels in the existing `Iv` column, unchanged in shape from
version 1 — only the `Body` column's contents grow a layer. Every wrap uses
the same primitive version 1 already used for the whole body: an ECDH secret
between this device's private key and one specific device's public key, now
applied once per recipient device instead of once per recipient user.

**Rejected: a full ciphertext per recipient device.** `ChatMessages` has one
`Body` column and one `Iv` column; multiplying either by device count is a
schema change the hub's ack/broadcast shape doesn't fit either. It also
scales the wrong dimension — a five-device fan-out would multiply a message's
*entire* size by five, where wrapping multiplies only the ~48-byte key.

**Rejected: key escrow (a device asks another of its own devices to hand it
the content key it's missing).** This adds an interactive protocol between a
user's own devices, on top of an already-asynchronous, offline-tolerant
messaging system — a device that's asleep, or simply not running the app,
becomes a dependency for reading a message that already arrived. Wrapping for
every known device up front has no such dependency: a device reads whatever
it was wrapped for, whenever it next asks, with nobody else involved.

**Rejected: keep one row per user, add a "please don't overwrite me" flag.**
This was the first design considered and the reason this document exists at
all — any scheme that still has exactly one *slot* per user has to decide
what happens when a second device wants it, and every answer to that
question is a version of the bug this document opens with. The fix isn't a
better single-slot policy. It's not having a single slot.

## 5. One row per device, not one row per user

`UserChatKey` gains `DeviceId` and `LastSeenAt`; the primary key moves to a
surrogate `Id`, matching every other table in this schema (composite primary
keys are otherwise unused here, and introducing the one place that broke this
convention wasn't worth it for a constraint a unique index enforces exactly
as well: `(UserId, DeviceId)`, unique). `PUT api/chat/keys/me` now upserts by
`(userId, deviceId)` — it touches one device's row, full stop, which is the
entire fix stated as a sentence.

**The device id has to be mintable with no network and no server round
trip**, for the same reason the private key itself lives under a fixed vault
entry rather than one keyed by user id
(`docs/chat-encryption.md` §3): the push background isolate has to find it
with nothing but the platform keystore. `chat_identity_device` sits beside
`chat_identity_key` for exactly that reason — a UUID, minted once, the first
time `ensureRegistered()` ever runs on that install, and never regenerated.

**It survives an account switch on purpose.** `_forgetEverything()` — the
routine that fires when a different account signs in on the same physical
device — clears the identity key pair, the cached peer keys, and the cached
own-device list. It does not clear the device id. The device id names the
*install*, not whoever happens to be signed into it; a phone that takes
turns between two accounts is still one device as far as the server needs to
know, and regenerating it on every switch would make every sign-out-then-in
look like a brand-new device to anyone still trying to reach the old one.

**The cap is five, evicted least-recently-seen, and self-healing on
eviction.** Nothing deletes a device's row when a user actually stops using
it — there is no signal for that. Left unbounded, a browser tab that mints a
fresh identity every time someone clears site data (`docs/chat-encryption.md`
§8 already names this as the honest cost of a browser-backed vault) would
accumulate rows forever. Eviction doesn't need to be careful about which
device it drops: an evicted device simply republishes its existing key pair
the next time it opens chat, landing back in the table under the same device
id, no worse off than a row that was merely slow to be read.

## 6. Detecting displacement, which the original design had no way to ask

`ensureRegistered()`'s missing branch, spelled out:

```dart
final mine = me.devices.where((d) => d.deviceId == deviceId).firstOrNull;
if (mine == null || mine.publicKeyJwk != storedPublic) {
  await api.publish(storedPublic, deviceId: deviceId);
}
```

This is now safe to run unconditionally, in a way it structurally could not
have been under the old schema: it only ever writes *this device's own* row.
Under one-row-per-user, the equivalent check — "does the server's key match
mine?" — would have had no way to answer without also answering "and if not,
whose key does the server actually have?", because there was only one row to
compare against and no device field to tell whether a mismatch meant
*someone else* or merely *stale*. The check was un-writable before the
schema had a place to write it into.

The republish covers both directions damage could flow: a device whose row
was evicted by the cap, or — the case this document opened with — a second
device that overwrote it. Both look identical from the first device's side
(the server's key for this device id doesn't match what's in the vault), and
both are fixed by the same one line.

`GET api/chat/keys/me` returns `Devices: [...]` for exactly this comparison,
plus `PublicKeyJwk` carrying the single most-recently-seen device's key — the
same value the endpoint has always returned, so a client built before this
change (a shipped 1.0.2, say) keeps working off that one field precisely as
it always did. Compatibility is not a special case bolted onto the response;
it's what the field already meant, still true.

## 7. What a build that predates device ids gets, and why it isn't broken

A client that has never heard of `deviceId` sends `PUT api/chat/keys/me` with
that field absent. The alternative to giving it *some* answer is rejecting
the request outright — breaking every already-shipped install the moment
this deploys. Absent maps to one specific, well-known id:

```csharp
public const string LegacyDeviceId = "00000000-0000-0000-0000-000000000000";
```

A literal id rather than treating "no device id" as its own special state
everywhere the code touches a device id — the cap counts it as a device like
any other, eviction can select it like any other, and a client reading
`Devices` sees an ordinary entry rather than a null it has to specially
handle. One reserved value threaded through the ordinary path, instead of a
second path through every method that touches one.

**Sending *to* a legacy-only peer still uses version 1**, unchanged from
before this work, because a 1.0.2 build has no idea a wrapped envelope
exists and would render it as opaque garbage. `WebCryptoChatCrypto.encrypt`
checks whether the peer's entire device set is exactly `{legacy}` and, if so,
takes the old path — one shared secret, one ciphertext, the format that
predates this document.

**Decrypting a version 1 body needed its own fix, and it is not the fix that
looks obvious.** The first draft of this resolved a v1 body's key by looking
it up under the legacy slot specifically — correct for reading *old* history
written before device ids existed, and silently wrong for a v1 message a
multi-device-aware sender had just sent *to* a legacy-only peer, where the
sender's own key was never filed under legacy at all. Version 1 carries no
sender-device field — that's the entire reason it needs a fallback in the
first place — so there is no way to know, from the envelope alone, which of
the peer's current devices actually produced it. The fix tries every
currently-cached device of the peer in turn and keeps whichever one's GCM tag
verifies. A wrong key fails that check cleanly; trying a handful, bounded by
the same five-device cap that bounds everything else here, costs nothing a
user would notice and was cheaper to build correctly than to special-case.

> **A migration bridge has two directions of traffic across it, and the
> obvious implementation of "handle the old format" is usually only tested
> against one of them.**

## 8. The mistake that shipped inside the fix itself

The first working version of `_encryptV2` skipped wrapping the content key
for the sending device's own id. The reasoning felt sound while writing it:
this device already holds the plaintext it just produced, so a wrap for
itself is a wasted derivation and a few wasted bytes in a payload with a hard
4 KB ceiling.

It breaks `ChatRepository.loadThread` the very next time that device reopens
the conversation. The plaintext-in-hand shortcut this reasoning leaned on —
`_attemptSend` builds the sender's own bubble from the plaintext it is still
holding, specifically so the ack's ciphertext never has to be decrypted —
covers exactly one moment: the instant of sending. It says nothing about
every subsequent load of that same stored message, on that same device,
which calls `decrypt()` on the persisted ciphertext like any other row in
history, with no plaintext left anywhere to fall back on. A device that sent
a message and can never read it again on a restart is not a smaller version
of the bug this document is about — it's the same bug, self-inflicted, one
line later.

The fix is one deleted `if`: wrap for every device this account owns,
including whichever one is doing the sending. Self-ECDH — a device deriving
against its own exported public key — is not a special case the primitive
needs to know about; `deriveBits(myPrivate, myOwnPublic)` is exactly as
well-defined as deriving against anyone else's, and it's the same operation
this same device will repeat, unprompted, the next time it needs to unwrap
its own message.

> **An optimization justified by "this path already has the value some other
> way" has to prove that shortcut covers every caller, not just the one in
> front of you while you're writing it.** The same value, `docs/chat-encryption.md`
> §5 already spent a section on for the ack's ciphertext; it cost a second
> reminder here because the two call sites don't look alike.

**A second instance of the same mistake shipped alongside the fix above, in a
different method, and survived one review pass before a second one caught
it.** `ChatKeyStore.ensureRegistered`'s republish branch — the one that fires
when this device's own row is missing or stale on the server, exactly the
case this whole feature exists to repair — fetched `me` (this account's
device list) *before* publishing this device's row, then cached that same
pre-publish `me` as "every device I own":

```dart
final mine = me.devices.where((d) => d.deviceId == deviceId).firstOrNull;
if (mine == null || mine.publicKeyJwk != storedPublic) {
  await api.publish(storedPublic, deviceId: deviceId);
  await _vault.write(identityOwnerEntry, userId);
}
await _cacheOwnDevices(me.devices);   // me predates the publish above
```

`me.devices` cannot contain this device's own row by construction — it was
fetched at a point in time before that row existed. Caching it anyway means
this device's own current id is never among the "my other devices" wrap
targets `_encryptV2` reads, for the rest of that session: the exact self-wrap
failure this section already describes, reached through the one code path
most likely to run *because* something about this device's registration was
already wrong (a five-device eviction, a fresh install after the server
already had four other devices, an upgrade from a build with no device id at
all). The `_generate` path a few lines below — first run, no stored key at
all — gets this right, with a comment explaining why: it refetches `me`
*after* publishing, paying a second round trip specifically to see its own
just-written row. The republish branch had the same shape and needed the
same fix, and didn't get it, because a reviewer (and the author) checking
"does this branch publish correctly" is a different question from "does this
branch's *cache* end up correct" — the publish succeeds either way; only the
read side is wrong.

The fix costs no second round trip: splice this device's own row into `me`'s
list before caching, replacing any stale entry for the same id by filtering
it out first.

```dart
final devicesToCache = [
  for (final d in me.devices) if (d.deviceId != deviceId) d,
  ChatKeyDevice(deviceId: deviceId, publicKeyJwk: storedPublic),
];
await _cacheOwnDevices(devicesToCache);
```

The test this shipped without: the original coverage for this branch
(`'republishes when the server has lost every device but this one has not'`)
asserted the publish itself — call count, that the same key and device id
were sent again — and never once called `ownDeviceKeys()` afterward to check
what got cached. A branch can publish exactly right and cache exactly wrong,
and a test that only watches the write side of that branch cannot tell the
difference. Watching the read side (`ownDeviceKeys()`, the value the crypto
layer actually consumes) is what closed the gap.

## 9. Two hypotheses where there used to be one

`ChatRepository._decrypt`'s one-shot recovery used to have exactly one thing
it could try: forget the peer's cached key and refetch it. That was written
for a reinstall, and it's still correct for one. It is no longer the only
reason a decrypt can fail for a reason worth retrying.

A v2 message wraps its content key for every device this account had *at
send time*. A device that finds out about a new device of its own — because
someone messaged them from it — only learns that on its own next
`ensureRegistered()`. Between those two events, a message wrapped for the
new device is unreadable on every *older* device of the same account, for a
reason that has nothing to do with the peer at all: `forget(peer)` refreshes
the wrong cache.

```dart
if (_refetchedPeers.add(peer)) {
  await _crypto.forget(peer);        // the peer published a device we haven't cached
  retried = true;
}
if (_refetchedOwnDevicesFor.add(peer)) {
  await _keys.ensureRegistered();    // *we* have a device we haven't cached
  retried = true;
}
if (retried) plaintext = await attempt();
```

Both hypotheses are tried, each bounded to once per peer per session, and
then one retry — not two separate retry cycles — because doing both together
on first failure is simpler than sequencing them, and a decrypt failure is
rare enough on a working thread that trying an unnecessary refresh alongside
the necessary one costs nothing worth optimizing away. The bound is per
peer rather than a single session-wide flag for the own-device hypothesis,
even though refreshing "every device I own" is not really peer-specific —
matching `_refetchedPeers`'s existing shape was worth more than a marginally
tighter bound that would have needed its own, differently-shaped bookkeeping
next to it.

## 10. What still leaks, and one gap left honestly open

Nothing here changes `docs/chat-encryption.md` §8's accounting: the server
still hands out public keys and could substitute its own without a safety
number to catch it; metadata (who talks to whom, when, how much) is still
visible; pre-existing plaintext stays plaintext. Multi-device adds one new
line to that list rather than removing any: **the device count and
`LastSeenAt` timestamps are now visible per user**, a coarser version of the
same timing-pattern disclosure already accepted for message send times, on
the identical grounds — the realistic adversary here is a database dump, not
an operator actively fingerprinting how many phones someone owns.

**One thing is not built:** a device that gets evicted by the five-device cap
loses read access to everything encrypted while it held its slot, exactly as
a peer whose key was never cached does. There is no notification to the
evicted device — no push exists to reach a device the server no longer has a
key for, which is a closed loop. The device finds out the ordinary way: it
tries to read a message and fails; `ensureRegistered()`'s next run re-adds
it under the exact same failure-and-recover shape a rotated peer already
uses. This is stated here rather than silently accepted, on the same
reasoning `docs/chat-attachments.md` §11 uses for capabilities that are
real but genuinely partial: five real devices with a documented, self-healing
eviction cost is a truer sentence than infinite devices with no cap and an
unbounded table.

## 11. The one id that isn't really a device id

`WebCryptoChatCrypto._shared` caches a derived AES-GCM secret by device id,
on the invariant §5 states plainly: a device's key pair doesn't change for
the life of its id, so the secret derived against it never goes stale. That
invariant holds for every id `_ensureDeviceId` mints — a fresh UUID, unique
to one install, forever. It does not hold for
`ChatKeyStore.legacyDeviceId`, the fixed all-zero sentinel every
pre-migration row of *every* account publishes under, because a build old
enough to have no device id concept has no id to be unique with. Treating
that sentinel as if it named one specific device was the same category of
mistake §7 describes for `_decryptV1`'s lookup direction — a value that looks
like an ordinary device id everywhere it's read, until the one place that
assumes uniqueness.

The failure needs two legacy parties in the same `WebCryptoChatCrypto`
instance to show up — routine for the Trainer Console, where one instance
serves a trainer's entire roster (`trainer_console_home.dart` builds one
`ChatRepository`, and therefore one crypto instance, for every client, not
one per open thread). Encrypting v1 to client A, whose only published device
is the legacy row, derives a secret against A's legacy public key and caches
it under `legacyDeviceId`. Encrypting v1 to client B — a different person,
also legacy-only — looks up the same cache key, finds A's secret still
there, and reuses it instead of deriving against B's actual public key. The
message to B is sealed with a key B cannot produce on their end; their
decrypt fails the GCM tag check and returns null, silently, the same shape
every other unreadable-message case in this document takes. The same
collision reaches a trainer's own account, too, if one of their own devices
is still on the legacy row: their own-device wrap for that row and a v1 send
to an unrelated legacy peer fight over the same cache entry depending on
which happened first in that session.

`forget(peer)`, the recovery this whole design leans on for a rotated key,
does not help here — by design, it only refreshes the peer's *device list*,
correct for every real device id, and never touches `_shared` at all,
because a real device's derived secret is never the thing that goes stale.
The legacy sentinel breaks that assumption in the other direction: it isn't
one device rotating, it's many unrelated devices sharing one name.

The fix does not try to make the sentinel behave like a real id. It excludes
it from the optimization instead: `_sharedKeyFor` never reads from or writes
to `_shared` when the device id in hand is `legacyDeviceId`, deriving fresh
every time regardless of which peer or which of this account's own devices
is on the other end. Real device ids are unaffected — the cache still holds
for the traffic it was built for. Legacy traffic pays one extra ECDH
derivation per message instead of reusing a cached key, which costs nothing
worth optimizing away: it is inherently transitional, shrinking as clients
upgrade, and gone entirely once no build old enough to lack a device id is
still signing in.

> **A cache keyed on "id" is only as safe as the promise that the id names
> one thing.** Every real device id in this system keeps that promise by
> construction; the one sentinel that predates device ids does not, and nothing
> about its type signature — it's a `String`, like every other device id —
> said so.

---

## What all of this has in common

Six separate mistakes in this document — the single-slot schema, the
missing displacement check, the self-wrap omission, the legacy-lookup
direction, the republish path's stale own-device cache, and the legacy
sentinel's cache collision — share one shape. Each one is code that is
correct for every case its author was actually holding in mind while writing
it, and silently wrong for a case that looks, from the outside, like a minor
variation: a second device instead of a reinstall, a later reload instead of
the moment of sending, a message *to* a legacy peer instead of history *from*
one, a republish instead of a first registration, two legacy peers instead
of one. None of the six is a logic error a type system or a unit test
written against the case in mind would ever have caught, because each test
would have been written against exactly the case the author was thinking
about, and passed — including, twice now, a test that watched the write half
of a branch and never checked what the branch actually left behind to be
read later.

> **The device is never the one you're testing against.**
