# Attachments the server cannot open: what an encrypted file costs

Chat could only carry text. This is the write path, the storage, and the
rendering for photos, videos, voice notes, audio files and documents — and
the handful of decisions that are not obvious from reading the diff.

It assumes `docs/chat-architecture.md` and `docs/chat-encryption.md`. The
outbox, the client-generated `messageId`, the ack, the ECDH key exchange and
`ChatCrypto`'s null-on-failure contract are all load-bearing here, and none
of them is re-explained.

Line references are to the commits on `claude/chat-media-attachments-8dpi45`
that introduced this feature.

---

## 1. The read path was built and had never run

`MediaType`, `Url` and `ThumbnailUrl` had been on `ChatMessage`,
`ChatMessageDto`, the Dart `ChatMessage` and `ThreadMessage` since the first
chat migration in August — propagating faithfully through four layers and
carrying `null` on every message that had ever been sent. There was no
upload endpoint, no storage, and no upload path anywhere in the repository.

> **Plumbing that has never had a value flow through it is not half-done, it
> is untested — and the compiler is happy about a column nothing writes.**
> Every layer type-checked. Nothing in the toolchain distinguishes a field
> that is faithfully threaded through from one that is faithfully threaded
> through and empty.

The consequence that mattered for this feature: those three columns could
not simply start being written. A build already in the wild reads
`MediaType.values[media]` by ordinal (`chat_message.dart`), and the moment
the server writes a value that index has never seen, that build throws —
see §2.

---

## 2. The enum index that could take down a thread

`MediaType.values[media]` is a live crash landmine the instant the server
writes a value the client doesn't recognise. `MediaType.values` had length 2
in every shipped build before this feature; an index of 2, 3 or 4 throws
`RangeError` inside `ChatMessage.fromJson`, called from `ChatRepository`'s
history loop and from the SignalR receive handler. A voice note sent to a
trainee on an older build would not degrade — it would throw out of the
loop, and the whole thread would render `"Could not load this
conversation."` forever, on every future load, not just the one message.

The fix was not "guard the lookup and carry on writing the column." It was
**the server never writes `MediaType`, `Url` or `ThumbnailUrl` on
`ChatMessage` at all.** Every attachment descriptor lives entirely inside
the encrypted manifest (`ChatBodyCodec`, §3), where an old client sees only
an unfamiliar body string — the same "renders as plain text" fallback every
future protocol change gets for free, because the manifest starts with a
human-readable `note` (§3).

The three columns are still on the model, still plumbed, still never
written. Both enums still gained the new values — nominal on the C# side
(`FitTracker.Api/Eums/Media.cs`), the manifest's own `kind` vocabulary on
the Dart side — but the Dart lookup that decodes a manifest's `kind`
(`ChatAttachmentRef.tryFromJson`) is bounds-checked and falls back to
`document` on an index it doesn't recognise, because *that* field really is
sent for real, by a future client, to a build that predates it:

```dart
final kind = kindIndex != null && kindIndex >= 0 && kindIndex < MediaType.values.length
    ? MediaType.values[kindIndex]
    : MediaType.document;
```

> **A wire format that deserialises by ordinal is a contract with every
> build in the wild.** The fix generalises: never write a plaintext ordinal
> column a shipped client indexes into, and guard every ordinal lookup that
> a genuinely new value can still reach.

This has a side benefit nobody asked for: the `ChatMessage` row no longer
records whether an attachment is a photo or a voice note. Compatibility
forced a small privacy win.

---

## 3. Why the key travels in the message, not the bucket

Each attachment is sealed under its own fresh, random AES-256-GCM key —
independent of the ECDH conversation key `ChatCrypto` derives — and that key
travels *inside* the same encrypted envelope the message body already goes
through:

