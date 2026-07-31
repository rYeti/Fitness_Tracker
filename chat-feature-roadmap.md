# Trainer Console Chat — Implementation Roadmap

Backend roadmap for the SignalR-backed Trainer Console chat feature. Text-only messaging is in scope now; the schema already accounts for media (pictures/videos), but the actual upload/storage pipeline is deferred (see "Out of scope" below).

No implementation bodies here — signatures, purpose, and reasoning only. Fill in the logic yourself.

---

## 0. What's already built

| File | Status |
|---|---|
| `FitTracker.Api/Hubs/ChatHub.cs` | Done — `JoinClientGroup`, `LeaveClientChat`, `SendMessage`, group naming via `GroupName(trainerId, actualClientId)`, `ResolveTrainerAsync` for role-agnostic auth |
| `FitTracker.Api/Models/ChatMessage.cs` | Done — `Id`, `Body` (nullable), `SenderId`, `SentAt`, `TrainerClient` nav, `MediaType`/`Url`/`ThumbnailUrl` (all nullable) |
| `FitTracker.Api/DTOs/ChatMessageDto.cs` | Done — mirrors `ChatMessage` but with `TrainerId`/`ClientId` as raw `Guid`s instead of the nested `TrainerClient` entity, no names (Flutter already has those from roster state) |
| `FitTracker.Api/Services/Interfaces/IChatService.cs` | Partial — `SendMessageAsync` signature done, `GetHistoryAsync` still needed (see §4) |
| `FitTracker.Api/Repositories/Interfaces/IChatRepository.cs` | Stub — only `AddMessageAsync` declared so far |
| `ITrainerClientService.GetActiveRelationshipAsync` | Done — full interface → service → repository chain, returns `TrainerClient?` |
| `IsActiveTrainerOfAsync` bug fix | Done — was comparing `t.Id` (the relationship's own PK) against `trainerId` instead of `t.TrainerId`; fixed. This was blocking every trainer-side auth check in the app, not just chat |

Build order for everything below: **DbSet → Repository → Service → Migration → Controller → `Program.cs` wiring**. Each step depends on the previous one existing, so don't skip ahead.

---

## 1. `AppDbContext` — register the new table

**File:** `FitTracker.Api/Data/AppDbContext.cs`

Add a `DbSet<ChatMessage>`, same pattern as the existing:
```csharp
public DbSet<TrainerClient> TrainerClients { get; set; }
```
(around line 69). Without this, EF has no idea the `ChatMessage` table should exist — nothing downstream compiles or migrates until this is in place.

---

## 2. `IChatRepository` / `ChatRepository`

**Files:** `FitTracker.Api/Repositories/Interfaces/IChatRepository.cs`, `FitTracker.Api/Repositories/ChatRepository.cs`

Pure data access — no auth checks, no DTO mapping. That logic belongs one layer up in `ChatService`, same separation `TrainerClientRepository` keeps from `TrainerClientService`.

### `Task<ChatMessage> AddMessageAsync(ChatMessage chatMessage)`
Already declared. Persists a new message and returns the saved entity (with any DB-generated values populated) — same shape as `TrainerClientRepository.CreateInviteAsync`: add to context, `SaveChangesAsync`, return the entity.

### `Task<List<ChatMessage>> GetHistoryAsync(Guid trainerId, Guid clientId, ...)`
Not yet declared — add it. Needs to:
- Filter by the `TrainerClient` relationship (both ids)
- Order by `SentAt` — almost certainly descending (newest first) since chat UIs typically load "most recent N" and scroll upward for older messages
- Take a pagination parameter. Decide: a simple `int take` (most recent N, no further paging yet) or a proper cursor (`DateTime? before`, return messages older than that timestamp) if you want infinite-scroll-style loading from day one. Given YAGNI, a simple `take` with a sane default is probably enough until the Flutter chat screen actually needs infinite scroll.
- No `.Include()` needed for `Trainer`/`Client` navigation — the DTO no longer carries names, so there's nothing to eager-load beyond the message data itself.

**Naming note:** earlier discussion called this `IChatMessageRepository`; the file that already exists is named `IChatRepository`. Keep the existing name — no reason to rename now that a file's already committed to it.

---

## 3. `ChatService` (concrete class)

**File:** `FitTracker.Api/Services/ChatService.cs`

Constructor dependencies: `ITrainerClientService` (for `GetActiveRelationshipAsync`) and `IChatRepository`.

### `Task<ChatMessageDto> SendMessageAsync(Guid trainerId, Guid clientId, Guid senderId, string? body)`
Steps:
1. Call `ITrainerClientService.GetActiveRelationshipAsync(trainerId, clientId)` to get the `TrainerClient` this message belongs to.
2. Handle `null`. Worth thinking through: `ChatHub.SendMessage` already ran `ResolveTrainerAsync` and threw a `HubException` before ever calling `ChatService`, so by the time execution reaches here, the relationship is already known to be active. A `null` here would mean the relationship was revoked in the split-second between the hub's check and this call — vanishingly unlikely, but not impossible. Decide whether that's worth a defensive exception or genuinely "can't happen, don't guard it" per the YAGNI conventions in `CLAUDE.md`. Leaning toward the latter given how tight the race window is, but it's your call.
3. Construct a `ChatMessage` — `SenderId`, `Body`, `TrainerClient` (from step 1). Leave `MediaType`/`Url`/`ThumbnailUrl` null (text-only path).
4. Save via `IChatRepository.AddMessageAsync`.
5. Map the saved entity to `ChatMessageDto` and return it. This is what `ChatHub.SendMessage` broadcasts to the group as `"ReceiveMessage"`.

### `Task<List<ChatMessageDto>> GetHistoryAsync(Guid trainerId, Guid clientId, ...)`
Calls `IChatRepository.GetHistoryAsync`, maps each `ChatMessage` to `ChatMessageDto`, returns the list. This is what `ChatController` (§5) will call.

Add both methods to `IChatService`.

---

## 4. `IChatService` — add `GetHistoryAsync`

**File:** `FitTracker.Api/Services/Interfaces/IChatService.cs`

Same signature shape as the repository method, minus the DTO-mapping detail (that's implementation, not interface):
```csharp
Task<List<ChatMessageDto>> GetHistoryAsync(Guid trainerId, Guid clientId, ...);
```

---

## 5. `ChatController` (REST)

**File:** `FitTracker.Api/Controllers/ChatController.cs` (new)

SignalR is for *live* delivery — it's not the right tool for "give me the last 50 messages when this screen opens." That's a plain HTTP GET, same as every other Trainer Console read (`TrainerConsoleController`).

Follow the exact pattern already in `TrainerConsoleController`:
- `[ApiController]`, `[Route("api/[controller]")]`, `[Authorize]`
- Private `GetUserId()` helper reading `ClaimTypes.NameIdentifier` off the JWT (copy verbatim from `TrainerConsoleController` — it's already a private helper there, not shared, so this controller needs its own copy)
- `GET /api/chat/{clientId}/history` — calls `IChatService.GetHistoryAsync(trainerId, clientId, ...)` where `trainerId` comes from `GetUserId()`

This is where the earlier "why a separate `ChatService` instead of doing it all in `ChatHub`" question pays off — this controller reuses the exact same persistence/mapping logic the hub already relies on for `SendMessage`, with zero duplicated EF code.

**Open question to resolve before writing this:** should this endpoint work for both roles (trainer *and* client calling it, same as the hub does), or is it trainer-only for now with the Flutter client-side history load handled differently? `ChatHub.SendMessage` already supports both roles via `ResolveTrainerAsync` — if the client also needs to load history, this controller needs the same role-resolution logic, not just `GetUserId()` treated as `trainerId` directly.

---

## 6. `Program.cs` wiring

**File:** `FitTracker.Api/Program.cs`

This part is framework plumbing, not business logic, so here's the literal wiring:

**Register SignalR + the new services**, alongside the existing `AddScoped` calls (~line 105-129):
```csharp
builder.Services.AddSignalR();
builder.Services.AddScoped<IChatRepository, ChatRepository>();
builder.Services.AddScoped<IChatService, ChatService>();
```

**Map the hub**, alongside `app.MapControllers()` (~line 155):
```csharp
app.MapHub<ChatHub>("/hubs/chat").RequireAuthorization();
```

**JWT auth for the WebSocket transport** — SignalR's WebSocket transport can't set an `Authorization` header, so the token has to travel as a query parameter instead. Add an `Events` block to the existing `AddJwtBearer(...)` call (~line 90-103):
```csharp
.AddJwtBearer(option =>
{
    option.TokenValidationParameters = new TokenValidationParameters { /* unchanged */ };

    option.Events = new JwtBearerEvents
    {
        OnMessageReceived = context =>
        {
            var accessToken = context.Request.Query["access_token"];
            var path = context.HttpContext.Request.Path;
            if (!string.IsNullOrEmpty(accessToken) && path.StartsWithSegments("/hubs/chat"))
            {
                context.Token = accessToken;
            }
            return Task.CompletedTask;
        }
    };
});
```
Scoped to `/hubs/chat` specifically so it doesn't loosen auth on the REST controllers — the Flutter SignalR client connects with `?access_token={jwt}` appended to the hub URL.

---

## 7. EF migration

Once the `DbSet` and final `ChatMessage` shape are settled:
```
dotnet ef migrations add AddChatMessages
```
Applies automatically on next run via the existing `db.Database.Migrate()` call already in `Program.cs` (~line 138-140) — no extra step needed, same as every other schema change in this repo.

---

## Out of scope for this pass

- **Media upload/storage.** `ChatMessage.MediaType`/`Url`/`ThumbnailUrl` exist so the schema doesn't need reworking later, but no storage provider is chosen and no upload endpoint exists yet. That's a deliberate follow-up, not an oversight.
- **Flutter chat screen.** Backend-only roadmap. The Flutter side (3-pane desktop / single-pane+tabs mobile, wired into `active_client_provider.dart`) is separate work once this API surface exists.
