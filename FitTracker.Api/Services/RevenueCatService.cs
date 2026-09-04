using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

public class RevenueCatService(
    IRevenueCatSubscriptionRepository repository,
    RevenueCatStateMachine stateMachine,
    IConfiguration configuration,
    ILogger<RevenueCatService> logger) : IRevenueCatService
{
    private readonly IRevenueCatSubscriptionRepository _repository = repository;
    private readonly RevenueCatStateMachine _stateMachine = stateMachine;
    private readonly IConfiguration _configuration = configuration;
    private readonly ILogger<RevenueCatService> _logger = logger;

    /// <summary>The RevenueCat entitlement identifier this app grants premium
    /// for. Must match <c>premiumEntitlementId</c> in
    /// fittnes_tracker/lib/core/providers/access_provider.dart — kept as a
    /// constant rather than config because a mismatch here fails silently
    /// (the entitlement id just never matches, no error raised), so both
    /// sides living as a plain, greppable string is safer than one of them
    /// depending on an environment variable staying in sync.</summary>
    private const string EntitlementId = "ForgeForm Pro";

    /// <inheritdoc/>
    public async Task HandleWebhookAsync(string payload, string? authHeader)
    {
        var secret = _configuration["RevenueCat:WebhookAuthHeader"];
        if (string.IsNullOrWhiteSpace(secret))
        {
            throw new InvalidOperationException("RevenueCat:WebhookAuthHeader is not configured.");
        }

        // RevenueCat has no HMAC signature the way Stripe does — the dashboard
        // lets you configure an arbitrary shared-secret string that's echoed
        // back verbatim in the Authorization header on every delivery. A
        // constant-time compare avoids leaking the secret's length/prefix
        // through response-timing, the way a plain `==` would.
        if (!FixedTimeEquals(authHeader, secret))
        {
            throw new UnauthorizedAccessException("RevenueCat webhook Authorization header did not match.");
        }

        var snapshot = Parse(payload);
        if (snapshot == null) return;

        var subscription = await _repository.GetOrCreateAsync(snapshot.UserId);
        if (_stateMachine.Apply(subscription, snapshot))
        {
            await _repository.SaveAsync(subscription);
        }
    }

    /// <inheritdoc/>
    public async Task<bool> IsEntitledAsync(Guid userId) => await _repository.IsEntitledAsync(userId);

    /// <summary>Extracts the fields we act on, or null for a payload we don't
    /// handle — an unparseable <c>app_user_id</c>, an event carrying none of
    /// our entitlement ids, or a <c>TRANSFER</c> (moving a subscription
    /// between app_user_ids — a real edge case with real complexity this
    /// app's login flow, always <c>Purchases.logIn(serverUserId)</c>, isn't
    /// expected to hit; deliberately unhandled rather than silently
    /// mishandled).</summary>
    private RevenueCatSnapshot? Parse(string payload)
    {
        using var doc = JsonDocument.Parse(payload);
        if (!doc.RootElement.TryGetProperty("event", out var evt)) return null;

        var type = evt.TryGetProperty("type", out var typeProp) ? typeProp.GetString() : null;
        if (type == "TRANSFER")
        {
            _logger.LogWarning(
                "Ignoring a RevenueCat TRANSFER event — not handled, see RevenueCatService.Parse");
            return null;
        }

        if (!evt.TryGetProperty("app_user_id", out var userIdProp)
            || !Guid.TryParse(userIdProp.GetString(), out var userId))
        {
            _logger.LogWarning("RevenueCat event's app_user_id was not a parseable user id");
            return null;
        }

        var entitlementIds = evt.TryGetProperty("entitlement_ids", out var idsProp)
            && idsProp.ValueKind == JsonValueKind.Array
                ? idsProp.EnumerateArray().Select(e => e.GetString()).ToArray()
                : [];
        if (!entitlementIds.Contains(EntitlementId))
        {
            // An event about a different entitlement (or product) than the
            // one this app grants premium for — not an error, just nothing to do.
            return null;
        }

        DateTime? expiresAt = evt.TryGetProperty("expiration_at_ms", out var expProp)
            && expProp.ValueKind == JsonValueKind.Number
                ? DateTimeOffset.FromUnixTimeMilliseconds(expProp.GetInt64()).UtcDateTime
                : null;

        var eventTimeMs = evt.TryGetProperty("event_timestamp_ms", out var tsProp)
            && tsProp.ValueKind == JsonValueKind.Number
                ? tsProp.GetInt64()
                : DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();

        return new RevenueCatSnapshot(
            UserId: userId,
            ExpiresAt: expiresAt,
            EventTime: DateTimeOffset.FromUnixTimeMilliseconds(eventTimeMs).UtcDateTime);
    }

    private static bool FixedTimeEquals(string? actual, string expected)
    {
        if (actual == null) return false;
        // CryptographicOperations.FixedTimeEquals requires equal-length
        // inputs, and branching on a length mismatch before calling it would
        // leak the secret's length through response timing. Hashing both
        // sides first (SHA-256, always 32 bytes) removes the length
        // difference entirely rather than short-circuiting on it.
        var actualHash = SHA256.HashData(Encoding.UTF8.GetBytes(actual));
        var expectedHash = SHA256.HashData(Encoding.UTF8.GetBytes(expected));
        return CryptographicOperations.FixedTimeEquals(actualHash, expectedHash);
    }
}
