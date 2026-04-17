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

    /// <summary>Adds an exercise entry to a workout.</summary>
    /// <param name="we">The workout exercise entity to persist.</param>
    /// <returns>The newly created workout exercise.</returns>
    Task<WorkoutExercise> AddExerciseToWorkoutAsync(WorkoutExercise we);

    /// <summary>Updates an existing workout exercise entry.</summary>
    /// <param name="weId">The ID of the workout exercise to update.</param>
    /// <param name="dto">The updated exercise data.</param>
    /// <returns>The updated workout exercise, or <c>null</c> if not found.</returns>
    Task<WorkoutExercise?> UpdateWorkoutExerciseAsync(Guid weId, WorkoutExerciseRequestDto dto);

    /// <summary>Deletes a workout exercise entry.</summary>
    /// <param name="weId">The ID of the workout exercise to delete.</param>
    /// <returns><c>true</c> if deleted; <c>false</c> if not found.</returns>
    Task<bool> DeleteWorkoutExerciseAsync(Guid weId);

    /// <summary>Adds a set template to a workout exercise.</summary>
    /// <param name="t">The set template entity to persist.</param>
    /// <returns>The newly created set template.</returns>
    Task<WorkoutSetTemplate> AddSetTemplateAsync(WorkoutSetTemplate t);

    /// <summary>Updates an existing set template.</summary>
    /// <param name="id">The ID of the set template to update.</param>
    /// <param name="dto">The updated set template data.</param>
    /// <returns>The updated set template, or <c>null</c> if not found.</returns>
    Task<WorkoutSetTemplate?> UpdateSetTemplateAsync(Guid id, WorkoutSetTemplateRequestDto dto);

    /// <summary>Deletes a set template.</summary>
    /// <param name="id">The ID of the set template to delete.</param>
    /// <returns><c>true</c> if deleted; <c>false</c> if not found.</returns>
    Task<bool> DeleteSetTemplateAsync(Guid id);
}
