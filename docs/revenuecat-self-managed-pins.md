# Self-managed nutrient pins: why premium had to grow a server side first

## The gap

The Trainer Console's micronutrient feature (merged as PR #83) made the "Tracked
nutrients" picker coach-driven. `TrainerClientService.GetMyNutrientPinsAsync`
returns a trainer's saved pins for their client, or a fixed default
(fibre/sugar/sodium) for anyone else — including a premium user who has no
trainer at all. That's not an oversight so much as a scope boundary the first
version of the feature never crossed: every existing caller of the "who am I
tracking for" question already had a trainer relationship to ask about. A
solo premium user with nobody to curate pins for them was simply never a case
the code considered, and they were stuck on the same three defaults forever
with no way to choose their own.

The obvious fix — let a premium user pick their own pins — needs a "is this
user premium" fact the server can act on. That fact didn't exist for a plain
user. `AccessProvider.hasPremiumAccess` on the client is `_isPremium ||
_proFromLicence`. `_proFromLicence` is a real server computation
(`TrainerLicence.GrantsPro`/`DerivesProAsync`), but it only exists for a
trainer or a trainer's client. `_isPremium` is set entirely from the device:
`Purchases.getCustomerInfo()` reads RevenueCat's local cache and the app
trusts whatever comes back (`access_provider.dart:257-274`). The API had zero
visibility into it — there was no RevenueCat reference anywhere in
`FitTracker.Api` before this change.

Building the pins feature directly on that client flag would have compiled,
worked in the happy path, and been wrong in the same way twice already fixed
elsewhere in this codebase: `docs/trainer-console-micronutrients.md` and
`docs/trainer-console-duplicate-rows.md` both describe a client-side check
standing in for a boundary the server never re-verified. A user can set
`_isPremium = true` in their own device's memory trivially (a jailbroken app,
a modified request, a debugger) — nothing stops them, because nothing on the
server ever looks. That's a fact no type system or test suite catches: the
code type-checks and the tests you'd write for the happy path all pass, because
the vulnerability is entirely about what the *caller* controls, not what the
function returns for valid input. So the actual work here wasn't "add a
picker" — it was "give the server a source of truth for third-party premium
that it can independently verify," and only then build the picker on top of it.

## Mirroring Stripe, not inventing a second pattern

`FitTracker.Api` already has exactly this problem solved for a different
premium source: `StripeWebhookController` → `LicenceStateMachine.Apply`
verifies a signed webhook and turns it into `TrainerLicence` state. RevenueCat's
webhook (`RevenueCatWebhookController.cs`) copies that shape on purpose —
anonymous by necessity, all logic delegated to a service, and a pure
state-machine function driving the actual state change — rather than being a
one-off. A second, differently-shaped integration living next to the first one
is a maintenance cost with no offsetting benefit; the two premium sources
being *independent* (see below) doesn't mean they should also be
*differently built*.

One real difference forced a divergence: **RevenueCat has no HMAC signature.**
Stripe signs its payload; you recompute the signature and compare. RevenueCat's
dashboard instead lets you configure an arbitrary shared-secret string that's
echoed back verbatim in the `Authorization` header on every delivery — so the
entire authentication story is a string compare. A naive `==` (or `string.Equals`)
short-circuits on the first differing byte, which leaks the secret's length and
roughly where it diverges through response timing — a real, exploitable
side-channel for a secret an attacker gets unlimited attempts against (nothing
rate-limits guesses at the *webhook auth header itself*; the rate limit is on
event volume, not credential attempts). `CryptographicOperations.FixedTimeEquals`
fixes the timing side of that, but it requires equal-length inputs, and
branching on a length mismatch before calling it reopens exactly the leak it's
meant to close. `RevenueCatService.FixedTimeEquals` hashes both sides with
SHA-256 first — always 32 bytes — so there's no length difference left to leak
before the constant-time comparison even runs.

## Computed liveness, not a stored flag

`RevenueCatSubscription.IsEntitled` is `ExpiresAt is DateTime exp && exp >
DateTime.UtcNow` — computed at read time, never stored. The alternative — a
`bool EntitlementActive` set from the incoming event's type (`RENEWAL` → true,
`EXPIRATION` → false, …) — is the same class of bug `docs/sync-account-switch-duplication.md`
and `docs/chat-timestamps.md` independently found in other features: a derived
value cached instead of recomputed drifts from the thing it was derived from
the moment time passes and nothing re-touches the row. A subscription that
quietly expires on a Tuesday with no further webhook traffic would stay
"active" forever under a stored-bool design, because nothing was ever going to
flip it. Deriving from `ExpiresAt` means expiry enforces itself — the next read
just sees that `ExpiresAt` is in the past, no `EXPIRATION`-event-specific code
path required. `RevenueCatStateMachineTests.APastExpiryComputesNotEntitledWithNoSpecialCasing`
pins exactly this: applying only ever a `RENEWAL`-shaped snapshot with an
already-past expiry produces `IsEntitled == false`, with nothing in the
state machine that special-cases the *reason* it lapsed.

