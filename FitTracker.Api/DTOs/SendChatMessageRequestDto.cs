namespace FitTracker.Api.DTOs;

/// <summary>
/// What a client sends to <c>ChatHub.SendMessage</c>. A single object rather
/// than loose parameters: version 2 added an ephemeral key and a per-device key
/// list on top of the four the hub already took, and a positional parameter
/// list that long is easy to reorder by accident on one side of the wire and
/// not the other.
/// </summary>
public class SendChatMessageRequestDto
{
    public Guid ClientId { get; set; }

    public Guid MessageId { get; set; }

    /// <summary>Base64 ciphertext, or plaintext under version 0. This hub never reads it.</summary>
    public string Body { get; set; } = string.Empty;

    /// <summary>Base64 IV <see cref="Body"/> was encrypted under. Null for version 0.</summary>
    public string? Iv { get; set; }

    public int EncryptionVersion { get; set; }

    /// <summary>The message's ephemeral ECDH public key. Required for version 2.</summary>
    public string? EphemeralPublicKeyJwk { get; set; }

    /// <summary>One wrapped copy of the content key per target device. Required for version 2.</summary>
    public List<ChatMessageKeyDto> Keys { get; set; } = [];
}
