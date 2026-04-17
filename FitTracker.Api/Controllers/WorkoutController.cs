using FitTracker.Api.DTOs;
using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FitTracker.Api.Controllers;

/// <summary>Handles CRUD operations for workout templates, workout exercises, and set templates.</summary>
[ApiController]
[Route("api/Workout")]
[Authorize]
public class WorkoutController : ControllerBase
{
    private readonly IWorkoutService _workoutService;

    /// <summary>Initialises a new instance of <see cref="WorkoutController"/>.</summary>
    /// <param name="workoutService">The workout service.</param>
    public WorkoutController(IWorkoutService workoutService)
    {
        _workoutService = workoutService;
    }

    /// <summary>Returns all workouts belonging to the authenticated user.</summary>
    /// <returns>A list of workout response DTOs, or 404 if the user cannot be identified.</returns>
    [HttpGet]
    public async Task<IActionResult> GetUserWorkouts()
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _workoutService.GetUserWorkoutsAsync(userId);
        return Ok(result);
    }

    /// <summary>Creates a new workout for the authenticated user.</summary>
    /// <param name="dto">The workout data to create.</param>
    /// <returns>The created workout response DTO, or 404 if the user cannot be identified.</returns>
    [HttpPost]
    public async Task<IActionResult> CreateWorkout([FromBody] WorkoutRequestDto dto)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _workoutService.CreateWorkoutAsync(dto, userId);
        return Ok(result);
    }

    /// <summary>Returns a single workout belonging to the authenticated user.</summary>
    /// <param name="id">The ID of the workout to retrieve.</param>
    /// <returns>The workout response DTO, or 404 if not found.</returns>
    [HttpGet("{id}")]
    public async Task<IActionResult> GetWorkoutById([FromRoute] Guid id)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _workoutService.GetWorkoutByIdAsync(id, userId);
        if (result == null) return NotFound("Workout not found");

        return Ok(result);
    }

    /// <summary>Updates an existing workout belonging to the authenticated user.</summary>
    /// <param name="id">The ID of the workout to update.</param>
    /// <param name="dto">The updated workout data.</param>
    /// <returns>The updated workout response DTO, or 404 if not found.</returns>
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateWorkout([FromRoute] Guid id, [FromBody] WorkoutRequestDto dto)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _workoutService.UpdateWorkoutAsync(id, userId, dto);
        if (result == null) return NotFound("Workout not found");

        return Ok(result);
    }

    /// <summary>Deletes a workout belonging to the authenticated user.</summary>
    /// <param name="id">The ID of the workout to delete.</param>
    /// <returns>204 No Content on success, or 404 if not found.</returns>
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteWorkout([FromRoute] Guid id)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _workoutService.DeleteWorkoutAsync(id, userId);
        if (!result) return NotFound("Workout not found");

        return NoContent();
    }

    /// <summary>Adds an exercise entry to a workout.</summary>
    /// <param name="workoutId">The ID of the workout to add the exercise to.</param>
    /// <param name="dto">The exercise data to add.</param>
    /// <returns>The created workout exercise response DTO, or 404 if the user cannot be identified.</returns>
    [HttpPost("{workoutId}/exercises")]
    public async Task<IActionResult> AddExercise([FromRoute] Guid workoutId, [FromBody] WorkoutExerciseRequestDto dto)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _workoutService.AddExerciseToWorkoutAsync(workoutId, dto);
        return Ok(result);
    }

    /// <summary>Updates an existing workout exercise entry.</summary>
    /// <param name="exerciseId">The ID of the workout exercise to update.</param>
    /// <param name="dto">The updated exercise data.</param>
    /// <returns>The updated workout exercise response DTO, or 404 if not found.</returns>
    [HttpPut("exercises/{exerciseId}")]
    public async Task<IActionResult> UpdateExercise([FromRoute] Guid exerciseId, [FromBody] WorkoutExerciseRequestDto dto)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _workoutService.UpdateWorkoutExerciseAsync(exerciseId, dto);
        if (result == null) return NotFound("Workout exercise not found");

        return Ok(result);
    }

    /// <summary>Deletes a workout exercise entry.</summary>
    /// <param name="exerciseId">The ID of the workout exercise to delete.</param>
    /// <returns>204 No Content on success, or 404 if not found.</returns>
    [HttpDelete("exercises/{exerciseId}")]
    public async Task<IActionResult> DeleteExercise([FromRoute] Guid exerciseId)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _workoutService.DeleteWorkoutExerciseAsync(exerciseId);
        if (!result) return NotFound("Workout exercise not found");

        return NoContent();
    }

    /// <summary>Adds a set template to a workout exercise.</summary>
    /// <param name="workoutExerciseId">The ID of the workout exercise to add the set template to.</param>
    /// <param name="dto">The set template data to add.</param>
    /// <returns>The created set template response DTO, or 404 if the user cannot be identified.</returns>
    [HttpPost("exercises/{workoutExerciseId}/sets")]
    public async Task<IActionResult> AddSetTemplate([FromRoute] Guid workoutExerciseId, [FromBody] WorkoutSetTemplateRequestDto dto)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _workoutService.AddSetTemplateAsync(workoutExerciseId, dto);
        return Ok(result);
    }

    /// <summary>Updates an existing set template.</summary>
    /// <param name="setId">The ID of the set template to update.</param>
    /// <param name="dto">The updated set template data.</param>
    /// <returns>The updated set template response DTO, or 404 if not found.</returns>
    [HttpPut("exercises/sets/{setId}")]
    public async Task<IActionResult> UpdateSetTemplate([FromRoute] Guid setId, [FromBody] WorkoutSetTemplateRequestDto dto)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _workoutService.UpdateSetTemplateAsync(setId, dto);
        if (result == null) return NotFound("Set template not found");

        return Ok(result);
    }

    /// <summary>Deletes a set template.</summary>
    /// <param name="setId">The ID of the set template to delete.</param>
    /// <returns>204 No Content on success, or 404 if not found.</returns>
    [HttpDelete("exercises/sets/{setId}")]
    public async Task<IActionResult> DeleteSetTemplate([FromRoute] Guid setId)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        if (userId == Guid.Empty) return NotFound("User not found");

        var result = await _workoutService.DeleteSetTemplateAsync(setId);
        if (!result) return NotFound("Set template not found");

        return NoContent();
    }
}
