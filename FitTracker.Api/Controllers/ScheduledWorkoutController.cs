using FitTracker.Api.DTOs;
using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FitTracker.Api.Controllers;

/// <summary>Handles operations for scheduled workouts, their exercises, and performed sets.</summary>
[ApiController]
[Route("api/ScheduledWorkout")]
[Authorize]
public class ScheduledWorkoutController : ControllerBase
{
    private readonly IScheduledWorkoutService _scheduledService;

    /// <summary>Initialises a new instance of <see cref="ScheduledWorkoutController"/>.</summary>
    /// <param name="scheduledService">The scheduled workout service.</param>
    public ScheduledWorkoutController(IScheduledWorkoutService scheduledService)
    {
        _scheduledService = scheduledService;
    }

    /// <summary>Returns all scheduled workouts belonging to the authenticated user.</summary>
    /// <returns>A list of scheduled workout response DTOs, or 404 if the user cannot be identified.</returns>
    [HttpGet]
    public async Task<IActionResult> GetUserScheduledWorkouts()
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _scheduledService.GetUserScheduledWorkoutsAsync(userId);
        return Ok(result);
    }

    /// <summary>Creates a new scheduled workout for the authenticated user.</summary>
    /// <param name="dto">The scheduled workout data to create.</param>
    /// <returns>The created scheduled workout response DTO, or 404 if the user cannot be identified.</returns>
    [HttpPost]
    public async Task<IActionResult> CreateScheduledWorkout([FromBody] ScheduledWorkoutRequestDto dto)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _scheduledService.CreateScheduledWorkoutAsync(dto, userId);
        if (result == null) return NotFound("Referenced workout or plan not found");

        return Ok(result);
    }

    /// <summary>Returns a single scheduled workout by ID.</summary>
    /// <param name="id">The ID of the scheduled workout to retrieve.</param>
    /// <returns>The scheduled workout response DTO, or 404 if not found.</returns>
    [HttpGet("{id}")]
    public async Task<IActionResult> GetScheduledWorkoutById([FromRoute] Guid id)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _scheduledService.GetScheduledWorkoutByIdAsync(id, userId);
        if (result == null) return NotFound("Scheduled workout not found");

        return Ok(result);
    }

    /// <summary>Updates an existing scheduled workout.</summary>
    /// <param name="id">The ID of the scheduled workout to update.</param>
    /// <param name="dto">The updated scheduled workout data.</param>
    /// <returns>The updated scheduled workout response DTO, or 404 if not found.</returns>
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateScheduledWorkout([FromRoute] Guid id, [FromBody] ScheduledWorkoutRequestDto dto)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _scheduledService.UpdateScheduledWorkoutAsync(id, userId, dto);
        if (result == null) return NotFound("Scheduled workout not found");

        return Ok(result);
    }

    /// <summary>Deletes a scheduled workout by ID.</summary>
    /// <param name="id">The ID of the scheduled workout to delete.</param>
    /// <returns>204 No Content on success, or 404 if not found.</returns>
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteScheduledWorkout([FromRoute] Guid id)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _scheduledService.DeleteScheduledWorkoutAsync(id, userId);
        if (!result) return NotFound("Scheduled workout not found");

        return NoContent();
    }

    /// <summary>Creates scheduled workout exercise entries for the given workout exercise IDs.</summary>
    /// <param name="scheduledWorkoutId">The ID of the scheduled workout.</param>
    /// <param name="workoutExerciseIds">The list of workout exercise template IDs to link.</param>
    /// <returns>The newly created scheduled exercise DTOs.</returns>
    [HttpPost("{scheduledWorkoutId}/exercises/batch")]
    public async Task<IActionResult> CreateExercisesBatch([FromRoute] Guid scheduledWorkoutId, [FromBody] List<Guid> workoutExerciseIds)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _scheduledService.CreateExercisesBatchAsync(scheduledWorkoutId, userId, workoutExerciseIds);
        if (result == null) return NotFound("Scheduled workout not found");

        return Ok(result);
    }

    /// <summary>Adds a performed set to a scheduled workout exercise.</summary>
    /// <param name="scheduledWorkoutId">The ID of the scheduled workout (used for routing context).</param>
    /// <param name="workoutExerciseId">The ID of the scheduled workout exercise to add the set to.</param>
    /// <param name="dto">The set data to create.</param>
    /// <returns>The created workout set response DTO, or 404 if the user cannot be identified.</returns>
    [HttpPost("{scheduledWorkoutId}/exercises/{workoutExerciseId}/sets")]
    public async Task<IActionResult> AddSet([FromRoute] Guid scheduledWorkoutId, [FromRoute] Guid workoutExerciseId, [FromBody] WorkoutSetRequestDto dto)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _scheduledService.AddSetAsync(workoutExerciseId, userId, dto);
        if (result == null) return NotFound("Scheduled workout exercise not found");

        return Ok(result);
    }

    /// <summary>Adds multiple performed sets to a scheduled workout exercise in a single request.</summary>
    [HttpPost("{scheduledWorkoutId}/exercises/{workoutExerciseId}/sets/batch")]
    public async Task<IActionResult> AddSetsBatch([FromRoute] Guid scheduledWorkoutId, [FromRoute] Guid workoutExerciseId, [FromBody] List<WorkoutSetRequestDto> dtos)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _scheduledService.AddSetsBatchAsync(workoutExerciseId, userId, dtos);
        return Ok(result);
    }

    /// <summary>Updates an existing performed set.</summary>
    /// <param name="setId">The ID of the set to update.</param>
    /// <param name="dto">The updated set data.</param>
    /// <returns>The updated workout set response DTO, or 404 if not found.</returns>
    [HttpPut("exercises/sets/{setId}")]
    public async Task<IActionResult> UpdateSet([FromRoute] Guid setId, [FromBody] WorkoutSetRequestDto dto)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _scheduledService.UpdateSetAsync(setId, userId, dto);
        if (result == null) return NotFound("Set not found");

        return Ok(result);
    }

    /// <summary>Deletes a performed set by ID.</summary>
    /// <param name="setId">The ID of the set to delete.</param>
    /// <returns>204 No Content on success, or 404 if not found.</returns>
    [HttpDelete("exercises/sets/{setId}")]
    public async Task<IActionResult> DeleteSet([FromRoute] Guid setId)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _scheduledService.DeleteSetAsync(setId, userId);
        if (!result) return NotFound("Set not found");

        return NoContent();
    }

    /// <summary>Marks a scheduled exercise as completed.</summary>
    /// <param name="scheduledExerciseId">The ID of the scheduled exercise to complete.</param>
    /// <returns>200 OK on success, or 404 if not found.</returns>
    [HttpPatch("exercises/{scheduledExerciseId}/complete")]
    public async Task<IActionResult> CompleteExercise([FromRoute] Guid scheduledExerciseId)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _scheduledService.CompleteExerciseAsync(scheduledExerciseId, userId);
        if (!result) return NotFound("Scheduled exercise not found");

        return Ok();
    }

    /// <summary>Marks a scheduled workout as completed.</summary>
    /// <param name="id">The ID of the scheduled workout to complete.</param>
    /// <returns>200 OK on success, or 404 if not found.</returns>
    [HttpPatch("{id}/complete")]
    public async Task<IActionResult> CompleteWorkout([FromRoute] Guid id)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _scheduledService.CompleteWorkoutAsync(id, userId);
        if (!result) return NotFound("Scheduled workout not found");

        return Ok();
    }
}
