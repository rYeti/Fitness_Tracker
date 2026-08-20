using FitTracker.Api.DTOs;
using FitTracker.Api.Models;

namespace FitTracker.Api.Services.Interfaces;

public interface ITrainerLicenceService
{
    /// <summary>The caller's plan, provisioning a Free one if they don't have it.
    /// Calling this is how a user becomes a trainer.</summary>
    Task<TrainerLicenceDto> GetOrCreateAsync(Guid trainerId);

    /// <summary>Starts a Stripe Checkout session for the given tier and returns the
    /// URL to send the trainer to. Null if the tier isn't purchasable or has no
    /// configured price.</summary>
    Task<string?> CreateCheckoutSessionAsync(Guid trainerId, LicenceTier tier);

    /// <summary>Returns a Stripe billing-portal URL, or null if the trainer has no
    /// Stripe customer yet (they've never bought anything).</summary>
    Task<string?> CreatePortalSessionAsync(Guid trainerId);

    /// <summary>Applies a verified Stripe webhook payload. Safe to call repeatedly
    /// with the same event.</summary>
    Task HandleWebhookAsync(string payload, string signatureHeader);
}
