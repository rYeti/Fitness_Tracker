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

    /// <summary>When the entitlement RevenueCat last reported expires, or null
    /// if the winning event reported no expiry at all — RevenueCat omits
    /// <c>expiration_at_ms</c> entirely for a product that never expires (a
    /// lifetime purchase, or an "unlimited duration" promotional grant), and
    /// only for that case: an event for anything that actually ends —
    /// including <c>EXPIRATION</c> itself — always carries a real, if past,
    /// timestamp instead. Null therefore means "entitled with no expiry," not
    /// "not entitled" — see <see cref="IsEntitled"/>, which uses
    /// <see cref="LastEventAt"/> to tell that apart from no event ever having
    /// been recorded.</summary>
    public DateTime? ExpiresAt { get; set; }

    /// <summary>Timestamp of the most recent RevenueCat event applied. RevenueCat
    /// retries and can deliver out of order, so an event older than this one is
    /// stale and must be ignored — the same guard
    /// <see cref="TrainerLicence.LastStripeEventAt"/> provides for Stripe. Also
    /// what tells a genuine "no expiry" grant (<see cref="ExpiresAt"/> null,
    /// this set) apart from a row nothing has ever applied to (both null).</summary>
    public DateTime? LastEventAt { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>Whether this user currently holds the entitlement. An event
    /// must have been recorded at all (<see cref="LastEventAt"/>), and then
    /// either no expiry was ever reported for it, or the reported expiry is
    /// still in the future — an EXPIRATION event needs no special handling
    /// beyond that, because its own expiration timestamp already puts us in
    /// the past by the time anyone reads this.</summary>
    public bool IsEntitled =>
        LastEventAt is not null && (ExpiresAt is null || ExpiresAt > DateTime.UtcNow);
}
