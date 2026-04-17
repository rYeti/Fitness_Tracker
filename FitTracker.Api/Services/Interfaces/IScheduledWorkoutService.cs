using FitTracker.Api.DTOs;

namespace FitTracker.Api.Services.Interfaces;

/// <summary>Business-logic contract for scheduled workouts, exercises, and performed sets.</summary>
public interface IScheduledWorkoutService
{
    /// <summary>Returns all scheduled workouts belonging to the specified user.</summary>
    /// <param name="userId">The user's ID.</param>
    Task<List<ScheduledWorkoutResponseDto>> GetUserScheduledWorkoutsAsync(Guid userId);

    /// <summary>Returns a single scheduled workout by ID, including its exercises and sets.</summary>
    /// <param name="id">The ID of the scheduled workout to retrieve.</param>
    /// <returns>The matching scheduled workout DTO, or <c>null</c> if not found.</returns>
    Task<ScheduledWorkoutResponseDto?> GetScheduledWorkoutByIdAsync(Guid id);

    /// <summary>Creates a new scheduled workout for the specified user.</summary>
    /// <param name="dto">The scheduled workout data to create.</param>
    /// <param name="userId">The ID of the user creating the entry.</param>
    /// <returns>The newly created scheduled workout DTO.</returns>
    Task<ScheduledWorkoutResponseDto> CreateScheduledWorkoutAsync(ScheduledWorkoutRequestDto dto, Guid userId);

    /// <summary>Updates an existing scheduled workout.</summary>
    /// <param name="id">The ID of the scheduled workout to update.</param>
    /// <param name="dto">The updated scheduled workout data.</param>
    /// <returns>The updated scheduled workout DTO, or <c>null</c> if not found.</returns>
    Task<ScheduledWorkoutResponseDto?> UpdateScheduledWorkoutAsync(Guid id, ScheduledWorkoutRequestDto dto);

    /// <summary>Deletes a scheduled workout by ID.</summary>
    /// <param name="id">The ID of the scheduled workout to delete.</param>
    /// <returns><c>true</c> if deleted; <c>false</c> if not found.</returns>
    Task<bool> DeleteScheduledWorkoutAsync(Guid id);

    /// <summary>Adds a performed set to a scheduled workout exercise.</summary>
    /// <param name="scheduledWorkoutExerciseId">The ID of the scheduled workout exercise to add the set to.</param>
    /// <param name="dto">The set data to create.</param>
    /// <returns>The newly created workout set DTO.</returns>
    Task<WorkoutSetResponseDto> AddSetAsync(Guid scheduledWorkoutExerciseId, WorkoutSetRequestDto dto);

    /// <summary>Updates an existing performed set.</summary>
    /// <param name="setId">The ID of the set to update.</param>
    /// <param name="dto">The updated set data.</param>
    /// <returns>The updated workout set DTO, or <c>null</c> if not found.</returns>
    Task<WorkoutSetResponseDto?> UpdateSetAsync(Guid setId, WorkoutSetRequestDto dto);

    /// <summary>Deletes a performed set by ID.</summary>
    /// <param name="setId">The ID of the set to delete.</param>
    /// <returns><c>true</c> if deleted; <c>false</c> if not found.</returns>
    Task<bool> DeleteSetAsync(Guid setId);

    /// <summary>Marks a scheduled exercise as completed.</summary>
    /// <param name="scheduledExerciseId">The ID of the scheduled exercise to complete.</param>
    /// <returns><c>true</c> if updated; <c>false</c> if not found.</returns>
    Task<bool> CompleteExerciseAsync(Guid scheduledExerciseId);

    /// <summary>Marks a scheduled workout as completed.</summary>
    /// <param name="scheduledWorkoutId">The ID of the scheduled workout to complete.</param>
    /// <returns><c>true</c> if updated; <c>false</c> if not found.</returns>
    Task<bool> CompleteWorkoutAsync(Guid scheduledWorkoutId);
}
