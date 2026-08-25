using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

/// <summary>
/// What runs when no FCM credentials are configured.
/// </summary>
/// <remarks>
/// Registered instead of <see cref="FirebasePushSender"/> when
/// <c>Fcm:ServiceAccountJsonBase64</c> is absent, so a developer running the API
/// locally — or an environment where the secret has not been set yet — gets an
/// API that serves every request normally and simply does not notify. That
/// matches how the codebase already treats missing Stripe and CORS config: log
/// loudly at startup, keep serving.
/// </remarks>
public class DisabledPushSender(ILogger<DisabledPushSender> logger) : IPushSender
{
    private readonly ILogger<DisabledPushSender> _logger = logger;

    public bool IsConfigured => false;

    public Task<PushSendResult> SendAsync(
        IReadOnlyList<string> tokens,
        PushMessage message,
        CancellationToken cancellationToken = default)
    {
        _logger.LogDebug(
            "Push is not configured; dropping a notification for {TokenCount} device(s).",
            tokens.Count);
        return Task.FromResult(new PushSendResult([]));
    }
}
