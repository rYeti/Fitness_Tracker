using FitTracker.Api.DTOs;
using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;


namespace FitTracker.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
/// <summary>Handles exercise library endpoints.</summary>
public class ExerciseController : ControllerBase
{
    private readonly IExerciseService _exerciseService;

    /// <summary>Initialises a new instance of <see cref="ExerciseController"/>.</summary>
    /// <param name="exerciseService">The exercise service.</param>
    public ExerciseController(IExerciseService exerciseService)
    {
        _exerciseService = exerciseService;
    }

    /// <summary>Creates a new exercise for the authenticated user.</summary>
    /// <param name="exercise">The exercise data to create.</param>
    /// <returns>The created exercise, or 404 Not Found if the user cannot be identified.</returns>
    [HttpPost("UserExercise")]
    [Authorize]
    public async Task<IActionResult> CreateExercise([FromBody] ExerciseRequestDto exercise)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);

        if (Guid.Empty == userId)
        {
            return NotFound("User not found");
        }

        var result = await _exerciseService.CreateExercise(exercise, userId);

        if (result == null)
        {
            return NotFound("No result");
        }

        return Ok(result);
    }

    /// <summary>Returns all exercises visible to the authenticated user.</summary>
    /// <param name="exerciseRequestDto">Optional filter criteria.</param>
    /// <returns>A list of exercises, or 404 Not Found if the user cannot be identified or no exercises exist.</returns>
    [HttpGet("AllExercises")]
    [Authorize]
    public async Task<IActionResult> GetExercises()
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);

        if (Guid.Empty == userId)
        {
            return NotFound("User not found");
        }

        var result = await _exerciseService.GetAllExercisesAsync(userId);

        if (result == null)
        {
            return NotFound("No result");
        }

        return Ok(result);
    }

    /// <summary>Returns exercises created by the authenticated user.</summary>
    /// <param name="exerciseRequestDto">Optional filter criteria.</param>
    /// <returns>A list of user-created exercises.</returns>
    [HttpGet("UserExercise")]
    [Authorize]
    public async Task<IActionResult> GetUserExercisesAsync()
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);

        if (Guid.Empty == userId)
        {
            return NotFound("User not found");
        }

        var result = await _exerciseService.GetUserExercisesAsync(userId);

        if (result == null)
        {
            return NotFound("No result");
        }

        return Ok(result);
    }

    /// <summary>Deletes an exercise belonging to the authenticated user.</summary>
    /// <param name="id">The ID of the exercise to delete.</param>
    /// <returns>204 No Content on success, or 404 Not Found if the exercise does not exist.</returns>
    [HttpDelete("UserExercise/{id}")]
    [Authorize]
    public async Task<IActionResult> DeleteExercise([FromRoute] Guid id)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);

        if (Guid.Empty == userId)
        {
            return NotFound("User not found");
        }

        var result = await _exerciseService.DeleteExercise(id, userId);

        if (result == false)
        {
            return NotFound("Exercise record not found");
        }

        return NoContent();
    }

    /// <summary>Updates an existing exercise belonging to the authenticated user.</summary>
    /// <param name="id">The ID of the exercise to update.</param>
    /// <param name="exercise">The updated exercise data.</param>
    /// <returns>The updated exercise, or 404 Not Found if the exercise does not exist.</returns>
    [HttpPut("UserExercise/{id}")]
    [Authorize]
    public async Task<IActionResult> UpdateExercises([FromRoute] Guid id, [FromBody] ExerciseRequestDto exercise)
    {
        var userId = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);

        if (Guid.Empty == userId)
        {
            return NotFound("User not found");
        }

        var result = await _exerciseService.UpdateExercise(id, userId, exercise);

        if (result == null)
        {
            return NotFound("No result");
        }

        return Ok(result);
    }


}