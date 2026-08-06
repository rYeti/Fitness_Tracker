using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

public class ChatService(ITrainerClientRepository trainerClientRepo, IChatRepository chatRepo) : IChatService
{
    private readonly ITrainerClientRepository _trainerClientRepo = trainerClientRepo;
    private readonly IChatRepository _chatRepo = chatRepo;

    /// <inheritdoc/>
    public async Task<ChatMessageDto> SendMessageAsync(Guid trainerId, Guid clientId, Guid senderId, Guid messageId, string message)
    {
        var chatMessage = await _chatRepo.AddMessageAsync(new ChatMessage
        {
            Id = messageId,
            Body = message,
            SenderId = senderId,
        });

        return ToDto(chatMessage, trainerId, clientId);
    }

    /// <inheritdoc/>
    public async Task<List<ChatMessageDto>> GetChatHistoryAsync(Guid trainerId, Guid clientId, int range)
    {
        var messageHistory = await _chatRepo.GetChatHistoryAsync(trainerId, clientId, range);
        if (messageHistory == null) return new List<ChatMessageDto>();
        var chatHistoryDto = new List<ChatMessageDto>();
        foreach (var chatHistory in messageHistory)
        {
            chatHistoryDto.Add(ToDto(chatHistory, trainerId, clientId));
        }
        return chatHistoryDto;
    }

    private static ChatMessageDto ToDto(ChatMessage m, Guid trainerId, Guid clientId) => new()
    {
        Id = m.Id,
        Body = m.Body,
        SentAt = m.SentAt,
        SenderId = m.SenderId,
        TrainerId = trainerId,
        ClientId = clientId,
        MediaType = m.MediaType,
        Url = m.Url,
        ThumbnailUrl = m.ThumbnailUrl,
    };
}