```json
{ "note": "Photo — update ForgeForm to view attachments",
  "ff": 1, "caption": "great session today",
  "att": [{ "id": "…", "kind": 0, "mime": "image/jpeg", "size": 812344,
            "key": "…32 bytes b64…", "iv": "…12 bytes b64…",
            "sha256": "…", "w": 1600, "h": 1200, "avg": "#8a7f6e" }] }
```

The payoff is in what a replay costs. `ChatRepository.replayPending`
re-encrypts the plaintext handed to it under the peer's current key with a
fresh IV — same as it always did for text. Because the attachment key lives
in that plaintext rather than being derived from the conversation key, a
replay re-encrypts a few hundred bytes of JSON, never the file. The 16 MB
video was never encrypted under the conversation key in the first place, so
there is nothing about it to redo. If the peer rotated keys between upload
and replay, the new envelope still carries the same attachment key, so the
file still opens — the attachment key's lifetime is independent of the
conversation's.

`ChatBodyCodec.encode` returns the caption unchanged when there is no
attachment — nothing moves on the wire for the ordinary text case, which is
still the overwhelming majority of messages. Detection on decode is a
guarded prefix test (`startsWith('{"note"')` and `contains('"ff":')`), never
a bare `jsonDecode`: a user who types a message starting with `{"note"` must
still see their own text, not a misparsed manifest.

> **A per-file key that lives with the message, not with the conversation,
> is what turns "resend" from a 16 MB re-upload into a 400-byte
> re-encryption.** The number that makes an IV-reuse rule survivable is
> arithmetic, not taste.

No `EncryptionVersion` bump came with this. That field describes *how*
bytes were protected — `WebCryptoChatCrypto.decrypt` is byte-in/byte-out and
genuinely cannot tell a manifest from a sentence — not *what they mean*.
Spending the version number on a body-format change would leave the next
real cryptographic scheme without one that means what it says. The
manifest's own `"ff": 1` field is where a *format* version belongs, and
that's where it lives.

---

## 4. Why the hub grew a name, not a parameter

SignalR binds hub methods by position and by arity, and fills no missing
trailing argument with a default. Adding a sixth parameter to
`ChatHub.SendMessage` would not degrade gracefully for a five-argument
caller — it fails the invocation outright, which means every shipped
iOS/Android build would have stopped being able to send anything the moment
this deployed. Hub methods cannot be overloaded either.

The fix: a new method, `SendMessageV2`, and the old signature delegates to
it with a null attachment list:

```csharp
public Task<ChatMessageDto> SendMessage(Guid clientId, string body, Guid messageId, string? iv, int encryptionVersion)
    => SendMessageV2(clientId, body, messageId, iv, encryptionVersion, null);
```

The ack contract is unchanged; the only addition is
`IChatAttachmentService.CommitAsync` running after the message is stored and
before the return. Commit is deliberately forgiving: an attachment id that
is missing, belongs to a different pair, or belongs to a different uploader
is **skipped with a warning, never thrown** — a lost message in exchange for
a tidy attachments table would be a bad trade. Commit is also one `UPDATE …
WHERE CommittedAt IS NULL`, so a replay re-commits nothing, and it does
**not** perform a `HeadObject` check — that would put an R2 round trip in
front of the ack, exactly the mistake `docs/chat-architecture.md`'s own
history warns against. A missing object surfaces later, on the
*recipient's* download attempt, as an ordinary download-failed state.

> **A hub contract is versioned by name, not by parameter, because arity
> mismatches don't degrade — they fail the call.** The five-argument path
> still has to work forever, or every build that predates this feature stops
> being able to send a message at all.

---

## 5. `createAll()` is not a migration, the second time

