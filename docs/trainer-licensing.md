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

## Going live

Everything above describes what the code does once Stripe is configured. This
section covers getting it configured in production, and why production had been
running without it.

### What was missing, and why nothing complained

`deploy.yml` builds the API's whole environment into one `--set-env-vars` string,
and until this section was written that string had no Stripe key in it. The
production API therefore booted with no `Stripe:SecretKey`, logged the warning
from `Program.cs`, and kept every trainer on Free. Nothing failed. That is by
design: the API is supposed to *degrade* rather than refuse to start when an
optional integration is missing, the same way it treats FCM and R2. The cost of
that design is that nobody notices a missing setting until they go looking for
the feature.

The compiler has no view of this, because configuration is a string lookup
resolved at runtime, and the test suite doesn't either, because every Stripe
test supplies its own configuration. There was also an obvious-looking fix that
would not have worked: typing the key into the Cloud Run console by hand.
`--set-env-vars` *replaces* the service's environment rather than merging into
it, so the next push to `main` would silently delete a key added that way. The
workflow is the only place a production setting can live.

The workflow now passes five values, following the same secrets-versus-variables
split it already uses for R2:

| GitHub setting | Kind | Becomes | Value |
|---|---|---|---|
| `STRIPE_SECRET_KEY` | secret | `Stripe__SecretKey` | `sk_live_…` or, better, a restricted `rk_live_…` key (see below) |
| `STRIPE_WEBHOOK_SECRET` | secret | `Stripe__WebhookSecret` | `whsec_…` from the live webhook endpoint |
| `STRIPE_PRICE_SOLO` | variable | `Stripe__Prices__Solo` | `price_…` |
| `STRIPE_PRICE_PRO` | variable | `Stripe__Prices__Pro` | `price_…` |
| `STRIPE_PRICE_STUDIO` | variable | `Stripe__Prices__Studio` | `price_…` |

Price ids are variables because they aren't sensitive and retuning one shouldn't
mean rotating a secret. None of the five can contain a comma, which is what
makes it safe to append them to the comma-joined string without base64. The FCM
JSON needed base64 because it does contain commas.

The workflow warns when the key is missing. It warns more pointedly when the key
is present and the webhook secret is not, because that is the worse
half-configuration: Checkout works, trainers pay, and every event that should
upgrade their licence is rejected.

### Test mode and live mode are separate worlds

Stripe keeps products, prices, customers, webhook endpoints and portal
configuration separately for each mode. A price id created in test mode doesn't
exist in live mode. A live key paired with test price ids fails every checkout
with "No such price". A `whsec_` secret from the test-mode endpoint rejects
every live event as a bad signature. The five values in the table must all come
from live mode. The test-mode set belongs in local user-secrets, never in the
workflow.

### The webhook's API version must match the SDK

`EventUtility.ConstructEvent` checks the event's `api_version` against the
version the installed Stripe.net was built for. Stripe.net 52.3.0 is built for
**`2026-07-29.dahlia`**. If they differ, the method throws a `StripeException`,
and the controller treats every `StripeException` as a bad signature. So a
mismatched endpoint shows up in the logs as "invalid signature" for every event,
which points at the secret when the version is the real cause.

Create the live endpoint with its API version set to the SDK's. When Stripe.net
is upgraded, check whether its pinned version moved and update the endpoint in
the same change.

### Dashboard checklist (live mode)

1. **Activate the account.** Add business details, a bank account for payouts,
   and a public business name and statement descriptor. Checkout shows these to
   the trainer.
2. **Products and prices.** Create one product per purchasable tier (Solo, Pro,
   Studio), each with a recurring price. Free gets no product. "Copy to live
   mode" on a test product works, but copying gives the price a new id. The
   ids go in the three variables.
3. **Customer portal** (Settings → Billing → Customer portal). Allow payment
   method updates, invoice history and cancellation. Allow subscription updates
   only between the three prices above. There is no Free price for a trainer to
   switch to, which is how "Free is never a downgrade target" is enforced (see
   above). Set cancellation to happen at the end of the billing period, so a
   trainer keeps what they paid for.
4. **Webhook endpoint** (Developers → Webhooks). URL
   `https://<cloud-run-host>/api/stripe/webhook`, API version
   `2026-07-29.dahlia`, events `checkout.session.completed`,
   `customer.subscription.created`, `customer.subscription.updated`,
   `customer.subscription.deleted`, `invoice.payment_failed`. Copy its signing
   secret into `STRIPE_WEBHOOK_SECRET`.
5. **Failed payments** (Settings → Billing → Subscriptions and emails). Turn on
   Smart Retries and the failed-payment and trial-ending emails. Whatever the
   retries end in, the licence lands in grace and then read-only, because the
   state machine acts on the subscription's status rather than on how Stripe
   reached it.
6. **API key.** Prefer a restricted key with write access to Customers,
   Checkout Sessions and Customer portal sessions, and read access to
   Subscriptions. Those are the only calls `TrainerLicenceService` makes. If the
   key leaks, it can't issue refunds or read payouts.
7. **Tax.** If you charge VAT, turn on Stripe Tax before launch. Checkout only
   collects it when the session asks for it, so enabling it is a code change,
   not only a dashboard setting.

### Checking it end to end

Set `WEB_ORIGIN` first. Checkout's success and cancel URLs and the portal's
return URL are built from `Cors:AllowedOrigins[0]`, and without it they fall
back to `http://localhost:5000`. After the deploy:

- The Cloud Run logs should contain neither Stripe warning from `Program.cs`.
- Send a test event from the dashboard's webhook page. It should get a 200, and
  the log should say "Ignoring unhandled Stripe event" (a test event matches no
  licence). A 400 means the secret or API version is wrong.
- Upgrade a real trainer account with a real card, confirm the tier and seat
  count change on the plan screen, then cancel from the portal and refund the
  charge.

### The general lesson

An integration that degrades gracefully when it is unconfigured looks exactly
like one that works, until someone uses the feature. Two habits prevent that.
Adding a configuration key to the code and adding it to the deploy pipeline
belong in the same change. And a boot warning only helps if someone reads the
logs after the first deploy, so read them.

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
