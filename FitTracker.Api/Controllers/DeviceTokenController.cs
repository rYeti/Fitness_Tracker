using System.Security.Claims;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FitTracker.Api.Controllers;

/// <summary>
/// Where a device says "notify me here" and, on sign-out, "stop".
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class DeviceTokenController(IDeviceTokenRepository deviceTokens) : ControllerBase
{
    private readonly IDeviceTokenRepository _deviceTokens = deviceTokens;

    public record RegisterDeviceTokenRequest(string Token, DevicePlatform Platform);

    /// <summary>
    /// Registers this device against the calling user, moving it off any previous
    /// owner.
    /// </summary>
    /// <remarks>
    /// Idempotent, and called on every launch as well as on every token refresh —
    /// FCM reissues tokens on its own schedule, so treating registration as a
    /// one-time event silently stops delivering to a device weeks later.
    /// </remarks>
    [HttpPost]
    public async Task<IActionResult> Register([FromBody] RegisterDeviceTokenRequest request)
    {
        var userId = GetUserId();
        if (userId is null) return Unauthorized();

        if (string.IsNullOrWhiteSpace(request.Token))
            return BadRequest("A device token is required.");

        await _deviceTokens.UpsertAsync(userId.Value, request.Token.Trim(), request.Platform);
        return NoContent();
    }

    /// <summary>Unregisters a device, on sign-out.</summary>
    /// <remarks>
    /// Deliberately not scoped to the caller. The client sends this while signing
    /// out, and the point is that the token stops belonging to *anyone* — a token
    /// left behind keeps delivering the previous user's messages to a phone
    /// somebody else is now holding. Knowing the token is proof enough of
    /// possession of the device, and the worst an attacker with one can do is
    /// stop their own notifications.
    /// </remarks>
    [HttpDelete("{token}")]
    public async Task<IActionResult> Unregister(string token)
    {
        var userId = GetUserId();
        if (userId is null) return Unauthorized();

        await _deviceTokens.DeleteAsync(token);
        return NoContent();
    }

    // Same two-step as ChatController: tokens minted by the OAuth path carry the
    // id as a bare "sub" rather than as NameIdentifier.
    private Guid? GetUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier) ?? User.FindFirst("sub");
        return claim != null && Guid.TryParse(claim.Value, out var id) ? id : null;
    }
}
