using FitTracker.Api.DTOs;
using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;


namespace FitTracker.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class WeightTrackingController : ControllerBase
{

    private readonly IWeightTrackingService _weightTrackingService;

    public WeightTrackingController(IWeightTrackingService weightTrackingService)
    {
        _weightTrackingService = weightTrackingService;
    }

    [HttpPost("TrackWeight")]
    [Authorize]
    public async Task<IActionResult> TrackWeight([FromBody] WeightTrackingRequestDto weightTrackingRequestDto)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);

        if (Guid.Empty == userId)
        {
            return NotFound("User not found");
        }

        var result = await _weightTrackingService.LogWeightAsync(weightTrackingRequestDto, userId);

        if (result == null)
        {
            return NotFound("No result");
        }

        return Ok(result);
    }

    [HttpGet("TrackWeight")]
    [Authorize]
    public async Task<IActionResult> GetTrackedWeights()
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);

        if (Guid.Empty == userId)
        {
            return NotFound("User not found");
        }

        var result = await _weightTrackingService.GetWeightLogs(userId);

        if (result == null)
        {
            return NotFound("No result");
        }

        return Ok(result);
    }
}