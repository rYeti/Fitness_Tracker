using System.Security.Claims;
using FitTracker.Api.DTOs;
using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FitTracker.Api.Controllers;

/// <summary>Trainer-facing reads/writes on a client's data (Trainer Console).
/// Every action requires an Active TrainerClient relationship — see
/// ITrainerConsoleService.</summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class TrainerConsoleController(ITrainerConsoleService service) : ControllerBase
{
    private readonly ITrainerConsoleService _service = service;

    [HttpGet("dashboard-kpis")]
    public async Task<IActionResult> GetDashboardKpis()
    {
        var trainerId = GetUserId();
        if (trainerId == null) return Unauthorized();
        return Ok(await _service.GetDashboardKpisAsync(trainerId.Value));
    }

    [HttpGet("{clientId}/weight-history")]
    public async Task<IActionResult> GetClientWeightHistory(Guid clientId)
    {
        var trainerId = GetUserId();
        if (trainerId == null) return Unauthorized();
        return Ok(await _service.GetClientWeightHistoryAsync(trainerId.Value, clientId));
    }

    [HttpGet("{clientId}/workout-summary")]
    public async Task<IActionResult> GetClientWorkoutSummary(Guid clientId)
    {
        var trainerId = GetUserId();
        if (trainerId == null) return Unauthorized();
        var result = await _service.GetClientWorkoutSummaryAsync(trainerId.Value, clientId);
        if (result == null) return NotFound();
        return Ok(result);
    }

    [HttpGet("{clientId}/workout-history")]
    public async Task<IActionResult> GetClientWorkoutHistory(Guid clientId, [FromQuery] DateTime date)
    {
        var trainerId = GetUserId();
        if (trainerId == null) return Unauthorized();
        var result = await _service.GetClientWorkoutHistoryAsync(trainerId.Value, clientId, date);
        if (result == null) return NotFound();
        return Ok(result);
    }

    [HttpGet("{clientId}/nutrition-summary")]
    public async Task<IActionResult> GetClientNutritionSummary(Guid clientId, [FromQuery] DateTime date)
    {
        var trainerId = GetUserId();
        if (trainerId == null) return Unauthorized();
        var result = await _service.GetClientNutritionSummaryAsync(trainerId.Value, clientId, date);
        if (result == null) return NotFound();
        return Ok(result);
    }

    [HttpPost("{clientId}/workout-plans")]
    public async Task<IActionResult> CreateClientWorkoutPlan(Guid clientId, [FromBody] WorkoutPlanRequestDto dto)
    {
        var trainerId = GetUserId();
        if (trainerId == null) return Unauthorized();
        var result = await _service.CreateClientWorkoutPlanAsync(trainerId.Value, clientId, dto);
        if (result == null) return NotFound();
        return Ok(result);
    }

    [HttpPut("{clientId}/workout-plans/{planId}")]
    public async Task<IActionResult> UpdateClientWorkoutPlan(Guid clientId, Guid planId, [FromBody] WorkoutPlanRequestDto dto)
    {
        var trainerId = GetUserId();
        if (trainerId == null) return Unauthorized();
        var result = await _service.UpdateClientWorkoutPlanAsync(trainerId.Value, clientId, planId, dto);
        if (result == null) return NotFound();
        return Ok(result);
    }

    private Guid? GetUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier) ?? User.FindFirst("sub");
        return claim != null && Guid.TryParse(claim.Value, out var id) ? id : null;
    }
}
