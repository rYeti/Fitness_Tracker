using System.Text;
using FitTracker.Api.DTOs;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

/// <summary>
/// Turns "user X was sent a message" into notifications on their devices, and
/// keeps the token table honest while doing it.
/// </summary>
/// <remarks>
/// This class used to write the notification. It cannot any more: the body is
/// ciphertext, so there is no preview to truncate and no title to pair it with.
/// What it builds now is a data payload the recipient's own device decrypts and
/// renders. See docs/chat-encryption.md.
/// </remarks>
public class PushNotificationService(
    IDeviceTokenRepository deviceTokens,
    IPushSender sender,
    ILogger<PushNotificationService> logger) : IPushNotificationService
{
    private readonly IDeviceTokenRepository _deviceTokens = deviceTokens;
    private readonly IPushSender _sender = sender;
    private readonly ILogger<PushNotificationService> _logger = logger;

    /// <summary>
    /// How much of the payload the encrypted content is allowed to take up.
    /// </summary>
    /// <remarks>
    /// FCM caps a message at 4KB. A ciphertext cannot be truncated and still
    /// decrypt — chop a byte off an AES-GCM payload and the tag fails, which the
    /// client correctly reads as "tampered with" — so an over-long message
    /// cannot be shortened the way the old 140-character preview was. It is
    /// dropped from the payload instead, along with the epk and every wrapped
    /// key: a version-2 message's key material is exactly as atomic as its
    /// ciphertext, since a device with the body but no way to unwrap its key is
    /// no better off than one with neither. The device then shows the sender's
    /// name with no preview — the same fallback as any other decryption failure.
    /// Deliberately well under 4KB: FCM's own envelope and base64's 4/3
    /// expansion both come out of the same budget.
    /// </remarks>
    private const int MaxDataBytes = 3200;

    /// <inheritdoc/>
    public async Task SendChatMessageAsync(
        Guid recipientId,
        string senderName,
        Guid messageId,
        EncryptedChatBody body,
        Guid threadId)
    {
        if (!_sender.IsConfigured) return;

        var devices = await _deviceTokens.GetForUserAsync(recipientId);
        // Nothing installed, or nothing signed in. Not an error — most users of
        // any messaging app are reachable on some devices and not others.
        if (devices.Count == 0) return;

        var tokens = devices.Select(d => d.Token).ToList();

        var data = new Dictionary<string, string>
        {
            // The client switches on this to tell a chat notification apart
            // from whatever is added later, and uses threadId to route.
            ["type"] = "chat_message",
            ["threadId"] = threadId.ToString(),
            ["messageId"] = messageId.ToString(),
            // The one human-readable thing in here, and the only reason a
            // notification can still say who it is from. A display name is not
            // message content.
            ["senderName"] = senderName,
        };

        // Every device's wrapped key rides in one compact field rather than one
        // FCM data key per device — the field-count budget is as real as the
        // byte budget, and a recipient with several devices should not be the
        // thing that blows either one. Each entry is `deviceId:wrappedKey:wrappedIv`;
        // none of the three can itself contain ':', since all three are base64
        // or an opaque client-generated id.
        var withKeys = new Dictionary<string, string>(data)
        {
            ["ciphertext"] = body.Ciphertext ?? string.Empty,
            ["encryptionVersion"] = body.EncryptionVersion.ToString(),
        };
        if (body.Iv != null) withKeys["iv"] = body.Iv;
        if (body.EphemeralPublicKeyJwk != null) withKeys["epk"] = body.EphemeralPublicKeyJwk;
        if (body.Keys is { Count: > 0 })
        {
            withKeys["keys"] = string.Join(',', body.Keys.Select(k => $"{k.DeviceId}:{k.WrappedKey}:{k.WrappedIv}"));
        }

        // Omitted rather than truncated when it will not fit, and omitted as one
        // unit: a ciphertext without its keys, or keys without their ciphertext,
        // are both exactly as unreadable as neither. The device then draws "New
        // message" under the sender's name, which is exactly what it already
        // does when it has no key for this peer.
        if (!string.IsNullOrEmpty(body.Ciphertext) && Fits(withKeys))
        {
            data = withKeys;
        }

        var result = await _sender.SendAsync(tokens, new PushMessage(data));

        if (result.DeadTokens.Count == 0) return;

        // Pruned the moment FCM says so. Left in place, a token for an
        // uninstalled app is retried on every single message for that user
        // forever — the table only ever grows, and so does the cost of each send.
        await _deviceTokens.DeleteManyAsync(result.DeadTokens);
        _logger.LogInformation(
            "Removed {Count} dead push token(s) for user {UserId}.",
            result.DeadTokens.Count, recipientId);
    }

    private static bool Fits(IReadOnlyDictionary<string, string> data) =>
        data.Sum(kv => Encoding.UTF8.GetByteCount(kv.Key) + Encoding.UTF8.GetByteCount(kv.Value)) <= MaxDataBytes;
}
