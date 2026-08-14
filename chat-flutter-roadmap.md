# Trainer Console Chat — Flutter Client Roadmap

Companion to `chat-feature-roadmap.md` (backend, complete). This covers the client side: outbox, SignalR connection, and the chat screen itself. No implementation bodies here — concepts, shapes, and build order only, same as the backend doc.

Backend contract this builds against (already shipped):
- Hub: `JoinClientGroup(clientId)`, `SendMessage(clientId, body, messageId)` → returns `ChatMessageDto` (the ack), broadcasts `ReceiveMessage` to the group, `LeaveClientChat(clientId)`.
- REST: `GET /api/chat/{clientId}/history?range=N` → `List<ChatMessageDto>`.
- `messageId` is **client-generated** — this is what makes retries safe (see §3).

---

## 0. Current state

Nothing exists yet: no chat feature folder, no SignalR package in `pubspec.yaml`, no outbox table. Confirmed via `pubspec.yaml` (Drift + Riverpod + Dio already present, no `signalr_netcore`/`signalr_core`) and `lib/feature/trainer_console/` (chat has no sibling folder next to `nutrition`, `workout_builder`, etc.).

Build order: **§1 outbox schema → §2 chat models/DTOs → §3 SignalR client wiring → §4 repository (glue layer + reconnect/replay) → §5 state/providers → §6 screen UI → §7 shell wiring.**

---

## 1. Outbox table (Drift)

The foundation everything else depends on. Follows the existing `AppDatabase` pattern (`lib/core/app_database.dart`) — a new Drift table registered alongside `WorkoutSetTable` etc., not a separate database.

