using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

public interface IChatRepository
{
    /// <summary>Persists a new chat message.</summary>
    Task<ChatMessage> AddMessageAsync(ChatMessage chatMessage);

    /// <summary>Returns up to <paramref name="range"/> of the most recent messages between the trainer and client, oldest first.</summary>
    Task<List<ChatMessage>> GetChatHistoryAsync(Guid trainerId, Guid client, int range);
}