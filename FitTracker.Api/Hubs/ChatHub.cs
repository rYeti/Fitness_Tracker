using System.Security.Claims;
using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace FitTracker.Api.Hubs;

[Authorize]
public class ChatHub(ITrainerClientService trainerClientService, IChatService chatService) : Hub
{
    private ITrainerClientService TrainerClientService { get; } = trainerClientService;
    private IChatService ChatService { get; } = chatService;
    private static string GroupName(Guid trainerId, Guid clientId) => $"chat:{trainerId}:{clientId}";

    /// <summary>
    /// Adds the caller's connection to the SignalR group for their chat with
    /// <paramref name="clientId"/>. Callable by either the trainer or the
    /// client side of the pair — <see cref="ResolveTrainerAsync"/> figures out
    /// which one the caller is.
    /// </summary>
    public async Task JoinClientGroup(Guid clientId)
    {
        var userId = GetUserId();
        var (trainerId, ok) = await ResolveTrainerAsync(userId, clientId);

        if (!ok) throw new HubException("Not authorized for this chat.");

        var actualClientId = trainerId == userId ? clientId : userId;

        await Groups.AddToGroupAsync(Context.ConnectionId, GroupName(trainerId, actualClientId));
    }

    /// <summary>
    /// Persists a message via <see cref="IChatService"/> and broadcasts it to
    /// every connection in the pair's group (including the sender).
    /// </summary>
    public async Task SendMessage(Guid clientId, string body, Guid messageId)
    {
        var userId = GetUserId();
        var (trainerId, ok) = await ResolveTrainerAsync(userId, clientId);
        if (!ok) throw new HubException("Not authorized for this chat.");

        var actualClientId = trainerId == userId ? clientId : userId;

        var message = await ChatService.SendMessageAsync(trainerId, actualClientId, senderId: userId, messageId: messageId, body);
        await Clients.Group(GroupName(trainerId, actualClientId)).SendAsync("ReceiveMessage", message);
    }

    /// <summary>
    /// Removes the caller's connection from the SignalR group for their chat
    /// with <paramref name="clientId"/>.
    /// </summary>
    public async Task LeaveClientChat(Guid clientId)
    {
        var userId = GetUserId();
        var (trainerId, ok) = await ResolveTrainerAsync(userId, clientId);
        if (!ok) throw new HubException("Not authorized for this chat.");
        var actualClientId = trainerId == userId ? clientId : userId;

        await Groups.RemoveFromGroupAsync(Context.ConnectionId, GroupName(trainerId, actualClientId));
    }

    // Resolves whether the caller is the trainer or the client side of an
    // Active relationship, so one hub serves both roles symmetrically.
    private async Task<(Guid trainerId, bool ok)> ResolveTrainerAsync(Guid userId, Guid clientId)
    {
        if (await TrainerClientService.IsActiveTrainerOfAsync(userId, clientId))
            return (userId, true);

        // caller might be the client, not the trainer — swap and re-check
        if (await TrainerClientService.IsActiveTrainerOfAsync(clientId, userId))
            return (clientId, true);

        return (default, false);
    }

    private Guid GetUserId() =>
        Guid.Parse(Context.User!.FindFirstValue(ClaimTypes.NameIdentifier)!);

}