namespace FitTracker.Api.Services.Interfaces;

/// <summary>Handles inbound RevenueCat webhook events and answers whether a
/// user currently holds the app-store premium entitlement.</summary>
public interface IRevenueCatService
{
    /// <summary>Verifies <paramref name="authHeader"/> against the configured
    /// shared secret, parses <paramref name="payload"/>, and applies it.
    /// Throws <see cref="UnauthorizedAccessException"/> on a bad or missing
    /// header — the only authentication this endpoint has, since anyone can
    /// POST to it.</summary>
    Task HandleWebhookAsync(string payload, string? authHeader);

    /// <summary>Whether this user currently holds the RevenueCat premium
    /// entitlement. Independent of <see cref="ITrainerClientService.DerivesProAsync"/> —
    /// see docs/revenuecat-self-managed-pins.md for why the two are siblings,
    /// not merged.</summary>
    Task<bool> IsEntitledAsync(Guid userId);
}
