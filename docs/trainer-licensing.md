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

## Setting it up

Everything above was already in the code, and none of it did anything in
production. The API reads four `Stripe:*` settings, and `deploy.yml`, the only
thing that ever configures the production API, passed none of them. So Cloud Run
booted with no key, logged "trainer licences will stay on the free tier", and
kept serving. Every test passed because the tests put the configuration in
themselves. The compiler couldn't see it either: `IConfiguration` is a string
lookup, and a missing key is just `null`. The warning at boot was the only
signal, and it's easy to miss among the other boot-time warnings.

You might think the quick fix is to type the variables into the Cloud Run
console. It isn't. `gcloud run deploy --set-env-vars` *replaces* the service's
whole environment, so the next push to `main` would quietly wipe them, and
trainers would drop back to "can't upgrade" with no code change to blame. A
setting has to come through the workflow, or it only lasts until the next
deploy.

### Two failure modes that look like something else

**API version mismatch shows up as a signature failure.** Stripe.net 52.3.0 pins
API version **`2026-07-29.dahlia`**. `EventUtility.ConstructEvent` refuses an
event serialised under a different version, and it throws the same
`StripeException` as a bad signature. `StripeWebhookController` catches it,
logs "Rejected a Stripe webhook with an invalid signature" and returns 400.
You'd end up checking a signing secret that was fine all along. Create the
webhook endpoint with its API version set to the SDK's version. When
you upgrade Stripe.net, check the pinned version
(`Stripe.StripeConfiguration.ApiVersion`) and update the endpoint to match
*before* deploying.

**A payment with no webhook just looks like a normal Free trainer.** Checkout only
needs the secret key, so a trainer can pay successfully. The licence changes
only when the webhook arrives. If the webhook secret is missing or wrong, Stripe
takes the money and the trainer stays on Free. That's why `deploy.yml` warns
specifically when the key is set but the webhook secret isn't.

### Steps

Do all of this in **test mode** first. Live mode has its own products, prices,
webhook endpoints, signing secrets and portal configuration. None of it carries
over, so going live means repeating these steps and swapping the secrets.

1. **Products and prices.** Create three products (Solo, Pro, Studio), each with
   one *recurring* price. Keep the per-seat constraint in "Tiers" above in mind.
   Copy each `price_…` id. Don't create a Free product: Free isn't bought.

2. **API key.** A restricted key (`rk_…`) is enough and safer than the full
   secret key. It needs write access to *Customers*, *Checkout Sessions*
   and *Customer portal*, and read access to *Subscriptions*. That's everything
   `TrainerLicenceService` calls.

3. **Webhook endpoint.** Developers → Webhooks → Add endpoint:

   | Field | Value |
   |---|---|
   | URL | `https://<cloud-run-host>/api/stripe/webhook` |
   | API version | `2026-07-29.dahlia` (must match Stripe.net, see above) |
   | Events | `checkout.session.completed`, `customer.subscription.created`, `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.payment_failed` |

   Copy its signing secret (`whsec_…`). Send only these events. Anything else
   is ignored, but every extra event is one more request on the webhook's
   rate-limit budget.

4. **Customer portal.** Settings → Billing → Customer portal. Allow payment-method
   updates, cancellation, and subscription *switching* between the three paid
   products only. This step enforces the "Free is never a downgrade target"
   rule, and nothing in the code backs it up. Cancel at period end rather than
   immediately, so a trainer keeps what they paid for up to the date they paid
   for it, and only then goes into grace.

5. **GitHub.** Settings → Secrets and variables → Actions:

   | Kind | Name | Value |
   |---|---|---|
   | Secret | `STRIPE_SECRET_KEY` | the `rk_…`/`sk_…` key |
   | Secret | `STRIPE_WEBHOOK_SECRET` | the `whsec_…` secret |
   | Variable | `STRIPE_PRICE_SOLO` / `_PRO` / `_STUDIO` | the three `price_…` ids |

   `WEB_ORIGIN` must also be set. Checkout's success and cancel URLs and the
   portal's return URL are built from it, and without it Stripe sends the
   trainer back to `http://localhost:5000`.

6. **Deploy** by running the *Deploy to Cloud Run* workflow manually
   (`workflow_dispatch`); nothing needs to land on `main`. Neither Stripe
   warning should appear in the job summary, and the API's boot log should
   have no `Stripe:` warnings.

7. **Test the whole flow.** Sign in as a trainer, open the plan screen, upgrade,
   and pay with `4242 4242 4242 4242`. Then check, in this order:
   - In the Stripe dashboard, the endpoint's event log shows 200 responses.
   - The plan screen shows the new tier and seat count.
   - A client of that trainer shows Pro.
   Then use the portal to switch plans and to cancel, and confirm each change
   reaches the plan screen. For a failed renewal, test clocks (Billing → Test
   clocks) with card `4000 0000 0000 0341` push a subscription into
   `past_due` without waiting a month.

### Running it locally

Put the same keys in user secrets (the API project already has a
`UserSecretsId`), using test-mode values:

```
dotnet user-secrets set "Stripe:SecretKey" "sk_test_…"   --project FitTracker.Api
dotnet user-secrets set "Stripe:Prices:Solo" "price_…"   --project FitTracker.Api
```

For webhooks, `stripe listen --forward-to localhost:5033/api/stripe/webhook`
prints a `whsec_…` of its own. Put that one in `Stripe:WebhookSecret`, not the
dashboard endpoint's secret. `stripe trigger customer.subscription.created`
won't do much here: it creates a customer that matches no licence, so all you
get is the "matched no licence" warning. Go through a real checkout instead.

### What the redirect back does, and doesn't do

Checkout sends the trainer back to `/#/trainer/licence?checkout=success`. The
web app uses path URLs (`usePathUrlStrategy`), so that fragment isn't a route.
The page reloads at `/`, `PostAuthHome` puts the trainer in the console, and
nothing reads `checkout=`. The plan screen loads fresh the next time it's
opened, so the upgrade does show up. But the webhook usually arrives a second
or two *after* the redirect, so a trainer who opens the plan screen straight
away can still see Free. A confirmation banner and a short re-poll on return
would fix that. This change doesn't add them.

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
