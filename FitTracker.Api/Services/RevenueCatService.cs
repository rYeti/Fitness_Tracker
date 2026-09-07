using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

public class RevenueCatService(
    IRevenueCatSubscriptionRepository repository,
    IUserRepository userRepository,
    RevenueCatStateMachine stateMachine,
    IConfiguration configuration,
    ILogger<RevenueCatService> logger) : IRevenueCatService
{
    private readonly IRevenueCatSubscriptionRepository _repository = repository;
    private readonly IUserRepository _userRepository = userRepository;
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

        var snapshot = await ParseAsync(payload);
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
    /// handle — a customer id that resolves to no known user, an event
    /// carrying none of our entitlement ids, or a <c>TRANSFER</c> (moving a
    /// subscription between app_user_ids — a real edge case with real
    /// complexity this app's login flow, always
    /// <c>Purchases.logIn(serverUserId)</c>, isn't expected to hit;
    /// deliberately unhandled rather than silently mishandled).</summary>
    private async Task<RevenueCatSnapshot?> ParseAsync(string payload)
    {
        using var doc = JsonDocument.Parse(payload);
        if (!doc.RootElement.TryGetProperty("event", out var evt)) return null;

        var type = GetString(evt, "type");
        if (type == "TRANSFER")
        {
            _logger.LogWarning(
                "Ignoring a RevenueCat TRANSFER event — not handled, see RevenueCatService.ParseAsync");
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

        var appUserId = GetString(evt, "app_user_id");
        var userId = await ResolveUserIdAsync(appUserId)
            ?? await ResolveUserIdAsync(GetString(evt, "original_app_user_id"));

        if (userId == null && evt.TryGetProperty("aliases", out var aliasesProp)
            && aliasesProp.ValueKind == JsonValueKind.Array)
        {
            foreach (var alias in aliasesProp.EnumerateArray())
            {
                userId = await ResolveUserIdAsync(
                    alias.ValueKind == JsonValueKind.String ? alias.GetString() : null);
                if (userId != null) break;
            }
        }

        if (userId == null)
        {
            // Not necessarily an error: an anonymous RevenueCat customer that
            // was never logged in as a real account resolves to nothing, and
            // that's expected. What made this worth logging by name is that
            // it also used to be the *only* outcome for every genuine
            // customer, back when the client sent a username here instead of
            // the account's id — see docs/revenuecat-self-managed-pins.md.
            _logger.LogWarning(
                "RevenueCat {EventType} event's app_user_id {AppUserId} did not resolve to a known user",
                type ?? "(no type)", appUserId ?? "(none)");
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
            UserId: userId.Value,
            ExpiresAt: expiresAt,
            EventTime: DateTimeOffset.FromUnixTimeMilliseconds(eventTimeMs).UtcDateTime);
    }

    /// <summary>Resolves a RevenueCat customer identifier to a real user's
    /// id, or null if it doesn't name one. Tried as a server user id first
    /// (the current client's <c>appUserID</c>, per
    /// <c>AccessProvider.initialize</c>), then as a username (what every
    /// RevenueCat customer created before that fix still carries as its
    /// <c>app_user_id</c>, and can never be renamed to match) — never
    /// guessed, always confirmed to name a real, still-existing user, so a
    /// well-formed but stale or unrelated id can't reach
    /// <see cref="IRevenueCatSubscriptionRepository.GetOrCreateAsync"/> and
    /// fail there on the foreign key instead.</summary>
    private async Task<Guid?> ResolveUserIdAsync(string? candidateId)
    {
        if (string.IsNullOrWhiteSpace(candidateId)) return null;

        if (Guid.TryParse(candidateId, out var parsedId))
        {
            var userById = await _userRepository.GetUserByIdAsync(parsedId);
            return userById?.Id;
        }

        var userByUsername = await _userRepository.GetUserByUsernameAsync(candidateId);
        return userByUsername?.Id;
    }

    private static string? GetString(JsonElement obj, string property) =>
        obj.TryGetProperty(property, out var value) && value.ValueKind == JsonValueKind.String
            ? value.GetString()
            : null;

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