The chat outbox already had one documented incident with this
(`app_database.dart`'s existing comment block): `createAll()` emits
`CREATE TABLE IF NOT EXISTS` for every table at its *current* schema, so an
install that has never run the app before gets the new columns for free —
and then the explicit `if (from < N)` branch's `ALTER TABLE ADD COLUMN`
fails with "duplicate column name" on that exact install, because the
column it's trying to add is already there. Each `ALTER` needs its own
`try/catch` for this reason; a single wrapping try/catch would silently
absorb a genuinely different failure.

The outbox schema for attachments (`attachmentManifest`,
`attachmentLocalPath`, `uploadStatus`, schema 37 → 38) hit the identical
shape of bug, because it's the identical mechanism — not a coincidence, a
recurrence. It's recorded here rather than only in the code comment because
the lesson generalises past this one table: **any schema bump on a database
whose *creation* path already reflects the target schema will hit this,
every time, and the fix is always the same shape** — per-statement
try/catch, tested against both a fresh install and an upgrade from before
the column existed.

The three new columns are a second axis (`AttachmentUploadStatus`), not four
more `ChatMessageStatus` values, for a reason worth stating plainly:
`ChatMessageStatus` indices are read by **raw SQL**
(`chat_out_box_table WHERE chat_message_status != 1`) that gates the
sign-out unsynced-changes warning. Overloading that enum with
upload-in-progress states would have made sign-out miscount how much work
was actually pending.

**`app_database.g.dart`'s new columns were hand-written, not
build_runner-generated.** `analyzer` 7.7.1, pinned in this repo, cannot
parse Dart 3.13's dot-shorthand syntax used elsewhere in this codebase, so
`build_runner build` crashes before emitting anything — and its own
"delete conflicting outputs" cleanup step briefly deleted twelve *other*
tracked `.g.dart` files before the crash, all restored via `git checkout --`
before anything was lost. The hand-written columns were pattern-matched
against Drift's existing generated style for the table's other nullable
columns in the same file, and are exercised — not merely compiled — by real
migration tests running the actual upgrade path against real SQLite files.
That is meaningfully stronger evidence of correctness than "the generator
would have produced this," but it is still a manual step with no compiler
checking it against Drift's actual codegen rules, and it will silently
diverge the next time a real `build_runner` run succeeds in an environment
without this sandbox's analyzer mismatch, if that run isn't diffed against
what's here first.

---

## 6. A presigned URL is not a network call, and the signature says so

`IChatAttachmentStore.CreateUploadUrl` / `CreateDownloadUrl` are
**synchronous** on purpose. SigV4 presigning is an offline HMAC computation
over the request's own parameters — it needs no round trip to R2 at all. A
`Task<Uri>` signature on a method that never actually awaits anything is an
invitation for a future caller to `await` it inside a section of code where
a real network call would be wrong, which is exactly the mistake
`docs/chat-architecture.md` already paid for once (a database read inside
what should have been a synchronous decision). Keeping the signature
synchronous keeps that mistake from having a second place to happen.

---

## 7. E2E encryption deletes the CDN playbook

`Image.network` and `cached_network_image` — the entire ordinary Flutter
approach to remote media — are unusable here. The bytes at a mint URL are
ciphertext; HTTP caching, progressive decode and the browser's own image
cache all assume the URL's bytes are the picture, and none of that is true
once the picture only exists as AES-GCM output.

What replaces it is two tiers with genuinely different lifetimes, and
conflating them is exactly what would have made §8 below lose someone's
photos:

- **`AttachmentStore`** — permanent, native platforms only. Decrypted bytes
  written to app-private storage (never the shared gallery — the OS sandbox
  is the boundary, the same argument `docs/chat-encryption.md` §8 already
  makes for the outbox holding plaintext), indexed by a small JSON file
  rather than a new Drift table, for the same build_runner reason as §5: a
  *new* table has no existing generated code to safely pattern-match by
  hand against, so a JSON sidecar was the lower-risk choice this time,
  revisited if codegen becomes available again.
- **`AttachmentCache`** — ephemeral, every platform including web (which has
  no permanent tier at all — see below). A ~40 MB in-memory LRU in front of
  the store, deduplicating concurrent fetches for one attachment id via an
  in-flight `Future` map, so two bubbles referencing the same photo neither
  mint two download URLs nor decrypt twice.

`ChatAttachmentProvider.stateFor` never issues a network call — it only
computes what to render from state already held (§8 covers the case that
makes this matter most). `fetch`/`ensureAutoFetched` are the only paths that
touch the network, and the policy is deliberately asymmetric: **images fetch
the moment their bubble paints; every other kind — document, audio, voice
note, video — waits for a tap.** That's a data-plan courtesy first and a
Class B cost control second (§12).

**Web has no permanent tier.** There is no filesystem, and putting hundreds
of megabytes of video in IndexedDB was not judged worth the trade for a
browser workstation on ordinarily-good connectivity. The Trainer Console
therefore re-fetches within the retention window and shows expired outside
it — the one place the two clients genuinely differ, and it's stated here
rather than hidden.

---

## 8. A lifecycle rule cannot say "committed"

A bucket lifecycle rule can say "delete anything older than 45 days under
`chat/`". It cannot say "whose database row still has a null
`CommittedAt`", because the bucket has no concept of what a chat message is.
Making a lifecycle rule sufficient on its own would need a staging prefix
plus a `CopyObject` at commit time — which puts an R2 round trip in front of
the ack, the same mistake §4 already ruled out.

So the reaper is a swept table, not a lifecycle rule alone:
`ChatAttachmentReaper` runs hourly, deleting rows where `CommittedAt IS NULL
AND CreatedAt < now - OrphanGraceHours` — objects a client minted an upload
URL for and then never actually sent. A separate weekly pass reconciles the
bucket's own object listing against the table, which is the *only* thing
that catches objects orphaned by a `TrainerClient` cascade delete — that
delete removes the SQL rows and leaves the R2 objects behind, because a
foreign-key cascade has no idea an S3-compatible bucket exists.

The retention window itself (45 days, `Attachments__RetentionDays`) is an R2
lifecycle rule, and *that* rule genuinely can be a plain bucket policy,
because expiring "everything under this prefix past this age" needs no
knowledge of commit state at all. The weekly reconciliation pass is what
clears the now-dangling `ChatAttachment` row once the lifecycle rule has
already removed its object — and it deliberately **never touches the
`ChatMessage` row**. The bubble and its caption survive; only the blob does
not. That split is what makes §7's "stored / not-yet-fetched, within the
window / expired" three-way state derivable from a timestamp plus a store
miss, rather than something that has to be recorded anywhere: a `404` (or
`410`, from §0.2 below) from any cause — early reaping, the lifecycle rule,
a genuinely bad request — lands in exactly the same `expired` state a
client reaches on its own by checking `sentAt` against the window, with no
network request issued once it's past that window.

---

## 9. A presigned PUT cannot enforce a byte cap

R2 has no presigned POST, and the POST policy is the only S3 mechanism that
can bind `content-length-range` into a signature. That means the 8 MB
image/document and 16 MB video caps are enforced **client-side and declared
server-side** — the client refuses an over-cap file before sealing it, and
the mint endpoint records the declared length, but nothing stops a modified
client from PUTting more bytes than it declared.

The mitigation is a lazy `HeadObject` on the *download* mint path — a REST
endpoint, where a round trip is unremarkable — that deletes and `410`s any
object whose actual length exceeds what was declared at mint time. This is
documented rather than hidden specifically because it is a real gap: a
client that lies about its own upload size can park an oversized object
until the next time *anyone* tries to download it, and only then does it
get cleaned up.

---

## 10. What still leaks

Encrypting the bytes does not encrypt the fact that a message had bytes.
Three new signals exist per attachment that didn't before: that a message
carried one, its ciphertext size (±16 bytes for the GCM tag), and its
upload timestamp.

Size is the only genuinely new signal, and it's coarse: 40 KB is plainly a
voice note, 12 MB plainly a video — it does not distinguish two photos of
similar dimensions from each other. This is accepted on the same grounds
`docs/chat-encryption.md` §8 already accepts message timing: the realistic
adversary here is a database dump or a subpoena, and a rough size-and-time
profile is a smaller disclosure than the `ChatMessages` timing pattern
that's already there. The known mitigation — padding ciphertext sizes to a
fixed set of buckets rather than leaving them exact — is **not built**; this
is where it would go if the size signal ever needs closing.

The one thing that stopped leaking, as a side effect of §2's compatibility
fix: whether a message was a photo or a voice note used to be visible on
the server via the (unwritten, but present) `MediaType` column. It is now
inside the ciphertext, full stop. Compatibility forced a privacy
improvement nobody set out to build.

---

## 11. Where we told the truth instead of shipping a fake

Six platforms and five media kinds is thirty combinations, and a few of
them are genuinely not covered — stated here rather than quietly degraded:

- **Voice recording is unavailable on Linux and on web.** Linux needs an
  external recording binary this repo doesn't bundle
  (`ChatComposer._micAvailable`), so the mic affordance is simply hidden
  there — a platform capability, not a bug. Web is deferred for a sharper
  reason: Chrome's `MediaRecorder` emits `audio/webm;codecs=opus`, and iOS
  cannot decode that. A trainer recording a voice note in the browser that
  their iPhone client then cannot play back is worse than not offering
  recording at all, so web users attach an audio *file* instead — the
  "Audio file" entry in the same attach sheet, using the ordinary file
  picker rather than the recorder.
- **Video posters are best-effort, not guaranteed.** The plan anticipated
  capturing one via `media_kit`'s `Player.screenshot()` at pick time; it
  wasn't built in this pass, and a video bubble shows its `avg` colour
  placeholder plus a duration badge until played, which is honest about
  what's actually there rather than a poster that sometimes silently fails
  to appear.
- **`media_kit` over `video_player` was the harder package, deliberately.**
  `video_player` has no Windows or Linux implementation at all, so it was
  never a candidate for "video plays inline everywhere." `media_kit`
  (libmpv-backed) does — Android, iOS, macOS, Windows, Linux, and a web
  fallback to an HTML5 `<video>` element that needs a URL rather than
  bytes, bridged by a `Blob` URL built with `package:web`
  (`video_blob_url_web.dart`) rather than the deprecated `dart:html`.
  Picking the package with genuine desktop coverage is what let "video
  plays inline on six platforms" be a true sentence instead of "…except on
  the two desktop platforms, where you get a button that opens your system
  player."

> **A capability that works on two platforms out of six, presented as if it
> works everywhere, is a support burden wearing a feature's clothes.** Every
> gap above is a `!kIsWeb`/`TargetPlatform` check with a comment pointing
> here, not a silent degrade a trainer discovers by filing a ticket.

---

## 12. "Like WhatsApp" was two mechanisms, and a plan can ship half of one

An earlier pass of this plan specified a 45-day server-side retention window
and stopped there. That is not what WhatsApp actually does, and shipping
only that half would have meant chat media genuinely vanishing forty-five
days after it arrived — a worse outcome than the feature having no
retention policy at all, because it looks like a bug rather than a
documented limit.

WhatsApp's actual behaviour is two mechanisms, not one: received media
auto-downloads to **permanent** device storage and stays there indefinitely
— that's the photo still openable two years later — and *separately*, the
server-side blob expires after roughly a month. The 45-day expiry is only
ever visible when the local copy is *also* gone: a reinstall, a second
device, or a manually cleared cache. §7's two-tier store (`AttachmentStore`
+ `AttachmentCache`) and §4b's storage-management screen exist specifically
because the server-side half is not survivable as a product decision
without the device-side half sitting next to it.

