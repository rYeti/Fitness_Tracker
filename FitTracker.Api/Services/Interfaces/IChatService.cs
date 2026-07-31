using FitTracker.Api.DTOs;

namespace FitTracker.Api.Services.Interfaces;

public interface IChatService
{
    /// <summary>
    /// Persists a chat message for a trainer-client pair and returns the
    /// serialized message payload to broadcast to the SignalR group.
    /// </summary>
    /// <param name="sender">The trainer id that identifies the chat pair (always the trainer side, regardless of who sent the message).</param>
    /// <param name="clientId">The client id that identifies the chat pair.</param>
    /// <param name="senderId">The user id of whoever actually sent this message (trainer or client).</param>
    /// <param name="message">The message body.</param>
    Task<ChatMessageDto> SendMessageAsync(Guid trainerId, Guid clientId, Guid senderId, string message);
}