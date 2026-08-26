using FitTracker.Api.DTOs;
using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

/// <summary>Data-access contract for exercise records.</summary>
public interface IExerciseRepository
{
    /// <summary>Returns all exercises belonging to the specified user.</summary>
    /// <param name="id">The user's ID.</param>
    Task<List<Exercise>> GetUserExercisesAsync(Guid id);

    /// <summary>The names of the given exercises, keyed by exercise id. Ids that don't resolve
    /// are simply absent.</summary>
    /// <remarks>The Trainer Console needs nothing but names, and used to get them by loading the
    /// entire global exercise catalogue as full entities — descriptions, image URLs, muscle
    /// groups — mapping every row to a DTO and keeping one string per row.
    ///
    /// Missing ids are expected, not an error: exercises may be seeded on the device, so a
    /// <c>WorkoutExercise.ExerciseId</c> is an opaque reference with no foreign key behind it.</remarks>
    Task<Dictionary<Guid, string>> GetNamesByIdsAsync(IReadOnlyCollection<Guid> exerciseIds);

    /// <summary>The exercise name behind each of the given <c>WorkoutExercise</c> ids.</summary>
    /// <remarks>Saves callers holding a scheduled session — which references the workout-exercise
    /// entry, not the exercise definition — from loading the user's whole workout library just to
    /// walk one id to the next.</remarks>
    Task<Dictionary<Guid, string>> GetNamesByWorkoutExerciseIdsAsync(IReadOnlyCollection<Guid> workoutExerciseIds);

    /// <summary>Updates an existing exercise owned by the specified user.</summary>
    /// <param name="exercise">The updated exercise data.</param>
    /// <param name="userId">The ID of the user who owns the exercise.</param>
    /// <param name="id">The ID of the exercise to update.</param>
    /// <returns>The updated exercise, or <c>null</c> if not found.</returns>
    Task<Exercise?> UpdateExerciseAsync(ExerciseRequestDto exercise, Guid userId, Guid id);

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