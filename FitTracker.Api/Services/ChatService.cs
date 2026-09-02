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
    public async Task<ChatMessageDto> SendMessageAsync(Guid trainerId, Guid clientId, Guid senderId, Guid messageId, EncryptedChatBody body, string? senderDeviceId = null)
    {
        // A ChatMessage carries no trainer/client ids of its own — it reaches the
        // pair through TrainerClientId, a required foreign key. So the loose pair
        // of Guids this method is handed has to be turned back into the
        // relationship row before anything can be stored.
        var relationship = await _trainerClientRepo.GetActiveRelationshipAsync(trainerId, clientId)
            ?? throw new InvalidOperationException(
                "No active trainer-client relationship exists for this pair.");

        var chatMessage = await _chatRepo.AddMessageAsync(new ChatMessage
        {
            Id = messageId,
            TrainerClientId = relationship.Id,
            Body = body.Ciphertext,
            Iv = body.Iv,
            EncryptionVersion = body.EncryptionVersion,
            EphemeralPublicKeyJwk = body.EphemeralPublicKeyJwk,
            SenderId = senderId,
            Keys = (body.Keys ?? [])
                .Select(k => new ChatMessageKey
                {
                    MessageId = messageId,
                    DeviceId = k.DeviceId,
                    WrappedKey = k.WrappedKey,
                    WrappedIv = k.WrappedIv,
                })
                .ToList(),
        });

        return ToDto(chatMessage, trainerId, clientId, senderDeviceId);
    }

    /// <inheritdoc/>
    public async Task<List<ChatMessageDto>> GetChatHistoryAsync(Guid trainerId, Guid clientId, int range, string? deviceId = null)
    {
        var messageHistory = await _chatRepo.GetChatHistoryAsync(trainerId, clientId, range, deviceId);
        if (messageHistory == null) return new List<ChatMessageDto>();
        var chatHistoryDto = new List<ChatMessageDto>();
        foreach (var chatHistory in messageHistory)
        {
            chatHistoryDto.Add(ToDto(chatHistory, trainerId, clientId, deviceId));
        }
        return chatHistoryDto;
    }

    /// <inheritdoc/>
    public Task<List<ChatConversationDto>> GetConversationsAsync(Guid userId, string? deviceId = null) =>
        _chatRepo.GetConversationsAsync(userId, deviceId);

    /// <inheritdoc/>
    public async Task MarkReadAsync(Guid userId, Guid otherPartyId)
    {
        var marked = await _chatRepo.MarkReadAsync(userId, otherPartyId, DateTime.UtcNow);
        if (!marked)
        {
            throw new InvalidOperationException(
                "No active trainer-client relationship exists for this pair.");
        }
    }

    // The stored message knows who sent it; the pair it belongs to is supplied by
    // the caller, which already had to resolve it to get here. Both ids travel on
    // every message because the client uses them to decide which side of the
    // thread a bubble sits on — it has no user id of its own to compare against.
    //
    // deviceId picks the one wrapped-key row (of potentially several — one per
    // registered device of both parties) that belongs to whoever is asking. A
    // message never carries any device's key but the caller's own.
    private static ChatMessageDto ToDto(ChatMessage m, Guid trainerId, Guid clientId, string? deviceId)
    {
        var key = deviceId == null ? null : m.Keys.FirstOrDefault(k => k.DeviceId == deviceId);

        return new ChatMessageDto
        {
            Id = m.Id,
            Body = m.Body,
            Iv = m.Iv,
            EncryptionVersion = m.EncryptionVersion,
            EphemeralPublicKeyJwk = m.EphemeralPublicKeyJwk,
            WrappedKey = key?.WrappedKey,
            WrappedIv = key?.WrappedIv,
            SentAt = m.SentAt,
            SenderId = m.SenderId,
            TrainerId = trainerId,
            ClientId = clientId,
            MediaType = m.MediaType,
            Url = m.Url,
            ThumbnailUrl = m.ThumbnailUrl,
        };
    }
}
