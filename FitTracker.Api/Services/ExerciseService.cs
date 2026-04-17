using FitTracker.Api.DTOs;
using FitTracker.Api.Services.Interfaces;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
namespace FitTracker.Api.Services;

/// <summary>Implementation of <see cref="IExerciseService"/>.</summary>
public class ExerciseService : IExerciseService
{

    private readonly IExerciseRepository _exerciseRepository;

    public ExerciseService(IExerciseRepository exerciseRepository)
    {
        _exerciseRepository = exerciseRepository;
    }

    /// <inheritdoc/>
    public async Task<ExerciseResponseDto> CreateExercise(ExerciseRequestDto exercise, Guid userId)
    {
        if (userId == Guid.Empty || exercise == null) return null!;

        var exerciseModel = new Exercise
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Name = exercise.Name,
            NameDe = exercise.NameDe,
            Description = exercise.Description,
            DescriptionDe = exercise.DescriptionDe,
            ImageUrl = exercise.ImageUrl,
            IsCustom = exercise.IsCustom,
            TargetMuscleGroups = exercise.TargetMuscleGroups,
            Type = exercise.Type,
        };

        var created = await _exerciseRepository.CreateExercisesAsync(exerciseModel);
        return ToResponseDto(created);
    }

    /// <inheritdoc/>
    public async Task<bool> DeleteExercise(Guid id, Guid userId)
    {
        return await _exerciseRepository.DeleteExerciseAsync(id, userId);
    }

    /// <inheritdoc/>
    public async Task<List<ExerciseResponseDto>> GetAllExercisesAsync(Guid userId)
    {
        var exercises = await _exerciseRepository.GetAllExercisesAsync();
        return [.. exercises.Select(ToResponseDto)];
    }

    /// <inheritdoc/>
    public async Task<List<ExerciseResponseDto>> GetUserExercisesAsync(Guid id)
    {
        var exercises = await _exerciseRepository.GetUserExercisesAsync(id);
        return [.. exercises.Select(ToResponseDto)];
    }

    /// <inheritdoc/>
    public async Task<ExerciseResponseDto> UpdateExercise(Guid id, Guid userId, ExerciseRequestDto exercise)
    {
        var updated = await _exerciseRepository.UpdateExerciseAsync(exercise, userId, id);
        return updated == null ? null! : ToResponseDto(updated);
    }

    private static ExerciseResponseDto ToResponseDto(Exercise e) => new()
    {
        id = e.Id,
        Name = e.Name,
        NameDe = e.NameDe,
        Description = e.Description,
        DescriptionDe = e.DescriptionDe,
        ImageUrl = e.ImageUrl,
        IsCustom = e.IsCustom,
        TargetMuscleGroups = e.TargetMuscleGroups,
        Type = e.Type,
    };
}