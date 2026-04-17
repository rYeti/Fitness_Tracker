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
    public async Task<WorkoutExerciseResponseDto> AddExerciseToWorkoutAsync(Guid workoutId, WorkoutExerciseRequestDto dto)
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

        var created = await _workoutRepository.AddExerciseToWorkoutAsync(we);
        return ToExerciseDto(created);
    }

    /// <inheritdoc/>
    public async Task<WorkoutExerciseResponseDto?> UpdateWorkoutExerciseAsync(Guid weId, WorkoutExerciseRequestDto dto)
    {
        var updated = await _workoutRepository.UpdateWorkoutExerciseAsync(weId, dto);
        return updated == null ? null : ToExerciseDto(updated);
    }

    /// <inheritdoc/>
    public async Task<bool> DeleteWorkoutExerciseAsync(Guid weId)
    {
        return await _workoutRepository.DeleteWorkoutExerciseAsync(weId);
    }

    /// <inheritdoc/>
    public async Task<WorkoutSetTemplateResponseDto> AddSetTemplateAsync(Guid workoutExerciseId, WorkoutSetTemplateRequestDto dto)
    {
        var template = new WorkoutSetTemplate
        {
            Id = Guid.NewGuid(),
            WorkoutExerciseId = workoutExerciseId,
            SetNumber = dto.SetNumber,
            TargetReps = dto.TargetReps,
            OrderPosition = dto.OrderPosition,
        };

        var created = await _workoutRepository.AddSetTemplateAsync(template);
        return ToSetTemplateDto(created);
    }

    /// <inheritdoc/>
    public async Task<WorkoutSetTemplateResponseDto?> UpdateSetTemplateAsync(Guid id, WorkoutSetTemplateRequestDto dto)
    {
        var updated = await _workoutRepository.UpdateSetTemplateAsync(id, dto);
        return updated == null ? null : ToSetTemplateDto(updated);
    }

    /// <inheritdoc/>
    public async Task<bool> DeleteSetTemplateAsync(Guid id)
    {
        return await _workoutRepository.DeleteSetTemplateAsync(id);
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
