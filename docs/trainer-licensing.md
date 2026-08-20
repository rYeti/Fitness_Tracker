# Trainer licensing and seat limits

Trainers hold a **licence**: a plan with a seat limit that caps how many clients
they can take on, and which determines whether ForgeForm Pro flows to them and
their clients. This document covers what the model guarantees, the two loopholes
it exists to close, and the configuration it needs.

## Tiers

| Tier | Seats | Console | Pro for trainer | Pro for clients |
|---|---|---|---|---|
| Free | 3 | ✅ | ❌ | ❌ |
| Solo | 10 | ✅ | ✅ | ✅ |
| Pro | 30 | ✅ | ✅ | ✅ |
| Studio | 100 | ✅ | ✅ | ✅ |

Seat counts live in `LicencePlanCatalog.SeatsByTier` — the only place they are
defined. **Prices do not live in the codebase.** The code maps a Stripe *price
id* to a tier, so the price ladder can be retuned in the Stripe dashboard
without a deploy or a migration.

> Pricing is not finalised. Two constraints to preserve whenever it is set:
> effective per-seat price should stay near the €4.89 consumer Pro price (see
> "Bulk-discount pooling" below), and a base component is warranted because
> console access and the trainer's own Pro don't scale with seat count.

## The two loopholes this closes

### Free Pro via self-invite

`AccessProvider.hasPremiumAccess` used to read `_isPremium || _isTrainerClient`.
Invite codes are free to mint, so anyone could register a second account, invite
themselves from it, redeem the code and hold a permanent Pro entitlement that
nobody paid for.

Two things close it, and both must stay closed:

1. **`TrainerLicence.GrantsPro` requires a non-Free tier.** A free-tier trainer's
   clients get the console relationship and no Pro. A self-invite on Free now
   yields a roster of one and nothing else.
2. **Pro is computed server-side** (`TrainerClientService.GetStatusAsync` →
   `proFromLicence`) and the client never derives premium from the existence of
   a relationship.

