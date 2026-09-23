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

## Pricing

| Tier | Seats | Monthly (net of VAT) | Yearly (net of VAT) | Per seat, full roster |
|---|---|---|---|---|
| Free | 3 | €0 | — | — |
| Solo | 10 | **€59** | €590 | €5.90 |
| Pro | 30 | **€139** | €1,390 | €4.63 |
| Studio | 100 | **€349** | €3,490 | €3.49 |

These are the figures to enter in Stripe. They live there and nowhere else, so
this table is the record of intent, not a source of truth — if the two ever
disagree, Stripe is what trainers are actually charged. Prices are quoted net of
VAT because a trainer is buying a business tool: EU trainers outside Germany with
a VAT ID are reverse-charged, and German trainers reclaim it. Yearly is two
months free.

### How the numbers were reached

A paid licence sells two different things at once, and the first draft of this
table priced only one of them.

**What a seat costs ForgeForm.** Every client on a paid licence gets Pro, and a
client who gets Pro from their trainer is a client who doesn't buy it. Consumer
Pro is €4.89 including 19% VAT, which is €4.11 net, and the store keeps 15% of
that, leaving about **€3.49** a month. That forgone revenue is the real marginal
cost of a seat. Infrastructure is noise beside it: a client's share of Postgres
and Cloud Run is roughly €0.05–0.15 a month, and chat attachments on Cloudflare
R2 — free egress, about $0.015 per GB stored, a 45-day retention window and
8/16 MB upload caps — stay under €0.02 even for a heavy user. The costs that
matter on the infrastructure side are fixed rather than per client: the Postgres
instance, and Cloud Run keeping an instance alive for as long as any SignalR
socket is open, since it bills an open WebSocket as a request in flight. Together
that is on the order of €50–100 a month for the whole service, which three Solo
licences pay for.

**What the licence is worth to a trainer.** The first draft stopped there: it
set the per-seat rate just above €3.49 and called it done. That covered the Pro
being handed to clients and charged almost nothing for the console itself — the
roster, chat, the workout builder, nutrition monitoring — which is the thing the
trainer is actually buying, and the thing competing coaching tools charge for on
its own without giving clients anything. Cost-plus pricing on the seat gave the
product away.

So each tier is built from two parts:

| Tier | Platform fee | Seat component | Price |
|---|---|---|---|
| Solo | ~€25 | 10 × €3.50 | €59 |
| Pro | ~€40 | 30 × €3.30 | €139 |
| Studio | ~€60 | 100 × €2.90 | €349 |

The **platform fee** is the console and the trainer's own Pro. Neither scales
with roster size, which is why it exists as a separate component at all, and it
is priced on value rather than cost. The **seat component** passes through the
Pro each client receives, tapering slightly with volume but staying close to the
€3.49 it replaces.

The sanity check is the trainer's own revenue. Online coaching commonly runs
around €100 per client per month, so a full Solo roster turns over about €1,000
and €59 is roughly 6% of it; Pro is about 5% and Studio about 3.5%. Business
tools are routinely priced at 3–10% of the revenue they support, and a licence
that saves a trainer one lost client or a few hours of admin a month has paid
for itself.

### What the prices must keep doing

Two constraints outlive these particular numbers, and any retune in Stripe has
to respect both:

1. **The per-seat price on a small tier must not undercut consumer Pro.** This is
   what closes bulk-discount pooling (below). At €59, a full Solo roster costs
   €7.02 per seat including VAT — more than buying Pro directly, so ten people
   splitting a "trainer" licence to get Pro cheaply would each pay more, not
   less. Studio's per-seat rate does sit below consumer Pro, deliberately: a
   hundred strangers pooling one account, each handing their food and training
   logs to whoever pays, is not a realistic attack.
2. **There is a base component.** A trainer with six clients on Solo still pays
   €59, because the console and their own Pro cost the same whether the roster
   is full or not. Pricing purely per seat would make a half-empty roster nearly
   free and charge nothing for the product.

The general lesson is the one the first draft got wrong: **when a plan bundles a
cost you pass through with a product you sell, price them separately.** Covering
the pass-through looks like a finished price because nothing is lost on it — the
books balance — but everything the product is worth has been given away, and no
spreadsheet of costs will show that, because the missing number is value, not
cost.

### Not built yet

A console-only tier (roughly €25–29, no Pro for clients) would suit trainers
whose clients don't need premium features. It would mean a tier for which
`TrainerLicence.GrantsPro` is false despite being paid, which changes the rule
that every paid tier grants Pro. Leave it until trainers ask for it.

The plan screen should say plainly that clients get ForgeForm Pro included
(worth €4.89 a month each) — it is the main thing that sets the licence apart
from other coaching tools, and it is easy to miss.

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
per-seat rate is the real lever. "Pricing" above sets it: a full Solo roster
costs more per seat than consumer Pro, so pooling saves nothing.

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

**Trainer is an account type, chosen at registration.** `POST api/auth/register`
takes an `accountType` of `Trainee` (the default) or `Trainer`; registering as a
trainer provisions Free/3/Active in `AuthService.RegisterAsync`. That call to
`ITrainerLicenceRepository.CreateFreeAsync` is the **only** place a licence is
ever created. There is deliberately no way to convert an existing account, and
the trainee app offers no route to one.

It used to be self-serve from Settings → "Set up Trainer Console", which opened
the plan screen — and the plan screen's own load, `GET api/TrainerLicence/me`,
was a get-or-create. So *reading* your plan provisioned one: an ordinary user who
opened that screen once became a permanent trainer, with three free seats and, on
web, a console they landed in on every subsequent sign-in. Every licence endpoint
is now a pure read plus a `not_a_trainer` refusal, and the repository exposes
`CreateFreeAsync` rather than `GetOrCreateAsync` so no read *can* provision.
Regression tests: `TrainerProvisioningTests`.

`IsTrainer = licence != null` is unchanged and still correct — it replaced
`IsTrainer = asTrainer.Count > 0`, which made you a trainer only if you already
had active clients, so a newly signed-up trainer was refused the console, the
only place they could invite their first client from. Regression test:
`TrainerClientServiceTests.AUserHoldingALicenceIsATrainerEvenWithNoClients`.

Free remains an entry state rather than something bought: Stripe is only involved
in *upgrading* an account that is already a trainer, and `checkout-session` /
`portal-session` refuse a caller with no licence.

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
