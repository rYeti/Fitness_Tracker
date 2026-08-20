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

    /// <summary>Null when the pair has never exchanged a message.</summary>
    public string? LastMessagePreview { get; set; }

    /// <summary>Null when the pair has never exchanged a message.</summary>
    public DateTime? LastMessageAt { get; set; }

    /// <summary>
    /// Messages from the other party since this caller last opened the thread.
    /// Never counts the caller's own messages.
    /// </summary>
    public int UnreadCount { get; set; }
}
