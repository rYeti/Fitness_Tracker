using System.Security.Claims;
using FitTracker.Api.DTOs;
using FitTracker.Api.Filters;
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

    [HttpGet("roster")]
    public async Task<IActionResult> GetRoster()
    {
        var trainerId = GetUserId();
        if (trainerId == null) return Unauthorized();
        return Ok(await _service.GetRosterAsync(trainerId.Value));
    }

    [HttpGet("{clientId}/weight-history")]
    public async Task<IActionResult> GetClientWeightHistory(Guid clientId)
    {
        var trainerId = GetUserId();
        if (trainerId == null) return Unauthorized();
        var result = await _service.GetClientWeightHistoryAsync(trainerId.Value, clientId);
        if (result == null) return NotFound();
        return Ok(result);
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

    [HttpGet("{clientId}/session-history")]
    public async Task<IActionResult> GetClientSessionHistory(Guid clientId, [FromQuery] int count = 10)
    {
        var trainerId = GetUserId();
        if (trainerId == null) return Unauthorized();
        if (count is < 1 or > 50) return BadRequest("count must be between 1 and 50.");
        var result = await _service.GetClientSessionHistoryAsync(trainerId.Value, clientId, count);
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

    /// <summary>Replaces the whole set of nutrients pinned to track for this
    /// client on the Nutrition tab. Requires an entitled licence — this is a
    /// write, unlike every read above.</summary>
    [ServiceFilter(typeof(RequireEntitledLicenceFilter))]
    [HttpPut("{clientId}/nutrient-pins")]
    public async Task<IActionResult> SetClientNutrientPins(Guid clientId, [FromBody] List<string> nutrientKeys)
    {
        var trainerId = GetUserId();
        if (trainerId == null) return Unauthorized();
        var result = await _service.SetClientNutrientPinsAsync(trainerId.Value, clientId, nutrientKeys);
        return result.Status switch
        {
            SetNutrientPinsStatus.Ok => Ok(result),
            SetNutrientPinsStatus.InvalidNutrientKey => BadRequest("Unrecognised nutrient key."),
            _ => NotFound(),
        };
    }

    [ServiceFilter(typeof(RequireEntitledLicenceFilter))]
    [HttpPost("{clientId}/workout-plans")]
    public async Task<IActionResult> CreateClientWorkoutPlan(Guid clientId, [FromBody] WorkoutPlanRequestDto dto)
    {
        var trainerId = GetUserId();
        if (trainerId == null) return Unauthorized();
        var result = await _service.CreateClientWorkoutPlanAsync(trainerId.Value, clientId, dto);
        if (result == null) return NotFound();
        return Ok(result);
    }

    [ServiceFilter(typeof(RequireEntitledLicenceFilter))]
    [HttpPut("{clientId}/workout-plans/{planId}")]
    public async Task<IActionResult> UpdateClientWorkoutPlan(Guid clientId, Guid planId, [FromBody] WorkoutPlanRequestDto dto)
    {
        var trainerId = GetUserId();
        if (trainerId == null) return Unauthorized();
        var result = await _service.UpdateClientWorkoutPlanAsync(trainerId.Value, clientId, planId, dto);
        if (result == null) return NotFound();
        return Ok(result);
    }

    [HttpGet("{clientId}/workouts")]
    public async Task<IActionResult> GetClientWorkouts(Guid clientId)
    {
        var trainerId = GetUserId();
        if (trainerId == null) return Unauthorized();
        var result = await _service.GetClientWorkoutsAsync(trainerId.Value, clientId);
        if (result == null) return NotFound();
        return Ok(result);
    }

    [HttpGet("{clientId}/exercises")]
    public async Task<IActionResult> GetClientExerciseLibrary(Guid clientId)
    {
        var trainerId = GetUserId();
        if (trainerId == null) return Unauthorized();
        var result = await _service.GetClientExerciseLibraryAsync(trainerId.Value, clientId);
        if (result == null) return NotFound();
        return Ok(result);
    }

    [ServiceFilter(typeof(RequireEntitledLicenceFilter))]
    [HttpPost("{clientId}/exercises")]
    public async Task<IActionResult> CreateTrainerExercise(Guid clientId, [FromBody] ExerciseRequestDto dto)
    {
        var trainerId = GetUserId();
        if (trainerId == null) return Unauthorized();
        var result = await _service.CreateTrainerExerciseAsync(trainerId.Value, clientId, dto);
        if (result == null) return NotFound();
        return Ok(result);
    }

    [ServiceFilter(typeof(RequireEntitledLicenceFilter))]
    [HttpPost("{clientId}/workouts")]
    public async Task<IActionResult> CreateClientWorkout(Guid clientId, [FromBody] ClientWorkoutRequestDto dto)
    {
        var trainerId = GetUserId();
        if (trainerId == null) return Unauthorized();
        var result = await _service.CreateClientWorkoutAsync(trainerId.Value, clientId, dto);
        return ToActionResult(result);
    }

    [ServiceFilter(typeof(RequireEntitledLicenceFilter))]
    [HttpPut("{clientId}/workouts/{workoutId}")]
    public async Task<IActionResult> UpdateClientWorkout(Guid clientId, Guid workoutId, [FromBody] ClientWorkoutRequestDto dto)
    {
        var trainerId = GetUserId();
        if (trainerId == null) return Unauthorized();
        var result = await _service.UpdateClientWorkoutAsync(trainerId.Value, clientId, workoutId, dto);
        return ToActionResult(result);
    }

    [ServiceFilter(typeof(RequireEntitledLicenceFilter))]
    [HttpDelete("{clientId}/workouts/{workoutId}")]
    public async Task<IActionResult> DeleteClientWorkout(Guid clientId, Guid workoutId)
    {
        var trainerId = GetUserId();
        if (trainerId == null) return Unauthorized();
        var status = await _service.DeleteClientWorkoutAsync(trainerId.Value, clientId, workoutId);
        return status switch
        {
            TrainerWorkoutStatus.Ok => NoContent(),
            TrainerWorkoutStatus.HasLoggedHistory => Conflict("This workout has logged history and can't be deleted."),
            _ => NotFound(),
        };
    }

    [ServiceFilter(typeof(RequireEntitledLicenceFilter))]
    [HttpPost("{clientId}/workout-plans/{planId}/schedule")]
    public async Task<IActionResult> ScheduleClientPlan(Guid clientId, Guid planId, [FromBody] SchedulePlanRequestDto dto)
    {
        var trainerId = GetUserId();
        if (trainerId == null) return Unauthorized();
        if (dto.CyclePattern.Count == 0) return BadRequest("cyclePattern must not be empty.");
        if (dto.DurationWeeks is < 1 or > 52) return BadRequest("durationWeeks must be between 1 and 52.");
        var created = await _service.ScheduleClientPlanAsync(trainerId.Value, clientId, planId, dto.CyclePattern, dto.DurationWeeks);
        if (created == null) return NotFound();
        return Ok(new { sessionsCreated = created.Value });
    }

    /// <summary>Maps a <see cref="TrainerWorkoutResult"/> to the response shape shared by
    /// create and update. <see cref="TrainerWorkoutStatus.NotPermitted"/> and
    /// <see cref="TrainerWorkoutStatus.NotFound"/> both 404, the same way every other
    /// endpoint on this controller already declines to say which one it was.</summary>
    private IActionResult ToActionResult(TrainerWorkoutResult result) => result.Status switch
    {
        TrainerWorkoutStatus.Ok => Ok(result.Workout),
        TrainerWorkoutStatus.UnknownExercise => BadRequest(new { unknownExerciseIds = result.UnknownExerciseIds }),
        TrainerWorkoutStatus.HasLoggedHistory => Conflict("This workout has logged history and can't be replaced."),
        _ => NotFound(),
    };

    private Guid? GetUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier) ?? User.FindFirst("sub");
        return claim != null && Guid.TryParse(claim.Value, out var id) ? id : null;
    }
}
