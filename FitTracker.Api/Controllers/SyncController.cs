using FitTracker.Api.Services;
using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FitTracker.Api.Controllers;

/// <summary>The changes feed. See docs/sync-architecture.md, part three.</summary>
[ApiController]
[Route("api/Sync")]
[Authorize]
public class SyncController(ISyncFeedService feed) : ControllerBase
{
    /// <summary>Everything of the caller's that changed since <paramref name="since"/>.</summary>
    [HttpGet("changes")]
    public async Task<IActionResult> GetChanges([FromQuery] DateTimeOffset? since)
    {
        if (!User.TryGetUserId(out var userId)) return Unauthorized();
        return Ok(await feed.GetChangesAsync(userId, since?.UtcDateTime));
    }
}
