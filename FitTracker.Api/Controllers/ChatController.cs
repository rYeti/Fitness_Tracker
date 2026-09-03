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

    /// <summary>Default number of messages returned when the caller doesn't ask for a specific window.</summary>
    private const int DefaultHistoryRange = 50;

    /// <summary>Upper bound, so one request can't ask for an unbounded thread.</summary>
    private const int MaxHistoryRange = 200;

    /// <param name="clientId">
    /// The <em>other party</em> in the thread: a client's id when a trainer calls,
    /// the trainer's id when the client does.
    /// </param>
    /// <param name="range">
    /// How many of the most recent messages to return. Defaulted rather than left
    /// at 0 — "take 0" comes back as an empty list, which reads exactly like a
    /// thread that has never been used.
    /// </param>
    [HttpGet("{clientId}/history")]
    public async Task<IActionResult> chatHistory(Guid clientId, [FromQuery] int range = DefaultHistoryRange)
    {
        var userId = GetUserId();
        if (userId is null) return Unauthorized();
        var (trainerId, actualClientId, ok) = await _trainerClientService.ResolvePairAsync(userId.Value, clientId);

        if (!ok) return Unauthorized();

        var chatHitory = await _chatService.GetChatHistoryAsync(
            trainerId,
            actualClientId,
            Math.Clamp(range <= 0 ? DefaultHistoryRange : range, 1, MaxHistoryRange));
        return Ok(chatHitory);
    }

    /// <summary>
    /// The caller's conversation list — one row per Active relationship, whichever
    /// side of it they are on.
    /// </summary>
    [HttpGet("conversations")]
    public async Task<IActionResult> Conversations()
    {
        var userId = GetUserId();
        if (userId is null) return Unauthorized();

        return Ok(await _chatService.GetConversationsAsync(userId.Value));
    }

    /// <summary>Marks the caller's side of one thread as read up to now.</summary>
    [HttpPost("{otherPartyId}/read")]
    public async Task<IActionResult> MarkRead(Guid otherPartyId)
    {
        var userId = GetUserId();
        if (userId is null) return Unauthorized();

        var (_, _, ok) = await _trainerClientService.ResolvePairAsync(userId.Value, otherPartyId);
        if (!ok) return Unauthorized();

        await _chatService.MarkReadAsync(userId.Value, otherPartyId);
        return NoContent();
    }

    private Guid? GetUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier) ?? User.FindFirst("sub");
        return claim != null && Guid.TryParse(claim.Value, out var id) ? id : null;
    }
}