> **When you copy a system's headline parameter, check which of its other,
> unstated parts that parameter was only survivable because of.** "45-day
> retention" was never the whole design; it was one number inside a design
> whose other half made losing data at 45 days invisible to a user still
> holding the app.

---

## 13. The billing rules that are not the price list

Verified against Cloudflare's own documentation rather than assumed, because
the unit price alone doesn't tell you what a design actually costs:

- **Deletes are free.** `DeleteObject` and `AbortMultipartUpload` are in
  R2's free-operations list, so both the orphan reaper and the retention
  lifecycle rule cost nothing in operations, however often they run.
- **`PutObject` is Class A** ($4.50 per million, 1M free); two PUTs per
  attachment (one for the file, one for its thumbnail where present) is
  comfortably inside the free tier at this feature's expected volume.
- **`GetObject` *and* `HeadObject` are both Class B** ($0.36 per million,
  10M free) — which makes §9's oversized-object check a small, real,
  billable cost per download mint, not a free safety net.
- **Storage bills on the average of *peak per day*.** The retention rule
  (§8) reducing the bill happens promptly on the schedule it runs, not only
  at month's end.
- **Concurrent writes to the *same* object key are capped at
  1/second** (HTTP 429). `resumeAttachmentUploads` and a manual retry both
  re-PUT the same object key on the same attachment id, so that retry path
  needs per-key backoff rather than a tight loop — distinct attachments use
  distinct keys and are unaffected by this cap.
