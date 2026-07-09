using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

/// <summary>Implementation of <see cref="IScheduledWorkoutService"/>.</summary>
public class ScheduledWorkoutService : IScheduledWorkoutService
{
    private readonly IScheduledWorkoutRepository _scheduledRepository;

    /// <summary>Initialises a new instance of <see cref="ScheduledWorkoutService"/>.</summary>
    /// <param name="scheduledRepository">The scheduled workout repository.</param>
    public ScheduledWorkoutService(IScheduledWorkoutRepository scheduledRepository)
    {
        _scheduledRepository = scheduledRepository;
    }

    /// <inheritdoc/>
    public async Task<List<ScheduledWorkoutResponseDto>> GetUserScheduledWorkoutsAsync(Guid userId)
    {
        var items = await _scheduledRepository.GetUserScheduledWorkoutsAsync(userId);
        return [.. items.Select(ToDto)];
    }

    /// <inheritdoc/>
    public async Task<ScheduledWorkoutResponseDto?> GetScheduledWorkoutByIdAsync(Guid id, Guid userId)
    {
        var sw = await _scheduledRepository.GetScheduledWorkoutByIdAsync(id, userId);
        return sw == null ? null : ToDto(sw);
    }

    /// <inheritdoc/>
    public async Task<ScheduledWorkoutResponseDto?> CreateScheduledWorkoutAsync(ScheduledWorkoutRequestDto dto, Guid userId)
    {
        var sw = new ScheduledWorkout
        {
            Id = Guid.NewGuid(),
            WorkoutId = dto.WorkoutId,
            WorkoutPlanId = dto.WorkoutPlanId,
            ScheduledDate = dto.ScheduledDate,
            CreatedAt = DateTime.UtcNow,
            Notes = dto.Notes,
            IsCompleted = dto.IsCompleted,
            IsSkipped = dto.IsSkipped,
        };

        var created = await _scheduledRepository.CreateScheduledWorkoutAsync(sw, userId);
        return created == null ? null : ToDto(created);
    }

    /// <inheritdoc/>
    public async Task<ScheduledWorkoutResponseDto?> UpdateScheduledWorkoutAsync(Guid id, Guid userId, ScheduledWorkoutRequestDto dto)
    {
        var updated = await _scheduledRepository.UpdateScheduledWorkoutAsync(id, userId, dto);
        return updated == null ? null : ToDto(updated);
    }

    /// <inheritdoc/>
    public async Task<bool> DeleteScheduledWorkoutAsync(Guid id, Guid userId)
    {
        return await _scheduledRepository.DeleteScheduledWorkoutAsync(id, userId);
    }

    /// <inheritdoc/>
    public async Task<WorkoutSetResponseDto?> AddSetAsync(Guid scheduledWorkoutExerciseId, Guid userId, WorkoutSetRequestDto dto)
    {
        var set = new WorkoutSet
        {
            Id = Guid.NewGuid(),
            ScheduledWorkoutExerciseId = scheduledWorkoutExerciseId,
            SetNumber = dto.SetNumber,
            Reps = dto.Reps,
            Weight = dto.Weight,
            WeightUnit = dto.WeightUnit,
            DurationSeconds = dto.DurationSeconds,
            Notes = dto.Notes,
            IsCompleted = dto.IsCompleted,
        };

        var created = await _scheduledRepository.AddSetAsync(set, userId);
        return created == null ? null : ToSetDto(created);
    }

    /// <inheritdoc/>
    public async Task<List<WorkoutSetResponseDto>> AddSetsBatchAsync(Guid scheduledWorkoutExerciseId, Guid userId, List<WorkoutSetRequestDto> dtos)
    {
        var results = new List<WorkoutSetResponseDto>();
        foreach (var dto in dtos)
        {
            var created = await AddSetAsync(scheduledWorkoutExerciseId, userId, dto);
            if (created != null) results.Add(created);
        }
        return results;
    }

    /// <inheritdoc/>
    public async Task<WorkoutSetResponseDto?> UpdateSetAsync(Guid setId, Guid userId, WorkoutSetRequestDto dto)
    {
        var updated = await _scheduledRepository.UpdateSetAsync(setId, userId, dto);
        return updated == null ? null : ToSetDto(updated);
    }

    /// <inheritdoc/>
    public async Task<bool> DeleteSetAsync(Guid setId, Guid userId)
    {
        return await _scheduledRepository.DeleteSetAsync(setId, userId);
    }

    /// <inheritdoc/>
    public async Task<bool> CompleteExerciseAsync(Guid scheduledExerciseId, Guid userId)
    {
        return await _scheduledRepository.CompleteExerciseAsync(scheduledExerciseId, userId);
    }

    /// <inheritdoc/>
    public async Task<bool> CompleteWorkoutAsync(Guid scheduledWorkoutId, Guid userId)
    {
        return await _scheduledRepository.CompleteWorkoutAsync(scheduledWorkoutId, userId);
    }

    /// <inheritdoc/>
    public async Task<List<ScheduledWorkoutExerciseResponseDto>?> CreateExercisesBatchAsync(Guid scheduledWorkoutId, Guid userId, List<Guid> workoutExerciseIds)
    {
        var created = await _scheduledRepository.CreateExercisesBatchAsync(scheduledWorkoutId, userId, workoutExerciseIds);
        return created == null ? null : [.. created.Select(ToExerciseDto)];
    }

    private static ScheduledWorkoutResponseDto ToDto(ScheduledWorkout sw) => new()
    {
        Id = sw.Id,
        WorkoutId = sw.WorkoutId,
        WorkoutPlanId = sw.WorkoutPlanId,
        TemplateWorkoutId = sw.TemplateWorkoutId,
        ScheduledDate = sw.ScheduledDate,
        CreatedAt = sw.CreatedAt,
        Notes = sw.Notes,
        IsCompleted = sw.IsCompleted,
        IsSkipped = sw.IsSkipped,
        Exercises = [.. sw.Exercises.Select(ToExerciseDto)],
    };

    private static ScheduledWorkoutExerciseResponseDto ToExerciseDto(ScheduledWorkoutExercise e) => new()
    {
        Id = e.Id,
        ScheduledWorkoutId = e.ScheduledWorkoutId,
        WorkoutExerciseId = e.WorkoutExerciseId,
        IsCompleted = e.IsCompleted,
        Notes = e.Notes,
        OverrideExerciseId = e.OverrideExerciseId,
        Sets = [.. e.Sets.Select(ToSetDto)],
    };

    private static WorkoutSetResponseDto ToSetDto(WorkoutSet s) => new()
    {
        Id = s.Id,
        ScheduledWorkoutExerciseId = s.ScheduledWorkoutExerciseId,
        SetNumber = s.SetNumber,
        Reps = s.Reps,
        Weight = s.Weight,
        WeightUnit = s.WeightUnit,
        DurationSeconds = s.DurationSeconds,
        IsCompleted = s.IsCompleted,
        Notes = s.Notes,
    };
}
