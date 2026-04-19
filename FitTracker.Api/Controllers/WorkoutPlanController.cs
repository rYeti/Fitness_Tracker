using FitTracker.Api.DTOs;
using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FitTracker.Api.Controllers;

/// <summary>Handles CRUD operations for workout plans and their workout membership.</summary>
[ApiController]
[Route("api/WorkoutPlan")]
[Authorize]
public class WorkoutPlanController : ControllerBase
{
    private readonly IWorkoutPlanService _planService;

    /// <summary>Initialises a new instance of <see cref="WorkoutPlanController"/>.</summary>
    /// <param name="planService">The workout plan service.</param>
    public WorkoutPlanController(IWorkoutPlanService planService)
    {
        _planService = planService;
    }

    /// <summary>Returns all workout plans belonging to the authenticated user.</summary>
    /// <returns>A list of workout plan response DTOs, or 404 if the user cannot be identified.</returns>
    [HttpGet]
    public async Task<IActionResult> GetUserPlans()
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _planService.GetUserPlansAsync(userId);
        return Ok(result);
    }

    /// <summary>Creates a new workout plan for the authenticated user.</summary>
    /// <param name="dto">The plan data to create.</param>
    /// <returns>The created workout plan response DTO, or 404 if the user cannot be identified.</returns>
    [HttpPost]
    public async Task<IActionResult> CreatePlan([FromBody] WorkoutPlanRequestDto dto)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _planService.CreatePlanAsync(dto, userId);
        return Ok(result);
    }

    /// <summary>Returns a single workout plan belonging to the authenticated user.</summary>
    /// <param name="id">The ID of the plan to retrieve.</param>
    /// <returns>The workout plan response DTO, or 404 if not found.</returns>
    [HttpGet("{id}")]
    public async Task<IActionResult> GetPlanById([FromRoute] Guid id)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _planService.GetPlanByIdAsync(id, userId);
        if (result == null) return NotFound("Plan not found");

        return Ok(result);
    }

    /// <summary>Updates an existing workout plan belonging to the authenticated user.</summary>
    /// <param name="id">The ID of the plan to update.</param>
    /// <param name="dto">The updated plan data.</param>
    /// <returns>The updated workout plan response DTO, or 404 if not found.</returns>
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdatePlan([FromRoute] Guid id, [FromBody] WorkoutPlanRequestDto dto)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _planService.UpdatePlanAsync(id, userId, dto);
        if (result == null) return NotFound("Plan not found");

        return Ok(result);
    }

    /// <summary>Deletes a workout plan belonging to the authenticated user.</summary>
    /// <param name="id">The ID of the plan to delete.</param>
    /// <returns>204 No Content on success, or 404 if not found.</returns>
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeletePlan([FromRoute] Guid id)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _planService.DeletePlanAsync(id, userId);
        if (!result) return NotFound("Plan not found");

        return NoContent();
    }

    /// <summary>Adds a workout to a plan.</summary>
    /// <param name="planId">The ID of the plan.</param>
    /// <param name="workoutId">The ID of the workout to add.</param>
    /// <returns>200 OK on success, or 404 if the user cannot be identified.</returns>
    [HttpPost("{planId}/workouts/{workoutId}")]
    public async Task<IActionResult> AddWorkoutToPlan([FromRoute] Guid planId, [FromRoute] Guid workoutId)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        await _planService.AddWorkoutToPlanAsync(planId, workoutId);
        return Ok();
    }

    /// <summary>Adds multiple workouts to a plan in a single request.</summary>
    [HttpPost("{planId}/workouts/batch")]
    public async Task<IActionResult> AddWorkoutsBatch([FromRoute] Guid planId, [FromBody] List<Guid> workoutIds)
    {
        await _planService.AddWorkoutsToPlanBatchAsync(planId, workoutIds);
        return Ok();
    }

    /// <summary>Removes a workout from a plan.</summary>
    /// <param name="planId">The ID of the plan.</param>
    /// <param name="workoutId">The ID of the workout to remove.</param>
    /// <returns>204 No Content on success, or 404 if not found.</returns>
    [HttpDelete("{planId}/workouts/{workoutId}")]
    public async Task<IActionResult> RemoveWorkoutFromPlan([FromRoute] Guid planId, [FromRoute] Guid workoutId)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _planService.RemoveWorkoutFromPlanAsync(planId, workoutId);
        if (!result) return NotFound("Plan-workout link not found");

        return NoContent();
    }
}
