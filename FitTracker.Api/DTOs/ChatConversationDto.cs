namespace FitTracker.Api.DTOs;

/// <summary>
/// One row in a user's conversation list: who is on the other end, a preview of
/// the last thing said, and how much of it they haven't read.
/// </summary>
/// <remarks>
/// Deliberately expressed as "the other party" rather than "the client", because
/// one endpoint serves both roles — a trainer sees their clients here, a client
/// sees their trainer.
/// </remarks>
public class ChatConversationDto
{
    public Guid OtherPartyId { get; set; }

    public string OtherPartyName { get; set; } = string.Empty;

    /// <summary>
    /// The last message's stored body. Null when the pair has never exchanged one.
    /// </summary>
    /// <remarks>
    /// Named "preview" from when this server could produce one. It cannot any
    /// more — from <see cref="LastMessageEncryptionVersion"/> 1 onward this is
    /// ciphertext, and the truncation that makes it a preview happens on the
    /// client, after it decrypts. The name is kept so the wire contract and the
    /// Flutter model do not have to change in lockstep with the meaning.
    /// </remarks>
    public string? LastMessagePreview { get; set; }

    /// <summary>Base64 IV for <see cref="LastMessagePreview"/>, null for a legacy row.</summary>
    public string? LastMessageIv { get; set; }

    /// <summary>How <see cref="LastMessagePreview"/> was protected. 0 = plaintext, 1 = encrypted.</summary>
    public int LastMessageEncryptionVersion { get; set; }

    /// <summary>Null when the pair has never exchanged a message.</summary>
    public DateTime? LastMessageAt { get; set; }

    /// <summary>
    /// Messages from the other party since this caller last opened the thread.
    /// Never counts the caller's own messages.
    /// </summary>
    public int UnreadCount { get; set; }
}