Regression tests: `TrainerLicenceTests.FreeTierNeverGrantsPro_HoweverHealthyTheLicence`,
`TrainerClientServiceTests.ATraineeOfAFreeTierTrainerGetsNoPro`, and
`test/trainer_console/access_provider_test.dart` ("being a trainer client grants
nothing by itself").

### Bulk-discount pooling

A paid licence gifts Pro to every client, so the *per-seat* price is a second
arbitrage surface: price seats far below the consumer Pro price and ten people
can pool, one paying as the "trainer", everyone getting Pro at a fraction of
list. Partly blunted structurally — a trainer sees all their clients' food and
training logs, so pooling means handing a near-stranger your data — but the
per-seat rate is the real lever.

## Seat accounting

A seat is consumed by an **Active** relationship *or* a **Pending, unexpired**
invite (`TrainerClientRepository.CountSeatsUsedAsync`). Outstanding invites count
because otherwise a trainer could mint any number of codes while under the limit
and blow past it the moment they were all redeemed. Trainers can withdraw an
unredeemed invite to reclaim its seat.

The limit is enforced **twice**:

- `CreateInviteAsync` — refuses at the limit.
- `AcceptInviteAsync` — **re-checks at redemption**. A code can be redeemed days
  later, by which point the trainer may have filled up or downgraded. Checking
  only at mint time makes the limit advisory rather than real.

Going over the limit **blocks new invites and never revokes existing clients**.
A trainer can therefore legitimately sit above their seat limit; the UI says so
plainly ("Nobody is removed, but you can't add more") rather than implying
clients are about to be cut loose.

## Lapse and grace

When Stripe reports a subscription unhealthy, the licence status changes and a
**14-day grace window** opens (`TrainerLicence.GracePeriod`). The window is
*started, not extended* — repeated failures on the same card must not let a
trainer ride an unpaid licence indefinitely.

| Phase | Console | Trainer Pro | Client Pro |
|---|---|---|---|
| Healthy | full | ✅ | ✅ |
| In grace | full, with a banner | ✅ | ✅ (client warned, `proEndsAt`) |
| Past grace | **read-only** | ❌ | ❌ |

Nothing is deleted at any point. Relationships survive, so paying restores the
console intact. Writes are blocked past grace by
`RequireEntitledLicenceFilter`, applied per-action next to the `[HttpPost]` so
that adding a new mutating endpoint is a deliberate choice.

Clients are warned during grace and offered their own Pro when it ends
(`_TraineeProNotice` in `main.dart`) — they did nothing wrong, and the first
they hear of it should not be a feature refusing to open.

## Two rules that stop the loopholes reopening

- **Free is only ever an initial state, never a downgrade target.** Configure the
  Stripe billing portal to allow cancel, payment-method updates, and paid↔paid
  switches *only*. If a trainer could move a full roster onto Free they would
  keep those seats permanently, because going over the limit blocks new invites
  rather than revoking clients. Cancelling instead routes through grace → not
  entitled, which self-corrects.
- **The 14-day trial requires a payment method** (`payment_method_collection:
  'always'`, set in `TrainerLicenceService.CreateCheckoutSessionAsync`). A
  cardless trial is the original attack with a 14-day reset. Combined with
  `TrainerLicence.HasUsedTrial`, the trial is one per customer.

## Becoming a trainer

A user becomes a trainer by asking for a licence: `POST api/TrainerLicence/me`,
reached from Settings → "Set up Trainer Console". This provisions Free/3/Active.

This replaced `IsTrainer = asTrainer.Count > 0`, which made you a trainer only if
you already had active clients — so a newly signed-up trainer was refused the
console, which is the only place they could invite their first client from.
Regression test: `TrainerClientServiceTests.AUserHoldingALicenceIsATrainerEvenWithNoClients`.

## Configuration

| Key | Purpose |
|---|---|
| `Stripe:SecretKey` | Server-side API key. Without it the API logs a warning at boot and every licence stays Free. |
| `Stripe:WebhookSecret` | Verifies webhook signatures. The webhook is anonymous — this is its entire authentication story. |
| `Stripe:Prices:Solo` / `:Pro` / `:Studio` | Price ids. A tier with no price can't be bought, and a webhook carrying that price can't be mapped back to a tier, so the API warns about unpriced tiers at boot. |

The success/cancel and portal return URLs are derived from
`Cors:AllowedOrigins[0]`, so the console's URL is configured in one place.

Webhook endpoint: `POST /api/stripe/webhook`. Anonymous, signature-verified,
excluded from CORS, on its own `"webhook"` rate-limit policy (generous and
partitioned globally, because Stripe retries in bursts and throttling a genuine
retry means a subscription change silently doesn't land).

Handled events: `checkout.session.completed`,
`customer.subscription.created|updated|deleted`, `invoice.payment_failed`. Every
handler is a pure upsert of "whatever Stripe says the subscription is now", so
replaying an event is a no-op. `TrainerLicence.LastStripeEventAt` guards against
out-of-order delivery — a late "payment failed" must not undo the "payment
succeeded" that already resolved it.

## Rollout

The `AddTrainerLicence` migration backfills a Free licence for every user who
already has active clients, with
`SeatLimit = GREATEST(3, active client count)`. **This is not optional**: from
that migration onward a user is a trainer because they hold a licence, so
without the backfill every existing trainer loses console access on deploy. The
`GREATEST` grandfathers anyone already over three clients rather than waking
them up over their limit.

The backfill uses `gen_random_uuid()`, built in from PostgreSQL 13.

## Known limitation

Premium quotas (meal templates, workout plans, plan durations) are still
enforced client-side against local SQLite. Deriving `hasPremiumAccess` from a
server-computed field closes the invite-code leak, which is the one that costs
money; it does not make premium tamper-proof against a modified client.
Server-side quota enforcement is deliberately out of scope.