**Columns (concept, not final Drift syntax):**
- `messageId` (UUID, primary key) — generated client-side at compose time, never server-side. This is the identity that makes replay idempotent on the backend (`ChatRepository.AddMessageAsync` already dedupes on it).
- `otherPartyId` (UUID) — the id of whoever is on the other side of this conversation, from this device's point of view. No role resolution needed here: unlike the hub/controller, which store one canonical row per relationship and so have to work out "is the caller the trainer or the client side," the outbox is one device's local view of one thread — it just copies whatever id the chat screen is already showing (the active-client selection on the trainer console side, or the trainer's id on the trainee app side).
- `body` (text)
- `createdAt` (timestamp) — for ordering resends.
- `status` (enum: `pending`, `sent`, `failed`) — `pending` until an ack arrives, `sent` once acked, `failed` after retry limit is exhausted (see §3's open question from the concept discussion).

**Why this layer first:** it's pure data, no network, no UI — fully unit-testable (write a row, assert it's still there, assert querying `pending` rows returns it) before anything else in this roadmap exists. It's also the layer most likely to have subtle bugs (see the walkthrough on ordering/idempotency), so it's worth getting right in isolation.

A DAO (`ChatOutboxDao`, matching `MealTemplateDao`'s pattern) exposes: insert a pending row, mark a row sent, query all pending rows ordered by `createdAt`.
DONE

---

## 2. Chat models / DTOs

Mirror `ChatMessageDto` (`FitTracker.Api/DTOs/ChatMessageDto.cs`) as a Dart model: `id`, `body`, `sentAt`, `senderId`, `trainerId`, `clientId`, `mediaType`, `url`, `thumbnailUrl`. This is what both the REST history response and the SignalR `ReceiveMessage` payload deserialize into — one shape, two arrival paths.

Keep the outbox row (§1) and this DTO **separate types**. They represent different things: the outbox row is "a send attempt I'm tracking," the DTO is "a message that exists on the server." A message the user is currently typing has no `sentAt` yet and might never get one (if it fails permanently) — collapsing them into one model invites nullable-field confusion.
DONE

---

## 3. SignalR client wiring

Add a SignalR client package (`signalr_netcore` is the common choice for Dart↔ASP.NET Core SignalR — verify current maintenance status before pinning a version, this ecosystem moves slower than the .NET side).

Responsibilities of this layer, kept thin — just the connection, no business logic:
- Build the hub connection URL with the JWT as `?access_token=` query param, per `CLAUDE.md`'s existing note on why (WebSocket transport can't set headers).
- Expose: `connect()`, `joinGroup(clientId)`, `leaveGroup(clientId)`, `send(clientId, messageId, body) → Future<ChatMessageDto>` (the ack), and a stream/callback for incoming `ReceiveMessage` events.
- Expose a **reconnected** event/callback — this is the trigger for replay (§4), not a timer. Check what the chosen package calls this (`onreconnected`-equivalent).

Nothing here touches the outbox or Drift — this class only knows about the wire protocol.

---

## 4. Repository — the glue layer (this is where the reconnect/replay logic lives)

This is the layer that answers "what happens when a message is lost and then reconnected" from the earlier discussion. It owns both the outbox DAO (§1) and the SignalR client (§3), and mediates between them:

**Sending a message:**
1. Generate `messageId` client-side.
2. Write a `pending` outbox row.
3. Call the SignalR client's `send(...)`.
4. On success (ack received): mark the outbox row `sent`.
5. On failure/timeout: leave it `pending` — do not retry inline, wait for the reconnect signal.

**On reconnect (triggered by §3's reconnected callback):**
1. Query all `pending` outbox rows for the active chat, ordered by `createdAt`.
2. Resend each **sequentially** (await each ack before sending the next) — not concurrently, to preserve the order the user typed them in, since SignalR doesn't guarantee ordering across concurrent invocations.
3. Same `messageId` each time → server-side dedup (`ChatRepository.AddMessageAsync`) makes this safe whether or not the original attempt actually landed.
4. After some bounded retry count fails permanently: mark `failed`, surface it — this is the one piece with no server-side counterpart; it's a pure client UX decision (§6).

**Loading history:** on chat open, call the REST history endpoint (`GET /api/chat/{clientId}/history`), merge with any still-`pending` outbox rows for that thread (a message the user just sent but hasn't gotten an ack for yet should still show in the list, just visually marked as sending).

**Receiving live messages:** subscribe to the SignalR client's incoming-message stream, append to the visible thread. Watch for one subtlety: your own sent message arrives twice from two different paths — once as the direct ack return value from `send(...)`, once via the `ReceiveMessage` broadcast (the hub broadcasts to the whole group, including the sender). Dedupe on `messageId`/`id` before appending, or the sender sees their own message double up.

---

## 4a. Walkthrough — one message, sent while the connection drops mid-flight

§4 describes the rules in the abstract. Here's the same logic traced through a single concrete message, state by state, so it's clear *why* each rule exists rather than just *what* it says.

**Setup:** trainer is chatting with a client. Trainer types "great set today" and hits send. `messageId = m1` is generated locally — this UUID is the thread that ties every step below together, on both client and server.

| Step | Outbox row (`m1`) | Wire | Server (`ChatRepository`) | UI |
| --- | --- | --- | --- | --- |
| 1. User hits send | insert `{id: m1, status: pending, body: "great set today"}` | — | — | bubble appears immediately, dimmed/clock icon (§6) |
| 2. Repository calls `send(clientId, m1, body)` | `pending` | `SendMessage` invocation in flight | — | still dimmed |
| 3. **Connection drops right here** — before the server responds, or after it responds but the ack never arrives | `pending` (unchanged — no ack means no state change) | dead | *unknown to the client which of these happened* — maybe the insert already happened, maybe it didn't | still dimmed, no error yet |

This is the crux of why the whole outbox exists: **the client cannot tell the difference between "server never got it" and "server got it but the ack was lost."** Both look identical from here — a `send()` call that never resolved. Guessing wrong in either direction is bad: assume "never got it" and don't resend → message silently vanishes. Assume "got it" and don't resend → message silently vanishes a different way. So the design doesn't guess; it always resends, and pushes the "was this already inserted?" question onto the server, which is the one party that actually knows the answer.

| Step | Outbox row (`m1`) | Wire | Server | UI |
| --- | --- | --- | --- | --- |
| 4. SignalR reconnects; §3's `onReconnected` fires | still `pending` | connection restored | — | connection-status banner clears |
| 5. Repository's reconnect handler (§4) queries pending rows for this thread, finds `m1`, resends it — **same `messageId`** | `pending` | `SendMessage(clientId, m1, body)` again | `ChatRepository.AddMessageAsync` looks up `Id == m1`: if step 3's insert *did* land, finds it and returns the existing row (no second insert); if it *didn't* land, inserts fresh | still dimmed |
| 6. Ack returns this time | mark `sent` | — | — | clock icon → sent (checkmark, or whatever §6 designs) |

Either branch in step 5 converges on the same outcome: exactly one `ChatMessage` row with `Id == m1`, and the client outbox marked `sent`. That convergence — regardless of which branch actually happened — is the entire point of making `messageId` client-generated and deduping on it server-side. Without it, step 5 would either risk a duplicate message (if step 3's insert *did* land) or the client would need some other way to ask "did my last send actually work?" before deciding to resend, which SignalR doesn't give you.

**The other subtlety this walkthrough surfaces (§4's last paragraph):** notice the ack in step 6 and the group broadcast are *two separate deliveries* of the same message, both arriving at the sender's own client. If the trainer has the chat screen open, they'll receive `m1` back via `ReceiveMessage` too (the hub broadcasts to the whole group, sender included) — *in addition to* the direct ack return value in step 5/6. If the UI naively appends every incoming `ReceiveMessage`, the trainer sees "great set today" twice in their own thread. This is why §4's repository layer must dedupe on `messageId` before appending to the visible list — checking "do I already have a message with this id (from the outbox merge, or from the ack) before adding one from the broadcast stream."

**What "failed" actually means, concretely:** if step 4 never happens — reconnect keeps failing, or reconnects succeed but the resend in step 5 keeps timing out — the repository's bounded-retry counter (§4, "after some bounded retry count fails permanently") eventually flips `m1` from `pending` to `failed`. That's a purely client-side bookkeeping decision (how many attempts, what backoff) with no server involvement — the server never sees a "failed" message, because from its point of view nothing ever arrived to fail. This is the one state (§6) that needs a manual "tap to retry" affordance, because the automatic reconnect-replay loop has already given up on it.

---

## 5. State / providers (Riverpod, matching existing patterns)

Follow `active_client_provider.dart`'s shape — a provider scoped to the currently active client, re-deriving when the active client changes, not re-fetched per navigation. Exposes to the UI: the merged message list (history + pending + live), connection status (for a "reconnecting..." banner), and a `sendMessage(body)` action that delegates to the repository.

Per `CLAUDE.md`'s shared-state rule: this must live at the app-shell level alongside the other active-client-scoped providers, not be re-created per screen — switching the active client re-derives this provider's data without a full navigation reload, same as Nutrition/Workout Builder.

---

## 6. Chat screen UI

Standard screen states per `CLAUDE.md` conventions — all four required, not just the happy path:
- **Loading** — skeleton message bubbles, not a bare spinner, while history fetches.
- **Empty** — "No messages yet — say hello" for a thread with no history.
- **Error** — history fetch failed: inline retry, not a silent blank screen.
- **Populated** — the message list + composer.

Additional states specific to chat, from the outbox work above:
- A `pending` (sending) message needs a distinct visual treatment (e.g. dimmed/clock icon) vs. a confirmed `sent` one.
- A `failed` message (retry budget exhausted) needs a visible "failed to send — tap to retry" affordance on that bubble — this is the manual-recovery path for the one case the automatic reconnect-replay can't solve by itself.
- A connection-status indicator (subtle, e.g. a thin banner) for "reconnecting..." — so a trainer mid-conversation on a flaky connection isn't confused about why nothing's arriving.

Desktop: 3-pane layout (roster / thread / client detail) per `CLAUDE.md`'s Messages screen spec; mobile: single-pane with navigation.

---

## 7. Shell wiring

Register the chat provider/repository at the `trainer_console_shell.dart` level so it's alive alongside the roster and active-client state, and hook connect/disconnect to app lifecycle (join the SignalR group when a chat thread becomes visible, leave it when navigating away — not one global connection joined to every client's group at once).

---

## Out of scope for this pass

- **Media/attachments** — no upload UI; backend fields exist but no upload endpoint either (see backend roadmap).
- **Typing indicators, read receipts, push notifications for new messages while app is backgrounded** — not part of the current spec, would need their own hub methods/schema.
- **Retry backoff tuning, exact retry-count limit** — a product decision (how many attempts, what interval) not yet made; §4's "bounded retry" is a placeholder for that decision.
