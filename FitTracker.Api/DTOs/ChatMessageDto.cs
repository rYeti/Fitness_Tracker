using FitTracker.Api.Enums;

namespace FitTracker.Api.DTOs;

public class ChatMessageDto
{
    public Guid Id { get; set; }

    /// <summary>The body exactly as stored — ciphertext from EncryptionVersion 1 onward.</summary>
    public string? Body { get; set; }

    /// <summary>Base64 IV for <see cref="Body"/>, null for a legacy plaintext row.</summary>
    public string? Iv { get; set; }

    /// <summary>0 = plaintext (written before encryption existed), 1 = ECDH P-256 + AES-256-GCM.</summary>
    public int EncryptionVersion { get; set; }

    public DateTime SentAt { get; set; }

    public Guid SenderId { get; set; }

    public Guid TrainerId { get; set; }

    public Guid ClientId { get; set; }

    public Media? MediaType { get; set; }

    public string? Url { get; set; }

    public string? ThumbnailUrl { get; set; }
}