Idempotency follows the same shape as `LicenceStateMachine`: `Apply` only
updates `ExpiresAt` when the incoming event's own timestamp is newer than
`LastEventAt` (`RevenueCatSnapshot.cs`). RevenueCat retries a webhook delivery
on any non-2xx response and can deliver out of order, so both "the same event
twice" and "a stale event after a newer one already landed" have to be no-ops
— confirmed by `ReplayingTheSameEventChangesNothing` and
`AnOutOfOrderEventIsIgnored`.

**`TRANSFER` events are logged and dropped, not handled.** RevenueCat sends
`TRANSFER` when a subscription moves from one `app_user_id` to another —
normally a real scenario (a user reinstalling and buying again under a new
anonymous id before ever logging in). This app's login flow always calls
`Purchases.logIn(serverUserId)` before RevenueCat can attribute a purchase, so
`app_user_id` is expected to always already be the server's own `User.Id` —
`TRANSFER` shouldn't have a live code path to exercise in practice. Handling it
"properly" would mean deciding what happens to a `UserNutrientPin` row that
outlives the account it was for, for a case the actual login flow shouldn't
produce. Silently ignoring it would be worse than either: a class of event
quietly doing nothing, with no record it happened. The `Parse` method logs a
warning and returns null instead, so a `TRANSFER` this app didn't expect shows
up in logs rather than in a bug report six months later.

## Two premium sources that stay siblings, not a merge

