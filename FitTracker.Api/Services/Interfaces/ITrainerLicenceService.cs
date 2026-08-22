using FitTracker.Api.DTOs;
using FitTracker.Api.Models;

namespace FitTracker.Api.Services.Interfaces;

public interface ITrainerLicenceService
{
    /// <summary>The caller's plan, or null if they aren't a trainer. A pure read:
    /// it never provisions, so no amount of looking makes someone a trainer.</summary>
    Task<TrainerLicenceDto?> GetMineAsync(Guid trainerId);

    /// <summary>Whether the user holds a licence at all. Cheaper than
    /// <see cref="GetMineAsync"/> (no seat count) for endpoints that only need to
    /// turn a non-trainer away.</summary>
    Task<bool> IsTrainerAsync(Guid userId);

    /// <summary>Starts a Stripe Checkout session for the given tier and returns the
    /// URL to send the trainer to. Null if the caller isn't a trainer, or the tier
    /// isn't purchasable or has no configured price.</summary>
    Task<string?> CreateCheckoutSessionAsync(Guid trainerId, LicenceTier tier);

    /// <summary>Returns a Stripe billing-portal URL, or null if the trainer has no
    /// Stripe customer yet (they've never bought anything).</summary>
    Task<string?> CreatePortalSessionAsync(Guid trainerId);

    /// <summary>Applies a verified Stripe webhook payload. Safe to call repeatedly
    /// with the same event.</summary>
    Task HandleWebhookAsync(string payload, string signatureHeader);
}
