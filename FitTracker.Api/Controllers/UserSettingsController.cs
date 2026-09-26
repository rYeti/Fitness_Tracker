using FitTracker.Api.DTOs;
using FitTracker.Api.Services;
using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FitTracker.Api.Controllers;

/// <summary>Handles reading and upserting user settings.</summary>
[ApiController]
[Route("api/UserSettings")]
[Authorize]
public class UserSettingsController(IUserSettingsService userSettingsService) : ControllerBase
{
    /// <summary>Returns the settings for the authenticated user, or 404 if not yet created.</summary>
    [HttpGet]
    public async Task<IActionResult> Get()
    {
        if (!User.TryGetUserId(out var userId)) return Unauthorized();
        var result = await userSettingsService.GetSettingsAsync(userId);
        if (result is null) return NotFound();
        return Ok(result);
    }

    /// <summary>Creates or fully replaces the settings for the authenticated user.</summary>
    /// <param name="dto">The settings data.</param>
    [HttpPut]
    public async Task<IActionResult> Upsert([FromBody] UserSettingsRequestDto dto)
    {
        if (!User.TryGetUserId(out var userId)) return Unauthorized();
        var result = await userSettingsService.UpsertSettingsAsync(userId, dto);
        return Ok(result);
    }
}
