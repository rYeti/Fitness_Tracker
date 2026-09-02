using FitTracker.Api.Enums;

namespace FitTracker.Api.Models;

public class ChatMessage
{
    public Guid Id { get; set; }

    /// <summary>The message body, as the sender's device handed it over.</summary>
    /// <remarks>
    /// Opaque from <see cref="EncryptionVersion"/> 1 onward: base64 of an
    /// AES-256-GCM ciphertext this server has no key for. Nothing here may
    /// read, truncate, search or log it. Rows written before encryption existed
    /// carry plaintext and are marked version 0.
    /// </remarks>
    public string? Body { get; set; }

    /// <summary>Base64 of the 12-byte AES-GCM IV <see cref="Body"/> was encrypted under.</summary>
    /// <remarks>Null exactly when <see cref="EncryptionVersion"/> is 0.</remarks>
    public string? Iv { get; set; }

    /// <summary>How <see cref="Body"/> was protected. 0 = plaintext, 1 = ECDH P-256 + AES-256-GCM.</summary>
    /// <remarks>
    /// Stored rather than inferred from "is there an IV?". The moment a second
    /// scheme exists, inference is how bodies written under the old one get
    /// decrypted under the new one's rules. Defaulting to 0 is what lets the
    /// migration leave every existing row alone and still be honest about it.
    /// </remarks>
    public int EncryptionVersion { get; set; }

    /// <summary>
    /// The message's own ephemeral ECDH public key, as a JSON Web Key.
    /// Present only for <see cref="EncryptionVersion"/> 2. Every device's
    /// wrapped copy of the content key (<see cref="Keys"/>) is derived from
    /// this key and that device's own — never from the sender's or recipient's
    /// long-lived identity key, which is why no cached peer key is needed to
    /// read a v2 message. See docs/chat-encryption.md.
    /// </summary>
    public string? EphemeralPublicKeyJwk { get; set; }

    /// <summary>One wrapped copy of this message's content key per target device.</summary>
    public List<ChatMessageKey> Keys { get; set; } = [];

    public Guid SenderId { get; set; }

    public DateTime SentAt { get; set; } = DateTime.UtcNow;

    public TrainerClient TrainerClient { get; set; } = null!;

    public Guid TrainerClientId { get; set; }

    public Media? MediaType { get; set; }

    public string? Url { get; set; }

    public string? ThumbnailUrl { get; set; }

}