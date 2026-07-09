using FitTracker.Api.DTOs;
using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

/// <summary>Data-access contract for exercise records.</summary>
public interface IExerciseRepository
{
    /// <summary>Returns all exercises belonging to the specified user.</summary>
    /// <param name="id">The user's ID.</param>
    Task<List<Exercise>> GetUserExercisesAsync(Guid id);

    /// <summary>Updates an existing exercise owned by the specified user.</summary>
    /// <param name="exercise">The updated exercise data.</param>
    /// <param name="userId">The ID of the user who owns the exercise.</param>
    /// <param name="id">The ID of the exercise to update.</param>
    /// <returns>The updated exercise, or <c>null</c> if not found.</returns>
    Task<Exercise> UpdateExerciseAsync(ExerciseRequestDto exercise, Guid userId, Guid id);

    /// <summary>Deletes an exercise owned by the specified user.</summary>
    /// <param name="id">The ID of the exercise to delete.</param>
    /// <param name="userId">The ID of the user who owns the exercise.</param>
    /// <returns><c>true</c> if deleted; <c>false</c> if not found.</returns>
    Task<bool> DeleteExerciseAsync(Guid id, Guid userId);

    /// <summary>Creates a new exercise.</summary>
    /// <param name="exercise">The exercise to create.</param>
    /// <returns>The newly created exercise.</returns>
    Task<Exercise> CreateExercisesAsync(Exercise exercise);

    /// <summary>Returns all exercises visible to the given user — system-provided exercises plus that user's own custom ones.</summary>
    /// <param name="userId">The ID of the requesting user.</param>
    Task<List<Exercise>> GetAllExercisesAsync(Guid userId);
}