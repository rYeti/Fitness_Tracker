using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

/// <summary>Implementation of <see cref="IWorkoutService"/>.</summary>
public class WorkoutService : IWorkoutService
{
    private readonly IWorkoutRepository _workoutRepository;

    /// <summary>Initialises a new instance of <see cref="WorkoutService"/>.</summary>
    /// <param name="workoutRepository">The workout repository.</param>
    public WorkoutService(IWorkoutRepository workoutRepository)
    {
        _workoutRepository = workoutRepository;
    }

    /// <inheritdoc/>
    public async Task<List<WorkoutResponseDto>> GetUserWorkoutsAsync(Guid userId)
    {
        var workouts = await _workoutRepository.GetUserWorkoutsAsync(userId);
        return [.. workouts.Select(ToDto)];
    }

    /// <inheritdoc/>
    public async Task<WorkoutResponseDto?> GetWorkoutByIdAsync(Guid id, Guid userId)
    {
        var workout = await _workoutRepository.GetWorkoutByIdAsync(id, userId);
        return workout == null ? null : ToDto(workout);
    }

    /// <inheritdoc/>
    public async Task<WorkoutResponseDto> CreateWorkoutAsync(WorkoutRequestDto dto, Guid userId)
    {
        var workout = new Workout
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Name = dto.Name,
            Description = dto.Description,
            Difficulty = dto.Difficulty,
            EstimatedDurationMinutes = dto.EstimatedDurationMinutes,
            IsTemplate = dto.IsTemplate,
            ScheduledDate = dto.ScheduledDate,
            Color = dto.Color,
        };

