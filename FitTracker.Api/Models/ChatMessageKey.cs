namespace FitTracker.Api.Models;

/// <summary>
/// One device's wrapped copy of one message's content key.
/// </summary>
/// <remarks>
/// <para>
/// A message body is encrypted once, under a random content key. That content
/// key is then wrapped — encrypted again, under a secret derived from the
/// message's ephemeral key pair (<see cref="ChatMessage.EphemeralPublicKeyJwk"/>)
/// and one target device's public key — once per device that should be able to
/// read it: every device of both parties to the conversation, the sender's own
/// included. A reader needs nothing but its own private key, the message's
/// <c>epk</c>, and its own row here.
/// </para>
/// <para>
/// Deliberately not a foreign key to <see cref="UserChatDeviceKey"/>. A device
/// key row can be pruned (a user is only allowed so many registered devices)
/// while the messages already wrapped for it must stay exactly as readable as
/// they always were on that device — pruning the key row must never cascade
/// into deleting history.
/// </para>
/// </remarks>
public class ChatMessageKey
{
    public Guid MessageId { get; set; }

    public ChatMessage ChatMessage { get; set; } = null!;

    public string DeviceId { get; set; } = string.Empty;

    /// <summary>Base64 AES-256-GCM ciphertext of the message's content key.</summary>
    public string WrappedKey { get; set; } = string.Empty;

    /// <summary>Base64 IV <see cref="WrappedKey"/> was wrapped under.</summary>
    public string WrappedIv { get; set; } = string.Empty;
}
