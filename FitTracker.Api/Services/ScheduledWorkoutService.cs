using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories;
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
    public async Task<List<ScheduledWorkoutResponseDto>> GetUserScheduledWorkoutsInRangeAsync(Guid userId, DateTime from, DateTime to)
    {
        var items = await _scheduledRepository.GetUserScheduledWorkoutsInRangeAsync(userId, from, to);
        return [.. items.Select(ToDto)];
    }

    /// <inheritdoc/>
    public Task<List<ClientTrainingStats>> GetClientTrainingStatsAsync(
        IReadOnlyCollection<Guid> clientIds,
        DateTime windowStart,
        DateTime windowEnd,
        DateTime weekStart,
        DateTime weekEnd) =>
        _scheduledRepository.GetClientTrainingStatsAsync(clientIds, windowStart, windowEnd, weekStart, weekEnd);

    /// <inheritdoc/>
    public Task<Dictionary<Guid, DateTime>> GetLastCompletedSessionDatesAsync(IReadOnlyCollection<Guid> clientIds) =>
        _scheduledRepository.GetLastCompletedSessionDatesAsync(clientIds);

    /// <inheritdoc/>
    public async Task<List<ScheduledWorkoutResponseDto>> GetRecentSessionsAsync(Guid userId, DateTime notAfter, int count)
    {
        var items = await _scheduledRepository.GetRecentSessionsAsync(userId, notAfter, count);
        return [.. items.Select(ToDto)];
    }

    /// <inheritdoc/>
    public Task<Dictionary<Guid, double>> GetBestWeightsBeforeAsync(Guid userId, DateTime before) =>
        _scheduledRepository.GetBestWeightsBeforeAsync(userId, before);

    /// <inheritdoc/>
    public async Task<ScheduledWorkoutResponseDto?> GetScheduledWorkoutByIdAsync(Guid id, Guid userId)
    {
        var sw = await _scheduledRepository.GetScheduledWorkoutByIdAsync(id, userId);
        return sw == null ? null : ToDto(sw);
    }

    /// <inheritdoc/>
    public Task<ScheduledWorkoutResponseDto?> CreateScheduledWorkoutAsync(ScheduledWorkoutRequestDto dto, Guid userId) =>
        // An id the server has never seen still meets the same-day check in the repository,
        // which answers with the session already there — under that session's id, which is
        // the one the app must keep.
        ClientIds.CreateOrResolveAsync(
            dto.Id,
            userId,
            _scheduledRepository.GetOwnerAsync,
            id => UpdateScheduledWorkoutAsync(id, userId, dto),
            async id =>
            {
                var created = await _scheduledRepository.CreateScheduledWorkoutAsync(new ScheduledWorkout
                {
                    Id = id,
                    WorkoutId = dto.WorkoutId,
                    WorkoutPlanId = dto.WorkoutPlanId,
                    ScheduledDate = dto.ScheduledDate,
                    CreatedAt = DateTime.UtcNow,
                    Notes = dto.Notes,
                    IsCompleted = dto.IsCompleted,
                    IsSkipped = dto.IsSkipped,
                }, userId);
                return created == null ? null : ToDto(created);
            });

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
            Rpe = dto.Rpe,
            SetType = dto.SetType ?? 0,
            Side = dto.Side ?? 0,
            Notes = dto.Notes,
            IsCompleted = dto.IsCompleted,
        };

        var created = await _scheduledRepository.AddSetAsync(set, userId);
        return created == null ? null : ToSetDto(created);
    }

    /// <inheritdoc/>
    public async Task<List<WorkoutSetResponseDto>?> AddSetsBatchAsync(Guid scheduledWorkoutExerciseId, Guid userId, List<WorkoutSetRequestDto> dtos)
    {
        // The batch is the exercise's whole log, not an addition to it — the same
        // correction AddSetTemplatesBatchAsync needed one table over. The client's active
        // workout rewrites an exercise's sets on every save, as fresh rows with no server
        // id, and the sync pushes those. Appending meant every save that followed a push
        // added another copy of the exercise: a session reviewed in the Trainer Console
        // listed "set 1" eight times. See docs/sync-concurrent-runs.md.
        //
        // An empty batch changes nothing, but still answers 404 for someone else's exercise.
        // A non-empty one leaves the owner check to the replace, which makes it anyway: this
        // used to check here first, and so twice for every batch on the push's hot path.
        if (dtos.Count == 0)
        {
            return await _scheduledRepository.GetExerciseOwnerAsync(scheduledWorkoutExerciseId) == userId ? [] : null;
        }

        // Each set keeps the id the app sent: a replace that minted fresh ones left the app
        // holding ids the server had just deleted. An id sent twice keeps it only once.
        var seen = new HashSet<Guid>();
        var sets = dtos.Select(dto => new WorkoutSet
        {
            Id = ClientIds.Requested(dto.Id) is { } id && seen.Add(id) ? id : Guid.NewGuid(),
            ScheduledWorkoutExerciseId = scheduledWorkoutExerciseId,
            SetNumber = dto.SetNumber,
            Reps = dto.Reps,
            Weight = dto.Weight,
            WeightUnit = dto.WeightUnit,
            DurationSeconds = dto.DurationSeconds,
            Rpe = dto.Rpe,
            SetType = dto.SetType ?? 0,
            Side = dto.Side ?? 0,
            Notes = dto.Notes,
            IsCompleted = dto.IsCompleted,
        }).ToList();

        var replaced = await _scheduledRepository.ReplaceSetsAsync(scheduledWorkoutExerciseId, userId, sets);
        return replaced?.Select(ToSetDto).ToList();
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
    public async Task<bool> UpdateExerciseNotesAsync(Guid scheduledExerciseId, Guid userId, string? notes)
    {
        return await _scheduledRepository.UpdateExerciseNotesAsync(scheduledExerciseId, userId, notes);
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
    public async Task<List<ScheduledWorkoutExerciseResponseDto>?> CreateExercisesBatchAsync(Guid scheduledWorkoutId, Guid userId, List<ScheduledExerciseBatchItemDto> items)
    {
        var created = await _scheduledRepository.CreateExercisesBatchAsync(scheduledWorkoutId, userId, items);
        return created?.Select(c =>
        {
            var dto = ToExerciseDto(c.Entry);
            dto.RequestedId = c.RequestedId;
            return dto;
        }).ToList();
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
        Rpe = s.Rpe,
        SetType = s.SetType,
        Side = s.Side,
        IsCompleted = s.IsCompleted,
        Notes = s.Notes,
    };
}