        var created = await _workoutRepository.CreateWorkoutAsync(workout);
        return ToDto(created);
    }

    /// <inheritdoc/>
    public async Task<WorkoutResponseDto?> UpdateWorkoutAsync(Guid id, Guid userId, WorkoutRequestDto dto)
    {
        var updated = await _workoutRepository.UpdateWorkoutAsync(id, userId, dto);
        return updated == null ? null : ToDto(updated);
    }

    /// <inheritdoc/>
    public async Task<bool> DeleteWorkoutAsync(Guid id, Guid userId)
    {
        return await _workoutRepository.DeleteWorkoutAsync(id, userId);
    }

    /// <inheritdoc/>
    public async Task<WorkoutExerciseResponseDto?> AddExerciseToWorkoutAsync(Guid workoutId, Guid userId, WorkoutExerciseRequestDto dto)
    {
        var we = new WorkoutExercise
        {
            Id = Guid.NewGuid(),
            WorkoutId = workoutId,
            ExerciseId = dto.ExerciseId,
            OrderPosition = dto.OrderPosition,
            Notes = dto.Notes,
            SupersetGroupId = dto.SupersetGroupId,
        };

        var created = await _workoutRepository.AddExerciseToWorkoutAsync(we, userId);
        return created == null ? null : ToExerciseDto(created);
    }

    /// <inheritdoc/>
    public async Task<List<WorkoutExerciseResponseDto>> AddExercisesToWorkoutBatchAsync(Guid workoutId, Guid userId, List<WorkoutExerciseRequestDto> dtos)
    {
        var results = new List<WorkoutExerciseResponseDto>();
        foreach (var dto in dtos)
        {
            var created = await AddExerciseToWorkoutAsync(workoutId, userId, dto);
            if (created != null) results.Add(created);
        }
        return results;
    }

    /// <inheritdoc/>
    public async Task<WorkoutExerciseResponseDto?> UpdateWorkoutExerciseAsync(Guid weId, Guid userId, WorkoutExerciseRequestDto dto)
    {
        var updated = await _workoutRepository.UpdateWorkoutExerciseAsync(weId, userId, dto);
        return updated == null ? null : ToExerciseDto(updated);
    }

    /// <inheritdoc/>
    public async Task<bool> DeleteWorkoutExerciseAsync(Guid weId, Guid userId)
    {
        return await _workoutRepository.DeleteWorkoutExerciseAsync(weId, userId);
    }

    /// <inheritdoc/>
    public async Task<WorkoutSetTemplateResponseDto?> AddSetTemplateAsync(Guid workoutExerciseId, Guid userId, WorkoutSetTemplateRequestDto dto)
    {
        var template = new WorkoutSetTemplate
        {
            Id = Guid.NewGuid(),
            WorkoutExerciseId = workoutExerciseId,
            SetNumber = dto.SetNumber,
            TargetReps = dto.TargetReps,
            OrderPosition = dto.OrderPosition,
        };

        var created = await _workoutRepository.AddSetTemplateAsync(template, userId);
        return created == null ? null : ToSetTemplateDto(created);
    }

    /// <inheritdoc/>
    public async Task<List<WorkoutSetTemplateResponseDto>> AddSetTemplatesBatchAsync(Guid workoutExerciseId, Guid userId, List<WorkoutSetTemplateRequestDto> dtos)
    {
        // The batch is the exercise's whole prescription, not an addition to it: the
        // client rebuilds every set template locally whenever a workout is saved and
        // then pushes the lot. Appending them left the previous generation behind, so
        // an exercise re-saved twice reported three times as many sets as it has.
        if (dtos.Count == 0) return [];

        var templates = dtos.Select(dto => new WorkoutSetTemplate
        {
            Id = Guid.NewGuid(),
            WorkoutExerciseId = workoutExerciseId,
            SetNumber = dto.SetNumber,
            TargetReps = dto.TargetReps,
            OrderPosition = dto.OrderPosition,
        }).ToList();

        var replaced = await _workoutRepository.ReplaceSetTemplatesAsync(workoutExerciseId, userId, templates);
        return replaced == null ? [] : [.. replaced.Select(ToSetTemplateDto)];
    }

    /// <inheritdoc/>
    public async Task<WorkoutSetTemplateResponseDto?> UpdateSetTemplateAsync(Guid id, Guid userId, WorkoutSetTemplateRequestDto dto)
    {
        var updated = await _workoutRepository.UpdateSetTemplateAsync(id, userId, dto);
        return updated == null ? null : ToSetTemplateDto(updated);
    }

    /// <inheritdoc/>
    public async Task<bool> DeleteSetTemplateAsync(Guid id, Guid userId)
    {
        return await _workoutRepository.DeleteSetTemplateAsync(id, userId);
    }

    private static WorkoutResponseDto ToDto(Workout w) => new()
    {
        Id = w.Id,
        UserId = w.UserId,
        Name = w.Name,
        Description = w.Description,
        Difficulty = w.Difficulty,
        EstimatedDurationMinutes = w.EstimatedDurationMinutes,
        IsTemplate = w.IsTemplate,
        ScheduledDate = w.ScheduledDate,
        CompletedDate = w.CompletedDate,
        Color = w.Color,
        RemovedAt = w.RemovedAt,
        Exercises = [.. w.Exercises.Select(ToExerciseDto)],
    };

    private static WorkoutExerciseResponseDto ToExerciseDto(WorkoutExercise e) => new()
    {
        Id = e.Id,
        WorkoutId = e.WorkoutId,
        ExerciseId = e.ExerciseId,
        OrderPosition = e.OrderPosition,
        Notes = e.Notes,
        SupersetGroupId = e.SupersetGroupId,
        RemovedAt = e.RemovedAt,
        SetTemplates = [.. e.SetTemplates.Select(ToSetTemplateDto)],
    };

    private static WorkoutSetTemplateResponseDto ToSetTemplateDto(WorkoutSetTemplate t) => new()
    {
        Id = t.Id,
        WorkoutExerciseId = t.WorkoutExerciseId,
        SetNumber = t.SetNumber,
        TargetReps = t.TargetReps,
        OrderPosition = t.OrderPosition,
    };
}
