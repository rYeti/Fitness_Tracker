using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Stripe;

namespace FitTracker.Api.Controllers;

/// <summary>
/// Receives Stripe subscription events.
///
/// Anonymous by necessity — Stripe has no bearer token — so the webhook
/// signature is the entire authentication story. Never relax that: this
/// endpoint can grant every trainee of a trainer a Pro entitlement.
/// </summary>
[ApiController]
[Route("api/stripe")]
[AllowAnonymous]
[EnableRateLimiting("webhook")]
public class StripeWebhookController(
    ITrainerLicenceService service,
    ILogger<StripeWebhookController> logger) : ControllerBase
{
    private readonly ITrainerLicenceService _service = service;
    private readonly ILogger<StripeWebhookController> _logger = logger;

    [HttpPost("webhook")]
    public async Task<IActionResult> Handle()
    {
        using var reader = new StreamReader(Request.Body);
        var payload = await reader.ReadToEndAsync();
        var signature = Request.Headers["Stripe-Signature"].ToString();

        try
        {
            await _service.HandleWebhookAsync(payload, signature);
        }
        catch (StripeException ex)
        {
            // Bad or missing signature. 400 so Stripe stops retrying something
            // that will never verify.
            _logger.LogWarning(ex, "Rejected a Stripe webhook with an invalid signature");
            return BadRequest();
        }
        catch (Exception ex)
        {
            // 500 so Stripe retries — a transient database failure shouldn't
            // silently drop a subscription change.
            _logger.LogError(ex, "Failed to process a Stripe webhook");
            return StatusCode(StatusCodes.Status500InternalServerError);
        }

        return Ok();
    }
}
