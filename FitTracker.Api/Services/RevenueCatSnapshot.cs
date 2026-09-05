using FitTracker.Api.Models;

namespace FitTracker.Api.Services;

/// <summary>
/// The fields of a RevenueCat webhook event this system cares about, lifted
/// out of the raw JSON payload.
///
/// Keeping the decision logic on a plain record rather than the raw payload
/// is what lets the interesting rule — reordering — be tested without
/// constructing a webhook body or standing up an HTTP listener. See
/// <see cref="RevenueCatStateMachine"/> and <c>SubscriptionSnapshot</c> for
/// the Stripe equivalent this mirrors.
/// </summary>
public record RevenueCatSnapshot(
    Guid UserId,
    DateTime? ExpiresAt,
    DateTime EventTime);

/// <summary>Applies RevenueCat's view of a user's subscription onto a
/// <see cref="RevenueCatSubscription"/> row.</summary>
public class RevenueCatStateMachine
{
    /// <summary>
    /// Brings <paramref name="subscription"/> in line with
    /// <paramref name="snapshot"/>. Returns false if the event was stale and
    /// nothing was changed.
    ///
    /// This is a pure upsert of "whatever RevenueCat says the expiry is now",
    /// which makes it idempotent by construction — RevenueCat retries
    /// deliveries on a non-2xx response, so applying the same event twice has
    /// to be safe. Unlike <c>LicenceStateMachine.Apply</c>, there is no
    /// status/tier mapping to do: liveness is <c>RevenueCatSubscription.IsEntitled</c>,
    /// a pure function of <c>ExpiresAt</c> vs now, computed at read time —
    /// this method's only job is making sure <c>ExpiresAt</c> reflects the
    /// most recent event RevenueCat has actually sent.
    /// </summary>
    public bool Apply(RevenueCatSubscription subscription, RevenueCatSnapshot snapshot)
    {
        // Out-of-order delivery: a late renewal confirmation must not undo a
        // more recent cancellation/expiration that already superseded it, and
        // vice versa — whichever event is actually newest wins, unconditionally.
        if (subscription.LastEventAt is DateTime last && snapshot.EventTime < last)
        {
            return false;
        }

        subscription.ExpiresAt = snapshot.ExpiresAt;
        subscription.LastEventAt = snapshot.EventTime;
        return true;
    }
}
