using System.Security.Claims;
using FitTracker.Api.Models;
using FitTracker.Api.Services;
using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FitTracker.Api.Controllers;

/// <summary>A trainer's plan: what it covers, and how to buy or manage it.
///
/// Every action here is trainer-only, and none of them provisions. Being a
/// trainer is decided once, when the account is registered as one — see
/// AuthService.RegisterAsync. This controller used to mint a Free licence from
/// its own GET, which quietly turned any user who opened the plan screen into a
/// permanent trainer.</summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class TrainerLicenceController(ITrainerLicenceService service) : ControllerBase
{
    private readonly ITrainerLicenceService _service = service;

    /// <summary>The caller's plan, or a <c>not_a_trainer</c> refusal if they
    /// aren't one. A pure read — it provisions nothing.</summary>
    [HttpGet("me")]
    public async Task<IActionResult> GetMine()
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var licence = await _service.GetMineAsync(userId.Value);
        return licence == null ? NotATrainer() : Ok(licence);
    }

    /// <summary>Starts Stripe Checkout for a paid tier and returns the URL to
    /// redirect the trainer to.</summary>
    [HttpPost("checkout-session")]
    public async Task<IActionResult> CreateCheckoutSession([FromBody] CheckoutRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();
        if (!await _service.IsTrainerAsync(userId.Value)) return NotATrainer();

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
        if (!await _service.IsTrainerAsync(userId.Value)) return NotATrainer();

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

    /// <summary>The refusal every action here shares. 403 with an
    /// <c>error</c> of <c>not_a_trainer</c> matches what TrainerClientController
    /// already sends for the same condition, so the client has one case to
    /// handle rather than one per endpoint.</summary>
    private ObjectResult NotATrainer() =>
        StatusCode(StatusCodes.Status403Forbidden, new
        {
            error = "not_a_trainer",
            message = "This account isn't a trainer account.",
        });

    private Guid? GetUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier) ?? User.FindFirst("sub");
        return claim != null && Guid.TryParse(claim.Value, out var id) ? id : null;
    }
}
