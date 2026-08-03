# Trainer Console Chat — Implementation Roadmap

Backend roadmap for the SignalR-backed Trainer Console chat feature. Updated after the external code audit (`chat-backend-review.md`, commit `dfd072c`) — all of its code-level claims were verified against the working tree, and two additional gaps it missed are folded in below (§6 DI registration, migration status).

Text-only messaging is in scope now; the schema already accounts for media, but upload/storage is deferred. No implementation bodies here — signatures, purpose, and reasoning only.

---

## 0. Current state (verified)

| File | Status |
| --- | --- |
| `FitTracker.Api/Hubs/ChatHub.cs` | ✅ Done — design is right (group-per-pair, `ResolveTrainerAsync`, persist-then-broadcast, `[Authorize]` + relationship check). Small cleanups pending (§5) and one contract change pending (§4) |
| `FitTracker.Api/Program.cs` | ✅ Mostly done — JWT `access_token` query extraction correctly scoped to `/hubs/chat`, `AddSignalR()`, `MapHub` + `RequireAuthorization()`, `IChatService` registered. **One gap: `IChatRepository` is never registered (§6)** |
| `FitTracker.Api/Repositories/ChatRepository.cs` | ✅ Functional (take-N-descending + reverse). Simplification pending once the FK exists (§3) |
| `FitTracker.Api/Repositories/Interfaces/IChatRepository.cs` | ✅ Done — `AddMessageAsync`, `GetChatHistoryAsync` |
| `FitTracker.Api/Models/ChatMessage.cs` | ⚠️ Missing explicit `TrainerClientId` FK (§3) and needs client-generated-id decision (§4) |
| `FitTracker.Api/Services/ChatService.cs` | ❌ **Does not compile — blocker (§1)** |
| `AppDbContext` | ⚠️ `DbSet<ChatMessage>` added, but **no migration exists yet** — first chat insert fails at runtime until §7 |
| `ChatController` (REST history) | ❌ Not started (§2) |

Build order: **§1 ChatService fix → §3 FK fix → §4 contract change → §7 migration (one migration covers §3+§4) → §6 DI registration → §2 controller → §5 cleanups.**

---

## 1. BLOCKER — rewrite `ChatService.cs`

The current file is hub code pasted into the service; it cannot compile:

- `SendMessageAsync` uses `await` but isn't declared `async`; never returns the promised `ChatMessageDto`.
- `var (trainerId, ok) = ...` collides with the `trainerId` **parameter**.
- Calls `ResolveTrainerAsync` / `GetUserId` — those live in the hub and depend on `Context.User`, which a service doesn't have.
- Throws `HubException` from a non-hub class.
- `private Guid GetUserId() => _ ;` is a dangling stub.
- Wrong constructor deps: `ITrainerClientRepository` + `IUserRepository`; the one it actually needs — `IChatRepository` — is missing.

**Target design (small, no auth logic):**