- **The Cloudflare account-management REST API is rate-limited to 1,200
  requests per 5 minutes per account and is not the same thing as the S3
  API.** `IChatAttachmentStore.ListKeysAsync` uses `ListObjectsV2` against
  the S3 endpoint specifically to avoid ever touching the management API at
  runtime — that API returning `Please enable R2` is a real, previously
  observed failure mode for code that reaches for it by habit.

None of this changes the design; all of it is why the design that got built
doesn't have a surprise line item in it three months from now.

---

## 14. Operations nothing in CI covers

Two manual steps have no automated check, and both fail silently rather
than loudly if skipped:

- **The R2 bucket needs a CORS policy** — PUT/GET, the console's web
  origin, `content-type` allowed, `etag` exposed. Without it, a browser
  upload fails its CORS preflight and nothing in the application code says
  why; it looks like a network failure from the browser's own network tab.
- **The bucket needs a lifecycle rule** expiring objects under `chat/`
  older than `Attachments__RetentionDays`. This is what makes §8's
  retention story true at all — the reaper's reconciliation pass cleans up
  *after* the rule has already removed the object, it does not itself
  enforce the window.

`Attachments__R2__{AccountId,Bucket,AccessKeyId,SecretAccessKey}` follow the
existing FCM/CORS pattern in `deploy.yml`: appended conditionally, with a
`::warning::` when unset, so a missing secret degrades the feature
(`Attachments__Provider` falls back to `disabled`) rather than failing the
deploy.

