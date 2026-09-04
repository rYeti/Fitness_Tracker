using System.Security.Claims;
using FitTracker.Api.Models;
using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace FitTracker.Api.Controllers;

/// <summary>Manages the trainer-client relationship lifecycle: invites, joining,
/// roster listing, and removal.</summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class TrainerClientController(ITrainerClientService service) : ControllerBase
{
    private readonly ITrainerClientService _service = service;

    /// <summary>Returns whether the current user is a client of a trainer, and/or a
    /// trainer themselves, along with where their premium access comes from.</summary>
    [HttpGet("status")]
    public async Task<IActionResult> GetStatus()
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();
        return Ok(await _service.GetStatusAsync(userId.Value));
    }

    /// <summary>Trainer generates a one-time invite code to share with a client.</summary>
    [HttpPost("invite")]
    public async Task<IActionResult> CreateInvite()
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var result = await _service.CreateInviteAsync(userId.Value);
        return result.Status switch
        {
            CreateInviteStatus.Ok => Ok(result.Invite),

            // 409 rather than 402: the trainer's plan is a fine plan, it's just
            // full. The seat numbers travel with the error so the console can
            // say "10 of 10 seats used" without asking again.
            CreateInviteStatus.SeatLimitReached => Conflict(new
            {
                error = "seat_limit_reached",
                message = $"Your plan covers {result.SeatLimit} clients and all of them are in use.",
                seatsUsed = result.SeatsUsed,
                seatLimit = result.SeatLimit,
            }),

            CreateInviteStatus.NotEntitled => StatusCode(StatusCodes.Status402PaymentRequired, new
            {
                error = "licence_lapsed",
                message = "Your licence has lapsed. Renew it to take on new clients.",
            }),

            CreateInviteStatus.NoLicence => StatusCode(StatusCodes.Status403Forbidden, new
            {
                error = "not_a_trainer",
                message = "Set up a trainer plan before inviting clients.",
            }),

            _ => StatusCode(StatusCodes.Status500InternalServerError),
        };
    }

    /// <summary>Trainer withdraws an invite they issued, freeing its seat.</summary>
    [HttpDelete("invite/{inviteId}")]
    public async Task<IActionResult> RevokeInvite(Guid inviteId)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();
        return await _service.RevokeInviteAsync(inviteId, userId.Value)
            ? NoContent()
            : NotFound();
    }

    /// <summary>Trainer's outstanding invites, so they can share, re-copy or
    /// withdraw a code they've already generated.</summary>
    [HttpGet("invites")]
    public async Task<IActionResult> GetPendingInvites()
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();
        return Ok(await _service.GetPendingInvitesAsync(userId.Value));
    }

    /// <summary>Client joins a trainer using the invite code.</summary>
    [EnableRateLimiting("invite")]
    [HttpPost("join/{inviteCode}")]
    public async Task<IActionResult> JoinTrainer(string inviteCode)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var result = await _service.AcceptInviteAsync(inviteCode, userId.Value);
        return result.Status switch
        {
            AcceptInviteStatus.Ok => Ok(result.Relationship),

            // Each failure gets its own message. Telling someone their code is
            // invalid when their trainer has simply run out of seats sends them
            // hunting for the wrong problem.
            AcceptInviteStatus.NotFound => BadRequest(new
            {
                error = "invalid_code",
                message = "That code doesn't match an invite. Check it and try again.",
            }),
            AcceptInviteStatus.Expired => BadRequest(new
            {
                error = "expired_code",
                message = "That invite has expired. Ask your trainer for a new code.",
            }),
            AcceptInviteStatus.SelfInvite => BadRequest(new
            {
                error = "self_invite",
                message = "That's your own invite code.",
            }),
            AcceptInviteStatus.TrainerAtSeatLimit => Conflict(new
            {
                error = "trainer_at_seat_limit",
                message = "Your trainer's plan is full. Ask them to free up a seat.",
            }),
            AcceptInviteStatus.TrainerNotEntitled => Conflict(new
            {
                error = "trainer_not_entitled",
                message = "Your trainer's plan isn't active. Ask them to renew it.",
            }),

            _ => StatusCode(StatusCodes.Status500InternalServerError),
        };
    }

    /// <summary>Returns the trainer's active client list.</summary>
    [HttpGet("my-clients")]
    public async Task<IActionResult> GetClients()
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();
        return Ok(await _service.GetClientsAsync(userId.Value));
    }

    /// <summary>The nutrients the caller's trainer has pinned for them to track,
    /// read-only. Defaults for a caller with no active trainer, or whose trainer
    /// never chose — see <see cref="ITrainerClientService.GetMyNutrientPinsAsync"/>.</summary>
    [HttpGet("my-nutrient-pins")]
    public async Task<IActionResult> GetMyNutrientPins()
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();
        return Ok(await _service.GetMyNutrientPinsAsync(userId.Value));
    }

    /// <summary>Trainer removes a client, or client leaves their trainer.</summary>
    [HttpDelete("{relationshipId}")]
    public async Task<IActionResult> Remove(Guid relationshipId)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();
        var success = await _service.RemoveRelationshipAsync(relationshipId, userId.Value);
        return success ? NoContent() : NotFound();
    }

    private Guid? GetUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier) ?? User.FindFirst("sub");
        return claim != null && Guid.TryParse(claim.Value, out var id) ? id : null;
    }
}