- Inject `IChatRepository` + `ITrainerClientRepository` (or `ITrainerClientService` — either works; pick one and match `GetActiveRelationshipAsync`'s home).
- Look up the **Active** relationship row by `(trainerId, clientId)` → get its `Id`. Keep the `Status == Active` filter — the hub already authorized, but this is cheap defense-in-depth if the hub check ever drifts.
- Build the `ChatMessage` (set the `TrainerClientId` FK — see §3, not the navigation), call `AddMessageAsync`, map entity → `ChatMessageDto` (fill `TrainerId`/`ClientId` from the relationship row).
- No `HubException`, no user resolution, no re-authorization. Identity and authorization are the hub's job; persistence and mapping are the service's.

Key conceptual point (this is where the paste went wrong): the hub knows *who is calling* (`Context.User`); the service is told *what to do* via parameters. By the time `SendMessageAsync(trainerId, clientId, senderId, ...)` is called, all identity questions are already answered.

---

## 2. `ChatController` — REST history endpoint

`ChatRepository.GetChatHistoryAsync` exists but **nothing calls it**. Loading history when the chat screen opens is a plain HTTP GET, not a hub concern.

- New `FitTracker.Api/Controllers/ChatController.cs`, following `TrainerConsoleController` exactly: `[ApiController]`, `[Route("api/[controller]")]`, `[Authorize]`, private `GetUserId()` helper.
- `GET /api/chat/{clientId}/history` → `IChatService.GetHistoryAsync` (add to the interface; maps repo entities → DTOs).
- **Pagination decision:** the current repo method takes a fixed `range` (most-recent-N). The audit recommends **keyset pagination** instead (`before:` cursor on `SentAt`/`Id`) — better for infinite scroll, and the composite index in §3 supports it directly. Fixed-N is simpler and fine for a first ship; keyset is the end state. Decide now whether to build keyset immediately or ship N-most-recent and revisit when the Flutter screen needs infinite scroll.
- **Both roles must be able to load history** — the client app needs it too, not just the trainer console. `GetUserId()` can't be treated as `trainerId` directly; the controller needs the same "which side is the caller" resolution the hub does (or a service method that accepts `(callerId, otherPartyId)` and resolves internally).

---

## 3. Schema fix — explicit `TrainerClientId` FK (runtime bug)

`ChatMessage` has a `TrainerClient` **navigation property but no FK property**, and `ChatRepository.AddMessageAsync` copies the navigation instance into a new entity. If that `TrainerClient` instance isn't tracked by the current `DbContext`, EF treats it as a **new entity** — it will try to insert a duplicate `TrainerClient` row or fail on the PK. This bites at runtime, not compile time.

- Add `public Guid TrainerClientId { get; set; }` to `ChatMessage`; creators set the FK, never the navigation.
- In `AppDbContext.OnModelCreating`: configure the relationship explicitly and add a **composite index on `(TrainerClientId, SentAt)`** — this matches the history query's filter+sort shape exactly, and serves keyset pagination too.
- Simplify `AddMessageAsync`: once the FK exists, the field-by-field copy is pointless — `_context.ChatMessages.Add(chatMessage)` directly.
- The history query can then filter on `c.TrainerClientId == relationshipId` instead of joining through the navigation (`c.TrainerClient.TrainerId == ...`), which is both simpler and uses the index.

Reminder: `TrainerClient.ClientId` is nullable (pending invites) — irrelevant once you filter `Status == Active`, but don't drop that filter.

---

## 4. Delivery guarantees — ack + idempotent replay (contract change, do BEFORE Flutter)

SignalR alone guarantees nothing about delivery. The plan is **client outbox + server ack + replay-on-reconnect** — and the same outbox infrastructure is later reused for offline workout sync. Two things in the current code block this:

- `ChatMessage.Id` is server-generated (`= Guid.NewGuid()` initializer) → a replayed send creates a duplicate row; the server can't recognize it as the same message.
- Hub `SendMessage` returns nothing → the client has no ack to correlate with its pending outbox entry.

**Contract changes:**

1. Hub signature becomes `SendMessage(Guid clientId, Guid messageId, string body)` — **`messageId` is client-generated**. Remove the `Guid.NewGuid()` initializer from the model (or keep it only as a fallback) and pass the id through.
2. Unique index on `ChatMessage.Id` (PK already gives you this); on duplicate-key insert, **return the existing message** instead of failing — replays become idempotent for free.
3. **Return `ChatMessageDto` from the hub method** — SignalR supports return values; that return *is* the ack. The broadcast to the group stays as-is; the return value goes only to the caller.
4. Client flow (later, Flutter): write to local outbox → invoke `SendMessage` → on return, mark acked → on reconnect, replay unacked rows.

Do this before any Flutter chat work — it changes the wire contract, and retrofitting after a client exists is far more expensive than doing it now.

---

## 5. Small cleanups

| File | Issue |
| --- | --- |
| `ChatHub.cs` | Injected services exposed as **public properties** (`TrainerClientService`, `ChatService`) — make them private fields, matching every other class in the codebase |
| `ChatHub.cs` | Unused usings: `System.Text.RegularExpressions`, `System.Xml` |
| `ChatHub.cs` | `GroupName` comment says "id-sorted"; the implementation is role-ordered (trainer first). That's deterministic and fine — **fix the comment, not the code** |
| `ChatHub.cs` | `LeaveClientChat` discards the `ok` flag from `ResolveTrainerAsync` — add an early return on `!ok` |
| `IChatService.cs` | XML doc still says `<param name="sender">`; the parameter is `trainerId` |
| `DTOs/ChatMessageDto.cs` | Leftover `using FitTracker.Api.Models;` no longer needed |

---

## 6. Remaining `Program.cs` wiring

Everything from the original roadmap is in place **except one line**:

```csharp
builder.Services.AddScoped<IChatRepository, ChatRepository>();
```

Without it, the moment `ChatService` takes `IChatRepository` in its constructor (§1), the app fails at startup with an unresolvable-dependency error. Place it next to the `IChatService` registration (~line 149).

---

## 7. EF migration

**Does not exist yet** — the Migrations folder has zero `ChatMessage` references, so despite the `DbSet`, the table is never created and the first insert throws at runtime.

Wait until §3 (FK + index) and §4 (id semantics) are settled, then generate **one** migration covering all of it:

```bash
dotnet ef migrations add AddChatMessages
```

Applies automatically on startup via the existing `db.Database.Migrate()` call.

---

## Out of scope for this pass

- **Media upload/storage** — schema fields exist (`MediaType`/`Url`/`ThumbnailUrl`); provider + upload endpoint deferred.
- **Flutter chat screen** — nothing exists yet (no chat feature folder, no `signalr_netcore` in pubspec), which is the correct order: outbox table first, SignalR client on top, after the §4 contract is final.
- **Wider app roadmap** — RPE persistence, export, generic offline outbox, BLS food data, adaptive TDEE, etc. are tracked in `chat-backend-review.md` §6–§7, not here.
