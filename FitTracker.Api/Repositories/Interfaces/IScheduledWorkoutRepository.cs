using FitTracker.Api.DTOs;
using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

/// <summary>Data-access contract for scheduled workouts, their exercises, and performed sets.</summary>
public interface IScheduledWorkoutRepository
{
    /// <summary>Returns all scheduled workouts belonging to the specified user.</summary>
    /// <param name="userId">The user's ID.</param>
    Task<List<ScheduledWorkout>> GetUserScheduledWorkoutsAsync(Guid userId);

    /// <summary>Returns a single scheduled workout by ID, including its exercises and sets.</summary>
    /// <param name="id">The ID of the scheduled workout to retrieve.</param>
    /// <returns>The matching scheduled workout, or <c>null</c> if not found.</returns>
    Task<ScheduledWorkout?> GetScheduledWorkoutByIdAsync(Guid id);

    /// <summary>Creates and persists a new scheduled workout.</summary>
    /// <param name="sw">The scheduled workout entity to persist.</param>
    /// <returns>The newly created scheduled workout.</returns>
    Task<ScheduledWorkout> CreateScheduledWorkoutAsync(ScheduledWorkout sw);

    /// <summary>Updates an existing scheduled workout.</summary>
    /// <param name="id">The ID of the scheduled workout to update.</param>
    /// <param name="dto">The updated scheduled workout data.</param>
    /// <returns>The updated scheduled workout, or <c>null</c> if not found.</returns>
    Task<ScheduledWorkout?> UpdateScheduledWorkoutAsync(Guid id, ScheduledWorkoutRequestDto dto);

    /// <summary>Deletes a scheduled workout by ID.</summary>
    /// <param name="id">The ID of the scheduled workout to delete.</param>
    /// <returns><c>true</c> if deleted; <c>false</c> if not found.</returns>
    Task<bool> DeleteScheduledWorkoutAsync(Guid id);

    /// <summary>Returns a single scheduled workout exercise by ID.</summary>
    /// <param name="id">The ID of the scheduled exercise to retrieve.</param>
    /// <returns>The matching scheduled exercise, or <c>null</c> if not found.</returns>
    Task<ScheduledWorkoutExercise?> GetScheduledExerciseAsync(Guid id);

    /// <summary>Adds a performed set to a scheduled workout exercise.</summary>
    /// <param name="set">The workout set entity to persist.</param>
    /// <returns>The newly created workout set.</returns>
    Task<WorkoutSet> AddSetAsync(WorkoutSet set);

    /// <summary>Updates an existing performed set.</summary>
    /// <param name="setId">The ID of the set to update.</param>
    /// <param name="dto">The updated set data.</param>
    /// <returns>The updated workout set, or <c>null</c> if not found.</returns>
    Task<WorkoutSet?> UpdateSetAsync(Guid setId, WorkoutSetRequestDto dto);

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
