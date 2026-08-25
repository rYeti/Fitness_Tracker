using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

/// <summary>
/// Turns "user X was sent a message" into notifications on their devices, and
/// keeps the token table honest while doing it.
/// </summary>
public class PushNotificationService(
    IDeviceTokenRepository deviceTokens,
    IPushSender sender,
    ILogger<PushNotificationService> logger) : IPushNotificationService
{
    private readonly IDeviceTokenRepository _deviceTokens = deviceTokens;
    private readonly IPushSender _sender = sender;
    private readonly ILogger<PushNotificationService> _logger = logger;

    /// <summary>
    /// Notification bodies are truncated rather than sent whole: FCM caps a
    /// payload at 4KB, and a lock screen shows perhaps two lines regardless.
    /// </summary>
    private const int PreviewLength = 140;

    /// <inheritdoc/>
    public async Task SendChatMessageAsync(Guid recipientId, string senderName, string? body, Guid threadId)
    {
        if (!_sender.IsConfigured) return;

        var devices = await _deviceTokens.GetForUserAsync(recipientId);
        // Nothing installed, or nothing signed in. Not an error — most users of
        // any messaging app are reachable on some devices and not others.
        if (devices.Count == 0) return;

        var tokens = devices.Select(d => d.Token).ToList();

        var message = new PushMessage(
            Title: senderName,
            Body: Preview(body),
            Data: new Dictionary<string, string>
            {
                // The client switches on this to tell a chat notification apart
                // from whatever is added later, and uses threadId to route.
                ["type"] = "chat_message",
                ["threadId"] = threadId.ToString(),
            });

        var result = await _sender.SendAsync(tokens, message);

        if (result.DeadTokens.Count == 0) return;

        // Pruned the moment FCM says so. Left in place, a token for an
        // uninstalled app is retried on every single message for that user
        // forever — the table only ever grows, and so does the cost of each send.
        await _deviceTokens.DeleteManyAsync(result.DeadTokens);
        _logger.LogInformation(
            "Removed {Count} dead push token(s) for user {UserId}.",
            result.DeadTokens.Count, recipientId);
    }

    private static string Preview(string? body)
    {
        // An attachment-only message has no body. "Sent a message" is a better
        // notification than an empty one, which some launchers render as a blank
        // row the user cannot interpret at all.
        if (string.IsNullOrWhiteSpace(body)) return "Sent a message";

        var trimmed = body.Trim();
        return trimmed.Length <= PreviewLength
            ? trimmed
            : string.Concat(trimmed.AsSpan(0, PreviewLength), "…");
    }
}
