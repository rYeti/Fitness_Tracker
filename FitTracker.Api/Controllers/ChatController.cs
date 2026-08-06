using System.Security.Claims;
using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;


namespace FitTracker.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ChatController(IChatService chatService, ITrainerClientService trainerClientService) : ControllerBase
{
    private readonly IChatService _chatService = chatService;
    private readonly ITrainerClientService _trainerClientService = trainerClientService;

    [HttpGet("{clientId}/history")]
    public async Task<IActionResult> chatHistory(Guid clientId, int range)
    {
        var userId = GetUserId();
        if (userId is null) return Unauthorized();
        var (trainerId, ok) = await ResolveTrainerAsync(userId.Value, clientId);

        if (!ok) return Unauthorized();

        var actualClientId = trainerId == userId ? clientId : userId.Value;


        var chatHitory = await _chatService.GetChatHistoryAsync(actualClientId, trainerId, range);
        return Ok(chatHitory);
    }

    private Guid? GetUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier) ?? User.FindFirst("sub");
        return claim != null && Guid.TryParse(claim.Value, out var id) ? id : null;
    }

    // Resolves whether the caller is the trainer or the client side of an
    // Active relationship, so one hub serves both roles symmetrically.
    private async Task<(Guid trainerId, bool ok)> ResolveTrainerAsync(Guid userId, Guid clientId)
    {
        if (await _trainerClientService.IsActiveTrainerOfAsync(userId, clientId))
            return (userId, true);

        // caller might be the client, not the trainer — swap and re-check
        if (await _trainerClientService.IsActiveTrainerOfAsync(clientId, userId))
            return (clientId, true);

        return (default, false);
    }
}