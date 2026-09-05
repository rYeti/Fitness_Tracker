namespace FitTracker.Api.Models;

/// <summary>
/// A user's own app-store subscription, as reported by RevenueCat — the only
/// server-side record of "device-side IAP premium"
/// (<c>AccessProvider._isPremium</c> on the client), which until this existed
/// was invisible to the API entirely. Independent of <see cref="TrainerLicence"/>:
/// a trainer's Pro and a plain user's own purchase are two separate sources
/// of premium, exactly as the client already OR's them together in
/// <c>AccessProvider.hasPremiumAccess</c>.
/// </summary>
/// <remarks>
/// Deliberately does not store a computed "is this active" flag. RevenueCat's
/// webhook sends an expiration timestamp on every event that matters; a bool
/// derived from an event's *type* and then trusted forever is exactly the
/// shape of stale-derived-state bug this codebase's sync and chat docs keep
/// finding. See <see cref="IsEntitled"/> and
/// <c>docs/revenuecat-self-managed-pins.md</c>.
/// </remarks>
public class RevenueCatSubscription
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>The user this subscription belongs to. Unique — RevenueCat's
    /// <c>app_user_id</c> is always set to this server's own user UUID at
    /// login (<c>Purchases.logIn(userId)</c>), so one row per user is exact,
    /// not an approximation.</summary>
    public Guid UserId { get; set; }
    public User User { get; set; } = null!;

    /// <summary>When the entitlement RevenueCat last reported expires. Null
    /// means no event has ever been recorded for this user.</summary>
    public DateTime? ExpiresAt { get; set; }

    /// <summary>Timestamp of the most recent RevenueCat event applied. RevenueCat
    /// retries and can deliver out of order, so an event older than this one is
    /// stale and must be ignored — the same guard
    /// <see cref="TrainerLicence.LastStripeEventAt"/> provides for Stripe.</summary>
    public DateTime? LastEventAt { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>Whether this user currently holds the entitlement. A pure
    /// function of "now" vs the last-reported expiry — an EXPIRATION event
    /// needs no special handling, because its own expiration timestamp
    /// already puts us in the past by the time anyone reads this.</summary>
    public bool IsEntitled => ExpiresAt is DateTime exp && exp > DateTime.UtcNow;
}
