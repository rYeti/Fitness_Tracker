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
    public async Task<ChatMessageDto> SendMessageAsync(Guid trainerId, Guid clientId, Guid senderId, string message)
    {
        var relationship = await _trainerClientRepo.GetActiveRelationshipAsync(trainerId, clientId)
            ?? throw new InvalidOperationException("Not authorized for this chat.");

        var chatMessage = await _chatRepo.AddMessageAsync(new ChatMessage
        {
            Body = message,
            SenderId = senderId,
            TrainerClient = relationship,
        });

        return ToDto(chatMessage, trainerId, clientId);
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