# The rate limiter is honest only because there's one instance

An automated scan flagged `Program.cs`'s `AddRateLimiter` block as suspiciously
in-memory, on the theory that Cloud Run can run more than one instance of the
API and each would count independently. This document verifies that claim,
explains why it was real but not yet dangerous, and records the one-line fix
that keeps it that way. Line references are to the commit that introduces this
document.

---

## 1. What's actually being throttled

`Program.cs:104-140` defines three fixed-window policies via
`AddRateLimiter`, each applied with `[EnableRateLimiting("…")]` on specific
controller actions — the limiter is not global:

| Policy | Limit | Partition key | Applied to |
|---|---|---|---|
| `auth` | 5 / minute | client IP | `AuthController`: `login`, `register`, `forgot-password`, `reset-password` |
| `invite` | 10 / minute | client IP | `TrainerClientController`: invite redemption |
| `webhook` | 300 / minute | fixed string `"stripe-webhook"` (global, not per-IP) | `StripeWebhookController` |

`auth` is the one that matters. It's not traffic shaping — it's the only
thing standing between `POST /api/auth/login` and an unlimited password-guessing
loop against a real account. `invite` is the same shape of guard for a lower-
stakes surface (a redeemable code, not a password). `webhook` is deliberately
partitioned globally rather than per-IP, because Stripe retries in bursts from
its own address range and per-IP throttling would mean a legitimate retry
silently doesn't land — a different problem with a different fix, out of
scope here.

## 2. Confirming the in-memory claim

`RateLimitPartition.GetFixedWindowLimiter` — the factory every policy above
uses — is `Microsoft.AspNetCore.RateLimiting`'s built-in in-process limiter.
It has no notion of a distributed backing store; the state (the current
window's count per partition key) lives in a `ConcurrentDictionary` inside the
process that received the request. There is no built-in ASP.NET Core option
that makes `AddRateLimiter` distributed — that requires writing a custom
`PartitionedRateLimiter` against something like Redis, which is a materially
bigger piece of infrastructure than a `RateLimitPartition` factory call.

So the scan's technical premise is correct: two instances of this API, both
enforcing the `auth` policy, do not share a counter. An attacker (or a client
with a broken retry loop) hitting `/api/auth/login` against a Cloud Run
service fronted by a load balancer gets `5 × N` attempts per minute, not 5,
where N is however many instances happen to be up.

## 3. Why the compiler and the tests had nothing to say about it

`FixedWindowRateLimiterOptions { PermitLimit = 5, Window = TimeSpan.FromMinutes(1) }`
is exactly correct C# for "5 requests per minute." Nothing about the type
signature, the option name, or a unit test hitting the endpoint six times in a
row on a single test host reveals that the number means something different
once the process is replicated. A test suite runs one process. Cloud Run's
autoscaling is a deployment-time property with no representation in the code
at all — the defect isn't in `Program.cs`, it's in the gap between what
`Program.cs` assumes about its own topology and what `deploy.yml` actually
provisions. That gap is invisible to anything that runs the API once.

## 4. Was the dilution actually unbounded?

Before this change, `.github/workflows/deploy.yml`'s `gcloud run deploy` step
passed no `--max-instances` flag at all. Cloud Run's default ceiling (100
per service, absent an explicit flag) applied, so under sustained load the
`auth` policy's real-world ceiling could be 500 requests/minute per IP rather
than 5 — a two-orders-of-magnitude gap between the intended guard and the
enforced one, and one that gets worse precisely when an attacker is generating
enough load to trigger autoscaling in the first place.

A second, unrelated feature branch (`claude/signalr-backplane`) is adding
end-to-end chat encryption; despite the name, at the time of this check it
does not add a Redis backplane or touch `deploy.yml`. No branch anywhere in
the repo — local or on `origin` — caps `--max-instances`. So the dilution was
real, current, and unbounded, not a future risk contingent on some other
change landing.

## 5. The fix, and why it's the right size for this problem

`deploy.yml` now passes `--max-instances=1`. With one instance, the in-memory
partition *is* the whole picture — the fixed-window limiter's counter is
correct by construction, because there is nothing else to be inconsistent
with.

This was chosen over building a distributed limiter for two reasons:

- **A Redis-backed `PartitionedRateLimiter` is a real piece of infrastructure**,
  not a config flag — provisioning, connection resilience, and a fallback
  behaviour for when Redis itself is unavailable (fail open and lose the
  guard, or fail closed and take login down with it). That's a deliberate
  follow-up, not something to bolt on unilaterally while verifying a scan
  result.
- **The API already has an unrelated, pre-existing reason to want a single
  instance**: `AddSignalR()` (`Program.cs`) has no backplane configured
  either, so chat groups are also tracked in-memory per instance today. A
  second instance wouldn't just dilute the rate limiter — it would silently
  drop chat messages between two clients unlucky enough to land on different
  instances. `--max-instances=1` is the fix both problems already needed, not
  a cap invented to serve the rate limiter alone.

The comment left in `deploy.yml` says why in place, and says explicitly what
has to be true before this cap can be lifted: a distributed rate limiter
partition *and* a SignalR backplane, not just one of the two.

## 6. The general lesson

A number in an options object (`PermitLimit = 5`) is only as true as the
process topology it was written against. Nothing enforces that relationship
across a config file boundary — `Program.cs` doesn't know how many replicas
`deploy.yml` will start, and `deploy.yml` doesn't know that `Program.cs` is
counting on there being exactly one. When a guard's correctness depends on an
assumption like that, the assumption needs to be written down next to the
knob that could break it (here, the `--max-instances` flag), not left
implicit — otherwise the next person to "fix" scaling by removing the cap has
no way to know they've just turned a 5-attempts-per-minute guard into a
500-attempts-per-minute one.
