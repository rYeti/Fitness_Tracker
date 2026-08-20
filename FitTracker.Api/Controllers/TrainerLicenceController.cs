using System.Security.Claims;
using FitTracker.Api.Models;
using FitTracker.Api.Services;
using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FitTracker.Api.Controllers;

/// <summary>A trainer's plan: what it covers, and how to buy or manage it.</summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class TrainerLicenceController(ITrainerLicenceService service) : ControllerBase
{
    private readonly ITrainerLicenceService _service = service;

    /// <summary>The caller's plan. Provisions a Free licence on first call —
    /// which is what turns a user into a trainer.</summary>
    [HttpGet("me")]
    public async Task<IActionResult> GetMine()
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();
        return Ok(await _service.GetOrCreateAsync(userId.Value));
    }

    /// <summary>Explicit opt-in to being a trainer. Same effect as GET me, but
    /// says so at the call site rather than relying on a read having a side
    /// effect.</summary>
    [HttpPost("me")]
    public async Task<IActionResult> BecomeTrainer()
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();
        return Ok(await _service.GetOrCreateAsync(userId.Value));
    }

    /// <summary>Starts Stripe Checkout for a paid tier and returns the URL to
    /// redirect the trainer to.</summary>
    [HttpPost("checkout-session")]
    public async Task<IActionResult> CreateCheckoutSession([FromBody] CheckoutRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        if (!Enum.TryParse<LicenceTier>(request.Tier, ignoreCase: true, out var tier) ||
            !LicencePlanCatalog.PurchasableTiers.Contains(tier))
        {
            // Free is deliberately not purchasable, and not a downgrade target.
            return BadRequest(new
            {
                error = "unknown_tier",
                message = $"Choose one of: {string.Join(", ", LicencePlanCatalog.PurchasableTiers)}.",
            });
        }

        var url = await _service.CreateCheckoutSessionAsync(userId.Value, tier);
        return url == null
            ? StatusCode(StatusCodes.Status503ServiceUnavailable, new
            {
                error = "tier_unavailable",
                message = "That plan isn't available for purchase right now.",
            })
            : Ok(new { url });
    }

    /// <summary>Returns a Stripe billing-portal URL for managing an existing
    /// subscription.</summary>
    [HttpPost("portal-session")]
    public async Task<IActionResult> CreatePortalSession()
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var url = await _service.CreatePortalSessionAsync(userId.Value);
        return url == null
            ? NotFound(new
            {
                error = "no_billing_account",
                message = "There's no subscription to manage yet.",
            })
            : Ok(new { url });
    }

    public class CheckoutRequest
    {
        public string Tier { get; set; } = string.Empty;
    }

    private Guid? GetUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier) ?? User.FindFirst("sub");
        return claim != null && Guid.TryParse(claim.Value, out var id) ? id : null;
    }
}
