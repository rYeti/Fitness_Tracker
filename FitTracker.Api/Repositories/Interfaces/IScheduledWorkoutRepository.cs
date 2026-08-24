using FitTracker.Api.DTOs;
using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

/// <summary>Data-access contract for scheduled workouts, their exercises, and performed sets.</summary>
public interface IScheduledWorkoutRepository
{
    /// <summary>Returns all scheduled workouts belonging to the specified user.</summary>
    /// <param name="userId">The user's ID.</param>
    Task<List<ScheduledWorkout>> GetUserScheduledWorkoutsAsync(Guid userId);

    /// <summary>Returns a single scheduled workout owned by the specified user, including its exercises and sets.</summary>
    /// <param name="id">The ID of the scheduled workout to retrieve.</param>
    /// <param name="userId">The ID of the user who must own the underlying workout.</param>
    /// <returns>The matching scheduled workout, or <c>null</c> if not found or not owned.</returns>
    Task<ScheduledWorkout?> GetScheduledWorkoutByIdAsync(Guid id, Guid userId);

    /// <summary>Creates and persists a new scheduled workout, if the referenced workout (and plan, if any) belong to the specified user.</summary>
    /// <param name="sw">The scheduled workout entity to persist.</param>
    /// <param name="userId">The ID of the user who must own the referenced workout/plan.</param>
    /// <returns>The newly created scheduled workout, or <c>null</c> if the referenced workout/plan isn't owned by <paramref name="userId"/>.</returns>
    Task<ScheduledWorkout?> CreateScheduledWorkoutAsync(ScheduledWorkout sw, Guid userId);

    /// <summary>Updates an existing scheduled workout owned by the specified user.</summary>
    /// <param name="id">The ID of the scheduled workout to update.</param>
    /// <param name="userId">The ID of the user who must own the scheduled workout and any newly-referenced workout.</param>
    /// <param name="dto">The updated scheduled workout data.</param>
    /// <returns>The updated scheduled workout, or <c>null</c> if not found, not owned, or the new workout reference isn't owned.</returns>
    Task<ScheduledWorkout?> UpdateScheduledWorkoutAsync(Guid id, Guid userId, ScheduledWorkoutRequestDto dto);

    /// <summary>Deletes a scheduled workout owned by the specified user.</summary>
    /// <param name="id">The ID of the scheduled workout to delete.</param>
    /// <param name="userId">The ID of the user who must own the scheduled workout.</param>
    /// <returns><c>true</c> if deleted; <c>false</c> if not found or not owned.</returns>
    Task<bool> DeleteScheduledWorkoutAsync(Guid id, Guid userId);

    /// <summary>Creates scheduled workout exercise records for a set of workout exercise IDs, if the scheduled workout is owned by the specified user.</summary>
    /// <param name="scheduledWorkoutId">The scheduled workout to attach exercises to.</param>
    /// <param name="userId">The ID of the user who must own the scheduled workout.</param>
    /// <param name="workoutExerciseIds">The workout exercise template IDs to link.</param>
    /// <returns>The newly created scheduled workout exercises, or <c>null</c> if the scheduled workout isn't found/owned.</returns>
    Task<List<ScheduledWorkoutExercise>?> CreateExercisesBatchAsync(Guid scheduledWorkoutId, Guid userId, List<Guid> workoutExerciseIds);

    /// <summary>Adds a performed set to a scheduled workout exercise owned by the specified user.</summary>
    /// <param name="set">The workout set entity to persist.</param>
    /// <param name="userId">The ID of the user who must own the parent scheduled workout.</param>
    /// <returns>The newly created workout set, or <c>null</c> if the scheduled workout exercise isn't found/owned.</returns>
    Task<WorkoutSet?> AddSetAsync(WorkoutSet set, Guid userId);

    /// <summary>Replaces every set logged against a scheduled exercise with <paramref name="sets"/>,
    /// in one transaction.</summary>
    /// <param name="scheduledWorkoutExerciseId">The scheduled exercise whose log is being rewritten.</param>
    /// <param name="userId">The ID of the user who must own the parent scheduled workout.</param>
    /// <param name="sets">The complete new log — never partial, anything omitted is deleted.</param>
    /// <returns>The stored sets, or <c>null</c> if the scheduled exercise doesn't exist or isn't owned by <paramref name="userId"/>.</returns>
    Task<List<WorkoutSet>?> ReplaceSetsAsync(Guid scheduledWorkoutExerciseId, Guid userId, List<WorkoutSet> sets);

    /// <summary>Updates an existing performed set owned by the specified user.</summary>
    /// <param name="setId">The ID of the set to update.</param>
    /// <param name="userId">The ID of the user who must own the parent scheduled workout.</param>
    /// <param name="dto">The updated set data.</param>
    /// <returns>The updated workout set, or <c>null</c> if not found or not owned.</returns>
    Task<WorkoutSet?> UpdateSetAsync(Guid setId, Guid userId, WorkoutSetRequestDto dto);

    /// <summary>Deletes a performed set owned by the specified user.</summary>
    /// <param name="setId">The ID of the set to delete.</param>
    /// <param name="userId">The ID of the user who must own the parent scheduled workout.</param>
    /// <returns><c>true</c> if deleted; <c>false</c> if not found or not owned.</returns>
    Task<bool> DeleteSetAsync(Guid setId, Guid userId);

    /// <summary>Marks a scheduled exercise as completed, if owned by the specified user.</summary>
    /// <param name="scheduledExerciseId">The ID of the scheduled exercise to complete.</param>
    /// <param name="userId">The ID of the user who must own the parent scheduled workout.</param>
    /// <returns><c>true</c> if updated; <c>false</c> if not found or not owned.</returns>
    Task<bool> CompleteExerciseAsync(Guid scheduledExerciseId, Guid userId);

    /// <summary>Marks a scheduled workout as completed, if owned by the specified user.</summary>
    /// <param name="scheduledWorkoutId">The ID of the scheduled workout to complete.</param>
    /// <param name="userId">The ID of the user who must own the scheduled workout.</param>
    /// <returns><c>true</c> if updated; <c>false</c> if not found or not owned.</returns>
    Task<bool> CompleteWorkoutAsync(Guid scheduledWorkoutId, Guid userId);
}