---

## 15. Three bugs that only a real browser found

Every unit and widget test for this feature passed from the day it was
written. Phase 7b — a real Playwright pass driving the built web bundle
against a seeded local API (`Attachments__Provider=local`, per
`docs/e2e-playwright.md`) — found three genuine defects anyway, none of
which any of that coverage could have caught, because none of them is
reachable without a real browser, a real HTTP stack, and a real second
signed-in session. `e2e/tests/chat-attachments.spec.ts` is where they were
found and is what now guards against them recurring.

**An enabled button with no name.** `ChatComposer`'s attach `IconButton`
set `tooltip: attachEnabled ? null : l10n.chatAttachmentsUnavailable` —
a tooltip only in the *disabled* state, on the theory (never written down)
that the icon alone was enough otherwise. `Icon(Icons.add_rounded)` carries
no `semanticLabel`, so the enabled button's accessible name was empty: a
screen reader announced "button", nothing else, and a Playwright
`getByRole('button', { name: … })` query could not find it either — the
same invisibility, for the same reason, on both sides. Widget tests never
exercise the button by role or name (they drive it, when they drive it at
all, through the picker seams), so nothing failed. Fixed by giving the
button a real label, `chatOpenAttachMenu` ("Add attachment"), in both
states — the same `tooltip:` mechanism the existing code comment already
explains is required for a screen reader to see it on web at all.

