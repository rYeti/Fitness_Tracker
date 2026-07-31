using FitTracker.Api.Data;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Repositories;

public class ChatRepository(AppDbContext context) : IChatRepository
{
    private readonly AppDbContext _context = context;

    /// <summary>Persists a new chat message.</summary>
    async Task<ChatMessage> IChatRepository.AddMessageAsync(ChatMessage chatMessage)
    {
        var chat = new ChatMessage
        {
            Id = chatMessage.Id,
            Body = chatMessage.Body,
            MediaType = chatMessage.MediaType,
            SenderId = chatMessage.SenderId,
            SentAt = chatMessage.SentAt,
            ThumbnailUrl = chatMessage.ThumbnailUrl,
            TrainerClient = chatMessage.TrainerClient,
            Url = chatMessage.Url,
        };

        _context.ChatMessages.Add(chat);
        await _context.SaveChangesAsync();
        return chat;
    }

    /// <summary>Fetches the most recent <paramref name="range"/> messages for the trainer/client pair, then reverses them into oldest-first order for display.</summary>
    async Task<List<ChatMessage>> IChatRepository.GetChatHistoryAsync(Guid trainerId, Guid client, int range)
    {
        var chatHistory = await _context.ChatMessages.Where(c => c.TrainerClient.TrainerId == trainerId && c.TrainerClient.ClientId == client).OrderByDescending(c => c.SentAt).Take(range).ToListAsync();

        chatHistory.Reverse();
        return chatHistory;
    }
}