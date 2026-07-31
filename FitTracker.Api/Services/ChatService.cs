using FitTracker.Api.DTOs;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

public class ChatService(ITrainerClientRepository repo, IUserRepository user) : IChatService
{
    private readonly ITrainerClientRepository _repo = repo;
    private readonly IUserRepository _user = user;

    public Task<ChatMessageDto> SendMessageAsync(Guid trainerId, Guid clientId, Guid senderId, string message)
    {
        var userId = GetUserId();
        var (trainerId, ok) = await ResolveTrainerAsync(userId, clientId);
        if (!ok) throw new HubException("Not authorized for this chat.");

        var actualClientId = trainerId == userId ? clientId : userId;

    }

    private Guid GetUserId() => _
      ;

}