**Every attachment upload silently failed in a browser.**
`ChatAttachmentTransfer.upload` set `Headers.contentLengthHeader` explicitly
on every PUT, on every platform, because a `Stream` body has no
otherwise-knowable length. On web, `dio_web_adapter` sends requests through
the Fetch API, and `Content-Length` is on [the Fetch spec's forbidden
header list](https://fetch.spec.whatwg.org/#forbidden-request-header) —
setting it throws before the request leaves the page. The failure crossed
two silences at once: dio wraps it as a `DioException` with no `response`,
which `classifyAuthError`-style code (here, the attachment sender's own
error handling) can only report as a generic "upload failed", and
`ApiClient`'s own error logging goes through `Logger()`, whose default
filter drops everything below debug builds — so a release build, which is
what a web bundle always is, printed nothing at all. No widget test could
have caught this: `ChatAttachmentSender` is always exercised through a
`FakeChatAttachmentTransfer` there, which never touches `dio_web_adapter`
or the Fetch API's header restrictions. It took a real browser sending a
real request to see it fail with no explanation. Fixed by omitting the
header on web (`kIsWeb`) and letting the browser compute it from the body,
keeping it on native platforms where it's still required.

**The local dev store's own signature never matched.** This is the same
shape of bug §1 opens with — code that had never run. `LocalDiskChatAttachmentStore`
exists specifically so a developer or this Playwright suite can exercise a
real upload/download round trip without an R2 account (§7's two-tier store
made this possible in the first place). Its presigned URL embeds the object
key with `Uri.EscapeDataString`, turning the key's internal `/` into `%2F`
— and ASP.NET Core's `{*objectKey}` catch-all route parameter does not
decode a `%2F` back into `/` when binding it, by design, so an encoded
slash inside one path segment can never be mistaken for a literal separator
during routing. `Sign()` HMACs the raw key; `ValidateToken` was given the
still-encoded one. Every signature check failed, silently, as a plain 403 —
correct behavior for a tampered or forged URL, wrong diagnosis for a key
nobody tampered with. `FitTracker.Api.Tests` never catches this class of
bug for the same reason `EnsureCreated()` misses a migration drift (§5):
building the model in memory and calling a service method directly skips
routing entirely, so a value that round-trips cleanly in a unit test never
passes through the URL encode/decode step that broke it. Fixed by decoding
the bound route value back to the raw key — `Uri.UnescapeDataString` —
before validating or touching the filesystem, in both `PutLocal` and
`GetLocal`.

**The general shape.** All three bugs lived at a boundary this feature's
own test suite structurally cannot cross: real ARIA semantics in a real
DOM, a real browser's Fetch implementation, and real ASP.NET Core routing.
Every fake and seam built for this feature (§B.2's `AttachmentCrypto`,
`FakeChatAttachmentTransfer`, `InMemoryChatAttachmentStore`) is correct and
was built for good reasons — but a fake, by construction, cannot fail the
way the real thing fails at an integration boundary it was built to skip
past. None of these three would have been caught by *more* unit tests
without first suspecting they existed; they were only found by actually
running the feature.

- **Size-bucket padding** for the ciphertext-size leak (§10) — not built.
- **Poster-frame capture** at pick time for video (§11) — not built.
- **Test coverage for `chat_push_decoder.dart`** — it has none, before or
  after this feature; `ChatKeyStore` and `WebCryptoChatCrypto` are
  constructed directly inside `decodeChatPush` rather than through an
  injectable seam, and building fake infrastructure for that was judged
  disproportionate to the manifest-decoding change itself.
