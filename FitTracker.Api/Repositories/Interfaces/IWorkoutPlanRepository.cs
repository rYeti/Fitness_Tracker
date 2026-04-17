using FitTracker.Api.DTOs;
using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

/// <summary>Data-access contract for workout plans and their workout membership records.</summary>
public interface IWorkoutPlanRepository
{
    /// <summary>Returns all workout plans belonging to the specified user.</summary>
    /// <param name="userId">The user's ID.</param>
    Task<List<WorkoutPlan>> GetUserPlansAsync(Guid userId);

    /// <summary>Returns a single workout plan belonging to the specified user, including its member workouts.</summary>
    /// <param name="id">The ID of the plan to retrieve.</param>
    /// <param name="userId">The ID of the user who owns the plan.</param>
    /// <returns>The matching plan, or <c>null</c> if not found.</returns>
    Task<WorkoutPlan?> GetPlanByIdAsync(Guid id, Guid userId);

    /// <summary>Creates and persists a new workout plan.</summary>
    /// <param name="plan">The workout plan entity to persist.</param>
    /// <returns>The newly created workout plan.</returns>
    Task<WorkoutPlan> CreatePlanAsync(WorkoutPlan plan);

    /// <summary>Updates an existing workout plan owned by the specified user.</summary>
    /// <param name="id">The ID of the plan to update.</param>
    /// <param name="userId">The ID of the user who owns the plan.</param>
    /// <param name="dto">The updated plan data.</param>
    /// <returns>The updated workout plan, or <c>null</c> if not found.</returns>
    Task<WorkoutPlan?> UpdatePlanAsync(Guid id, Guid userId, WorkoutPlanRequestDto dto);

    /// <summary>Deletes a workout plan owned by the specified user.</summary>
    /// <param name="id">The ID of the plan to delete.</param>
    /// <param name="userId">The ID of the user who owns the plan.</param>
    /// <returns><c>true</c> if deleted; <c>false</c> if not found.</returns>
    Task<bool> DeletePlanAsync(Guid id, Guid userId);

    /// <summary>Adds a workout to a plan by persisting the join record.</summary>
    /// <param name="link">The plan-workout join entity to persist.</param>
    Task AddWorkoutToPlanAsync(WorkoutPlanWorkout link);

    /// <summary>Removes a workout from a plan by deleting the join record.</summary>
    /// <param name="planId">The ID of the plan.</param>
    /// <param name="workoutId">The ID of the workout to remove.</param>
    /// <returns><c>true</c> if the link was deleted; <c>false</c> if not found.</returns>
    Task<bool> RemoveWorkoutFromPlanAsync(Guid planId, Guid workoutId);
}
