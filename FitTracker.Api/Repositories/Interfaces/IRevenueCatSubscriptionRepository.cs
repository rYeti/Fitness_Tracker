using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

/// <summary>Data access for a user's own app-store subscription, as reported
/// by RevenueCat. See <see cref="RevenueCatSubscription"/>.</summary>
public interface IRevenueCatSubscriptionRepository
{
    Task<RevenueCatSubscription?> GetByUserAsync(Guid userId);

    /// <summary>Whether this user currently holds the entitlement — the one
    /// question every caller outside the webhook actually needs answered,
    /// without having to know how it's stored.</summary>
    Task<bool> IsEntitledAsync(Guid userId);

    /// <summary>Returns this user's row, creating (but not yet saving) one if
    /// this is the first event ever recorded for them. Auto-creating is safe
    /// here, unlike a get-or-create for a <see cref="Models.TrainerLicence"/>
    /// would be: RevenueCat's <c>app_user_id</c> is always this server's own
    /// user UUID, set at login, so the user row already exists by the time
    /// RevenueCat can send a webhook about them, and a subscription row
    /// carries no entitlement of its own until <see cref="SaveAsync"/> sets
    /// one.</summary>
    Task<RevenueCatSubscription> GetOrCreateAsync(Guid userId);

    /// <summary>Persists a change to an already-fetched subscription (via
    /// <see cref="GetOrCreateAsync"/> or <see cref="GetByUserAsync"/>).</summary>
    Task SaveAsync(RevenueCatSubscription subscription);
}
