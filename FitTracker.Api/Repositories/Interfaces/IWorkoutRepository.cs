using FitTracker.Api.DTOs;
using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

/// <summary>Data-access contract for workout templates and their exercises and set templates.</summary>
public interface IWorkoutRepository
{
    /// <summary>Returns all workouts belonging to the specified user.</summary>
    /// <param name="userId">The user's ID.</param>
    Task<List<Workout>> GetUserWorkoutsAsync(Guid userId);

    /// <summary>Returns a single workout belonging to the specified user, including its exercises and set templates.</summary>
    /// <param name="id">The ID of the workout to retrieve.</param>
    /// <param name="userId">The ID of the user who owns the workout.</param>
    /// <returns>The matching workout, or <c>null</c> if not found.</returns>
    Task<Workout?> GetWorkoutByIdAsync(Guid id, Guid userId);

    /// <summary>Creates and persists a new workout.</summary>
    /// <param name="workout">The workout entity to persist.</param>
    /// <returns>The newly created workout.</returns>
    Task<Workout> CreateWorkoutAsync(Workout workout);

    /// <summary>Updates an existing workout owned by the specified user.</summary>
    /// <param name="id">The ID of the workout to update.</param>
    /// <param name="userId">The ID of the user who owns the workout.</param>
    /// <param name="dto">The updated workout data.</param>
    /// <returns>The updated workout, or <c>null</c> if not found.</returns>
    Task<Workout?> UpdateWorkoutAsync(Guid id, Guid userId, WorkoutRequestDto dto);

    /// <summary>Deletes a workout owned by the specified user.</summary>
    /// <param name="id">The ID of the workout to delete.</param>
    /// <param name="userId">The ID of the user who owns the workout.</param>
    /// <returns><c>true</c> if deleted; <c>false</c> if not found.</returns>
    Task<bool> DeleteWorkoutAsync(Guid id, Guid userId);

    /// <summary>Adds an exercise entry to a workout owned by the specified user.</summary>
    /// <param name="we">The workout exercise entity to persist.</param>
    /// <param name="userId">The ID of the user who must own the target workout.</param>
    /// <returns>The newly created workout exercise, or <c>null</c> if the workout doesn't exist or isn't owned by <paramref name="userId"/>.</returns>
    Task<WorkoutExercise?> AddExerciseToWorkoutAsync(WorkoutExercise we, Guid userId);

    /// <summary>Updates an existing workout exercise entry owned by the specified user.</summary>
    /// <param name="weId">The ID of the workout exercise to update.</param>
    /// <param name="userId">The ID of the user who must own the parent workout.</param>
    /// <param name="dto">The updated exercise data.</param>
    /// <returns>The updated workout exercise, or <c>null</c> if not found or not owned.</returns>
    Task<WorkoutExercise?> UpdateWorkoutExerciseAsync(Guid weId, Guid userId, WorkoutExerciseRequestDto dto);

    /// <summary>Deletes a workout exercise entry owned by the specified user.</summary>
    /// <param name="weId">The ID of the workout exercise to delete.</param>
    /// <param name="userId">The ID of the user who must own the parent workout.</param>
    /// <returns><c>true</c> if deleted; <c>false</c> if not found or not owned.</returns>
    Task<bool> DeleteWorkoutExerciseAsync(Guid weId, Guid userId);

    /// <summary>Adds a set template to a workout exercise owned by the specified user.</summary>
    /// <param name="t">The set template entity to persist.</param>
    /// <param name="userId">The ID of the user who must own the parent workout.</param>
    /// <returns>The newly created set template, or <c>null</c> if the workout exercise doesn't exist or isn't owned by <paramref name="userId"/>.</returns>
    Task<WorkoutSetTemplate?> AddSetTemplateAsync(WorkoutSetTemplate t, Guid userId);

    /// <summary>Updates an existing set template owned by the specified user.</summary>
    /// <param name="id">The ID of the set template to update.</param>
    /// <param name="userId">The ID of the user who must own the parent workout.</param>
    /// <param name="dto">The updated set template data.</param>
    /// <returns>The updated set template, or <c>null</c> if not found or not owned.</returns>
    Task<WorkoutSetTemplate?> UpdateSetTemplateAsync(Guid id, Guid userId, WorkoutSetTemplateRequestDto dto);

    /// <summary>Deletes a set template owned by the specified user.</summary>
    /// <param name="id">The ID of the set template to delete.</param>
    /// <param name="userId">The ID of the user who must own the parent workout.</param>
    /// <returns><c>true</c> if deleted; <c>false</c> if not found or not owned.</returns>
    Task<bool> DeleteSetTemplateAsync(Guid id, Guid userId);
}
