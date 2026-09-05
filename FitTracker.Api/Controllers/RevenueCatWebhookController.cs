using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace FitTracker.Api.Controllers;

/// <summary>
/// Receives RevenueCat subscription events for a plain user's own app-store
/// purchase — the entitlement source <see cref="Services.TrainerClientService.GetMyNutrientPinsAsync"/>
/// uses for a user with no trainer to curate pins for them.
///
/// Anonymous by necessity — RevenueCat has no bearer token to attach — so the
/// configured shared-secret header is the entire authentication story. Never
/// relax that: this endpoint can grant a user their own premium entitlement.
/// </summary>
[ApiController]
[Route("api/revenuecat")]
[AllowAnonymous]
[EnableRateLimiting("revenuecat-webhook")]
public class RevenueCatWebhookController(
    IRevenueCatService service,
    ILogger<RevenueCatWebhookController> logger) : ControllerBase
{
    private readonly IRevenueCatService _service = service;
    private readonly ILogger<RevenueCatWebhookController> _logger = logger;

    [HttpPost("webhook")]
    public async Task<IActionResult> Handle()
    {
        using var reader = new StreamReader(Request.Body);
        var payload = await reader.ReadToEndAsync();
        var authHeader = Request.Headers.Authorization.ToString();

        try
        {
            await _service.HandleWebhookAsync(payload, authHeader);
        }
        catch (UnauthorizedAccessException ex)
        {
            _logger.LogWarning(ex, "Rejected a RevenueCat webhook with a bad Authorization header");
            return Unauthorized();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to process a RevenueCat webhook");
            return StatusCode(StatusCodes.Status500InternalServerError);
        }

        return Ok();
    }
}