`ITrainerClientService.DerivesProAsync` (licence-derived) and
`IRevenueCatService.IsEntitledAsync` (a user's own app-store purchase) are
deliberately never combined into one "is this user premium" method. The
temptation is real — `AccessProvider.hasPremiumAccess` on the client already
ORs together the client-side purchase flag and the server-verified licence
flag, so a server-side `IsPremiumAsync` that ORs the same two things server-side
looks like it'd finish the parity. It would also be scope creep with a real
cost: every other feature gated on `DerivesProAsync` today (the micronutrient
summary lock, for one) would silently start accepting RevenueCat entitlement
too, whether or not that was ever asked for or reasoned through for that
feature. `TrainerLicence.GrantsPro` requiring a *paid* tier and never an
invite-code relationship is a deliberately narrow rule with three regression
tests behind it (see `docs/trainer-licensing.md`) — folding a second,
differently-sourced "yes" into the same yes/no would be exactly the kind of
implicit widening that rule exists to prevent. So `SetMyNutrientPinsAsync` and
`GetMyNutrientPinsAsync` call `_revenueCat.IsEntitledAsync` directly, as one
more branch alongside the trainer-pins branch — one new repository call at the
one call site that needs it, nothing platform-wide.

## The three-way read, and why the write refuses two of three

```csharp
public async Task<List<string>> GetMyNutrientPinsAsync(Guid userId)
{
    var asClient = await _repo.GetActiveRelationshipForClientAsync(userId);
    if (asClient != null)
    {
        var trainerPins = await _nutrientPins.GetPinsAsync(asClient.TrainerId, userId);
        return trainerPins.Count == 0 ? [.. NutrientKeys.Defaults] : trainerPins;
    }

    if (await _revenueCat.IsEntitledAsync(userId))
    {
        var ownPins = await _userNutrientPins.GetPinsAsync(userId);
        return ownPins.Count == 0 ? [.. NutrientKeys.Defaults] : ownPins;
    }

    return [.. NutrientKeys.Defaults];
}
```

A linked client's branch is checked *first* and unconditionally short-circuits
the RevenueCat branch — a client with an active trainer never reaches
`IsEntitledAsync`, even if they also happen to hold their own RevenueCat
entitlement (nothing stops a client from also being a paying app-store
subscriber). `SetMyNutrientPinsAsync` enforces the same ordering as a refusal
rather than a silent no-op: a linked client's write attempt gets
`HasActiveTrainer`, not `NotEntitled` and not quiet success — the caller needs
to know *why* the picker isn't theirs to use, because "your coach manages
this" and "you need Premium" point the user at two completely different next
steps.

`UserNutrientPin` mirrors `TrainerNutrientPin`'s replace-the-whole-set write
(`ReplacePinsAsync`: delete existing rows, insert the new set, one
`SaveChangesAsync`) rather than an incremental add/remove, for the same reason
recorded in `docs/trainer-console-duplicate-rows.md` — toggling a single row
independently isn't safe to make idempotent, replacing the set is.

## The client gate is UX, not enforcement

`food_tracking_screen.dart`'s `_buildTrackedNutrients` computes `canSelfPick =
access.hasPremiumAccess && !access.isTrainerClient` and passes
`_toggleMyPin` as `onTogglePin` only when true — otherwise `null`, which
`TrackedNutrientsCard` already treats as "read-only, hide the picker"
(`tracked_nutrients_card.dart:39-41`, built generically because the Trainer
Console's own card needed the same null/non-null contract). That's exactly
the same relationship the rest of this feature already has between client and
server everywhere else: the client decides what to *show*, `PUT
api/TrainerClient/my-nutrient-pins` decides what's *allowed*. A modified
client that flips `canSelfPick` locally and calls the endpoint anyway gets the
same `HasActiveTrainer`/`NotEntitled` 403 a legitimate client would have
avoided by not showing the button — the picker's visibility is a convenience,
never the boundary.

`_toggleMyPin` mirrors the Trainer Console's own
`NutritionProvider.togglePin` (`nutrition_provider.dart:98-118`): optimistic
local update, persist, revert on failure — chosen so a tap feels instant on
the trainee side exactly as it does on the trainer side, rather than the two
surfaces of the same feature behaving differently for no reason a user could
tell you.

## The webhook that could never match a real user

The design above assumed one fact that turned out to be false: that
`app_user_id` on an incoming webhook would always be the server's own
`User.Id`, because `Purchases.logIn(userId)` is called with it at sign-in.
`RevenueCatService.Parse` was written against that assumption —
`Guid.TryParse(userIdProp.GetString(), out var userId)` failing is treated as
an unparseable/foreign event to ignore, not an error, on the theory that it
can only mean a stray webhook about someone else's app.

It meant something else in practice. `main.dart`'s restore path calls
`accessProvider.initialize(userId: restoredAuth.user!.username, ...)` —
`login_screen.dart` and `register_screen.dart` did the same, from a local
`newUserId` that is also, despite its name, the username. `AccessProvider`
passes that straight into `Purchases.logIn`, so RevenueCat's dashboard has
never recorded a single ForgeForm purchase under a GUID — every `app_user_id`
it has ever seen is a username string. Every webhook event this feature ever
received would hit `Guid.TryParse`, fail, log a warning, and return null. No
`RevenueCatSubscription` row could ever be created for a real purchase, for
any user, ever — a genuinely paying, premium user would still see `not
entitled` on every attempt to pick their own nutrients, indistinguishable
from someone who never subscribed at all. This shipped in the same PR as the
feature it silently broke.

Nothing here was a bug the type system or the test suite could have caught.
`RevenueCatStateMachineTests` and the `TrainerClientService` tests all
construct a `RevenueCatSnapshot`/webhook payload directly with a real `Guid`
already in hand — none of them go through `Purchases.logIn` or exercise what
the client actually sends as `app_user_id`, because nothing in this codebase
had ever needed that value to be anything more specific than "some string
RevenueCat also has," until this feature made the identity of that string
load-bearing. The gap was findable only by asking, for a genuinely-entitled
account, "does this actually work end-to-end" — which surfaced it on the
first real attempt.

**The fix**: the client never had a GUID to give `Purchases.logIn` in the
first place — `AuthResponseDto`/`AuthResponseModel` (the login/register/
refresh/profile-update response) carried a username, email and name, but
never the user's `Id`, even though the JWT it ships alongside already encodes
it as the `sub` claim. Rather than have the client decode its own JWT to
recover an identifier the server already has to hand, `AuthResponseDto`
gained an `Id` field, set once at its single construction site
(`AuthService.IssueTokensInternalAsync`, shared by login, register, refresh
and profile update), and the three call sites that feed
`AccessProvider.initialize` now pass `.id` instead of `.username`.

The account-switch detection in `login_screen.dart`/`register_screen.dart`
(`last_logged_in_user`, wiping the local database when a different account
signs in) deliberately keeps using the username-derived `newUserId` it
already had — that comparison has nothing to do with RevenueCat, and
changing what it's keyed on would only be a second, unrelated identity change
riding on this one. Only the `userId:` argument to `initialize` moved to the
GUID.

A session restored from a cache written before this field existed sees `id:
''` until the next silent token refresh — every refresh response goes through
the same `IssueTokensInternalAsync`, so the cached user JSON self-heals
within one access-token lifetime (`Jwt:AccessTokenMinutes`, an hour by
default) without a migration step.

## What this deliberately doesn't do

- No change to `AccessProvider.hasPremiumAccess` or any other feature reading
  it — `IRevenueCatService.IsEntitledAsync` has exactly one caller
  (`TrainerClientService`), not a platform-wide premium refactor.
- No `TRANSFER` handling beyond the log-and-drop above.
- No HTTP-layer test of `RevenueCatWebhookController` itself, matching the
  existing gap around `StripeWebhookController` — the state machine and the
  service/endpoint-level authorization tests cover the logic; the controller
  is a thin, already-mirrored shim.
