using FitTracker.Api.Models;

namespace FitTracker.Api.Services;

/// <summary>
/// The fields of a Stripe subscription this system cares about, lifted out of
/// the Stripe SDK's types.
///
/// The webhook translates Stripe's payload into one of these and hands it to
/// <see cref="LicenceStateMachine"/>. Keeping the decision logic on a plain
/// record rather than <c>Stripe.Subscription</c> is what lets the interesting
/// rules — grace windows, reordering, tier changes — be tested without
/// constructing SDK objects or standing up an HTTP listener.
/// </summary>
public record SubscriptionSnapshot(
    string SubscriptionId,
    string CustomerId,
    string? PriceId,
    string StripeStatus,
    DateTime? CurrentPeriodEnd,
    DateTime EventTime);

/// <summary>Applies Stripe's view of a subscription onto a licence.</summary>
public class LicenceStateMachine(LicencePlanCatalog catalog)
{
    private readonly LicencePlanCatalog _catalog = catalog;

    /// <summary>
    /// Brings <paramref name="licence"/> in line with <paramref name="snapshot"/>.
    /// Returns false if the event was stale and nothing was changed.
    ///
    /// This is a pure upsert of "whatever Stripe says the subscription is now",
    /// which makes it idempotent by construction — Stripe retries deliveries, so
    /// applying the same event twice has to be safe.
    /// </summary>
    public bool Apply(TrainerLicence licence, SubscriptionSnapshot snapshot)
    {
        // Out-of-order delivery: a late "payment failed" must not undo the
        // "payment succeeded" that already resolved it.
        if (licence.LastStripeEventAt is DateTime last && snapshot.EventTime < last)
        {
            return false;
        }

        licence.StripeSubscriptionId = snapshot.SubscriptionId;
        licence.StripeCustomerId = snapshot.CustomerId;
        licence.CurrentPeriodEnd = snapshot.CurrentPeriodEnd;
        licence.LastStripeEventAt = snapshot.EventTime;

        // An unrecognised price leaves the tier alone. Downgrading someone to
        // Free because a price id wasn't in config would strip Pro from their
        // whole roster over a configuration mistake.
        if (_catalog.TierForPrice(snapshot.PriceId) is LicenceTier tier)
        {
            licence.Tier = tier;
            licence.SeatLimit = LicencePlanCatalog.SeatsFor(tier);
        }

        licence.Status = MapStatus(snapshot.StripeStatus);

        if (licence.Status == LicenceStatus.Trialing)
        {
            // One trial per trainer. Without this, cancel-and-resubscribe would
            // mint a fresh 14 days of Pro every time.
            licence.HasUsedTrial = true;
        }

        if (licence.Status is LicenceStatus.Active or LicenceStatus.Trialing)
        {
            licence.GraceEndsAt = null;
        }
        else if (licence.GraceEndsAt == null)
        {
            // Started, not extended: repeated failures shouldn't let a trainer
            // ride an unpaid licence indefinitely by re-failing the same card.
            licence.GraceEndsAt = snapshot.EventTime + TrainerLicence.GracePeriod;
        }

        return true;
    }

    /// <summary>Collapses Stripe's subscription statuses onto ours. Anything
    /// unrecognised is treated as unhealthy rather than assumed fine.</summary>
    private static LicenceStatus MapStatus(string stripeStatus) => stripeStatus switch
    {
        "active" => LicenceStatus.Active,
        "trialing" => LicenceStatus.Trialing,
        "past_due" or "unpaid" or "incomplete" => LicenceStatus.PastDue,
        "canceled" or "incomplete_expired" or "paused" => LicenceStatus.Canceled,
        _ => LicenceStatus.PastDue,
    };
}
