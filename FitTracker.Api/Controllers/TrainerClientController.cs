using System.Security.Claims;
using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FitTracker.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class TrainerClientController(ITrainerClientService service) : ControllerBase
{
    private readonly ITrainerClientService _service = service;

    /// <summary>Returns whether the current user is a client of a trainer, and/or a trainer themselves.</summary>
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
        return Ok(result);
    }

    /// <summary>Client joins a trainer using the invite code.</summary>
    [HttpPost("join/{inviteCode}")]
    public async Task<IActionResult> JoinTrainer(string inviteCode)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();
        var result = await _service.AcceptInviteAsync(inviteCode, userId.Value);
        if (result == null) return BadRequest("Invalid or expired invite code.");
        return Ok(result);
    }

    /// <summary>Returns the trainer's active client list.</summary>
    [HttpGet("my-clients")]
    public async Task<IActionResult> GetClients()
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();
        return Ok(await _service.GetClientsAsync(userId.Value));
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
