using FitTracker.Api.DTOs;

namespace FitTracker.Api.Services.Interfaces;

public interface IChatService
{
    /// <summary>
    /// Persists a chat message for a trainer-client pair and returns the
    /// serialized message payload to broadcast to the SignalR group.
    /// </summary>
    /// <param name="trainerId">The trainer id that identifies the chat pair (always the trainer side, regardless of who sent the message).</param>
    /// <param name="clientId">The client id that identifies the chat pair.</param>
    /// <param name="senderId">The user id of whoever actually sent this message (trainer or client).</param>
    /// <param name="messageId">The client-generated id used to dedupe retries/echoes of the same message.</param>
    /// <param name="body">
    /// The message body, already encrypted by the sender's device. This server
    /// stores it verbatim and cannot read it — see docs/chat-encryption.md.
    /// </param>
    /// <exception cref="InvalidOperationException">No Active relationship joins the pair.</exception>
    Task<ChatMessageDto> SendMessageAsync(Guid trainerId, Guid clientId, Guid senderId, Guid messageId, EncryptedChatBody body);

    /// <summary>
    /// Retrieves chat history for a trainer-client pair, oldest first.
    /// </summary>
    /// <param name="trainerId">The trainer id that identifies the chat pair.</param>
    /// <param name="clientId">The client id that identifies the chat pair.</param>
    /// <param name="range">How many of the most recent messages to return — a message count, not a number of days.</param>
    Task<List<ChatMessageDto>> GetChatHistoryAsync(Guid trainerId, Guid clientId, int range);

    /// <summary>
    /// Every Active thread this user is a party to, newest activity first, with
    /// a preview of the last message and the caller's own unread count.
    /// </summary>
    /// <param name="userId">The signed-in user — trainer or client; the "other party" is whoever they are not.</param>
    Task<List<ChatConversationDto>> GetConversationsAsync(Guid userId);

    /// <summary>
    /// Marks this caller's side of a thread as read up to now.
    /// </summary>
    /// <exception cref="InvalidOperationException">No Active relationship joins the pair.</exception>
    Task MarkReadAsync(Guid userId, Guid otherPartyId);
}
