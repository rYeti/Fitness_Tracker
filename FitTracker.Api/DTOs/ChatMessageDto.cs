using FitTracker.Api.Enums;

namespace FitTracker.Api.DTOs;

public class ChatMessageDto
{
    public Guid Id { get; set; }

    /// <summary>The body exactly as stored — ciphertext from EncryptionVersion 1 onward.</summary>
    public string? Body { get; set; }

    /// <summary>Base64 IV for <see cref="Body"/>, null for a legacy plaintext row.</summary>
    public string? Iv { get; set; }

    /// <summary>0 = plaintext, 1 = pairwise ECDH P-256 + AES-256-GCM, 2 = per-device ECDH P-256 + AES-256-GCM.</summary>
    public int EncryptionVersion { get; set; }

    /// <summary>The message's ephemeral ECDH public key. Present only for <see cref="EncryptionVersion"/> 2.</summary>
    public string? EphemeralPublicKeyJwk { get; set; }

    /// <summary>
    /// This <em>device's own</em> wrapped copy of the content key, resolved
    /// server-side against the <c>deviceId</c> the caller sent. Null when the
    /// message predates this device, or under version 0/1 — the ordinary shape
    /// of "cannot be decrypted here", not an error.
    /// </summary>
    public string? WrappedKey { get; set; }

    /// <summary>Base64 IV <see cref="WrappedKey"/> was wrapped under.</summary>
    public string? WrappedIv { get; set; }

    public DateTime SentAt { get; set; }

    public Guid SenderId { get; set; }

    public Guid TrainerId { get; set; }

    public Guid ClientId { get; set; }

    public Media? MediaType { get; set; }

    public string? Url { get; set; }

    public string? ThumbnailUrl { get; set; }
}