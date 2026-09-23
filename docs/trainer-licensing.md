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

| Tier | Seats | Monthly (net of VAT) | Yearly (net of VAT) | Per seat, full roster, incl. VAT |
|---|---|---|---|---|
| Free | 3 | €0 | — | — |
| Solo | 10 | **€44** | €440 | €5.24 |
| Pro | 30 | **€89** | €890 | €3.53 |
| Studio | 100 | **€179** | €1,790 | €2.13 |

These are the figures to enter in Stripe. They live there and nowhere else, so
this table records what was intended, not what is charged — if the two ever
disagree, Stripe wins. Prices are quoted net of VAT because a trainer is buying
a business tool: EU trainers outside Germany with a VAT ID are reverse-charged,
and German trainers reclaim it. Yearly is two months free.

### How the numbers were reached

This ladder is the third one proposed, and each earlier draft failed in a way
worth recording, because neither failure shows up in a spreadsheet of costs.

**Draft one priced the pass-through and gave away the product.** Every client on
a paid licence gets Pro. Consumer Pro is €4.89 including 19% VAT — €4.11 net,
about **€3.49** after the store's 15% — so the first draft treated €3.49 as the
cost of a seat and priced each tier just above seats × €3.49. The books balanced,
which is exactly why it looked finished. But that covered only the Pro handed to
clients, and charged almost nothing for the console itself — roster, chat, the
workout builder, nutrition monitoring — which is the thing a trainer is actually
buying.

**Draft two fixed that by adding a platform fee on top** (€59 / €139 / €349),
and was then checked against what trainers can buy instead. It lost badly at the
top: a 100-client Studio at €349 was twice the market. The competitor check also
exposed that draft one's cost floor was wrong in the first place.

**€3.49 is the worst case, not the cost of a seat.** It is revenue forgone *if*
that client would otherwise have bought Pro, and most wouldn't — consumer apps
convert a few percent of users to paid, and a trainer's clients signed up
because their trainer asked them to, not because they went looking for a
premium tracker. What giving a client Pro actually costs is their share of the
infrastructure plus the handful who would have paid:

| Cost | Per client per month |
|---|---|
| Postgres and Cloud Run | ~€0.05–0.15 |
| Chat attachments on Cloudflare R2 (free egress, ~$0.015/GB stored, 45-day retention, 8/16 MB caps) | < €0.02 |
| Forgone consumer Pro | €3.49 × the share who would have bought it |

The costs that matter on the infrastructure side are fixed rather than per
client: the Postgres instance, and Cloud Run keeping an instance alive for as
long as any SignalR socket is open, since it bills an open WebSocket as a
request in flight. Together that is on the order of €50–100 a month for the
whole service. Even a full Studio roster where one client in ten would have
bought Pro costs about €15 in infrastructure and €35 in forgone revenue against
€179 of licence.

**So the price is set by the market, and the floor is only there to stop
pooling.** What trainers could buy instead, in 2026, per month:

| Clients | Trainerize | TrueCoach | Everfit |
|---|---|---|---|
| ~5 | $23 | $20 | free |
| 15–20 | $50 (15) | $53 (20) | — |
| 30–50 | $79 (30) | $107 (50) | ~$75–95 |
| 100 | — | — | ~$140 |
| Nutrition add-on | +$20–45 | — | +$33–39 |

Trainerize and Everfit sell nutrition separately; ForgeForm includes it. None
of them give clients a premium app. Like for like — nutrition included — the
market sits around $70 for 15 clients, $110–125 for 30 and $175 for 100. Solo
and Pro come in below that, and Studio level with it while still giving every
client Pro. Competitor prices move; re-check them before retuning.

### What the prices must keep doing

Two constraints outlive these particular numbers, and any retune in Stripe has
to respect both:

1. **Small tiers must not undercut consumer Pro per seat.** This is what closes
   bulk-discount pooling (below) — not cost recovery. At €44 net, a full Solo
   roster costs €5.24 per seat including VAT, above the €4.89 of buying Pro
   directly, so ten people splitting a "trainer" licence to get Pro cheaply
   would each pay more. Pro and Studio deliberately sit below that line: thirty
   or a hundred strangers pooling one account, each handing their food and
   training logs to whoever pays, is not a realistic attack. A `€44 including
   VAT` Solo (€36.97 net, €4.40 a seat) was considered and rejected for exactly
   this reason — it made pooling pay by 10%.
2. **There is a base component.** A trainer with six clients on Solo still pays
   €44, because the console and their own Pro cost the same whether the roster
   is full or not. Pricing purely per seat would make a half-empty roster
   nearly free and charge nothing for the product.

The general lesson is the one both earlier drafts got wrong from opposite
directions: **a price has a floor, a ceiling and a value, and each comes from a
different place.** The floor comes from cost and abuse — here, pooling. The
ceiling comes from what the buyer can get elsewhere. The value sits in between.
Draft one found only the floor and mistook it for the price; draft two added
value and never looked at the ceiling. None of the three shows up by looking at
your own costs harder.

### Not built yet

A console-only tier (no Pro for clients) would suit trainers whose clients don't
need premium features. It would mean a tier for which `TrainerLicence.GrantsPro`
is false despite being paid, which changes the rule that every paid tier grants
Pro. Leave it until trainers ask for it.

The plan screen should say plainly that clients get ForgeForm Pro included
(worth €4.89 a month each) and that nutrition is included rather than an
add-on — those, plus the German localisation and end-to-end encrypted chat, are
what set the licence apart from the tools in the table above, and they are easy
to miss.

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
