using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

/// <summary>Implementation of <see cref="IWorkoutService"/>.</summary>
public class WorkoutService : IWorkoutService
{
    private readonly IWorkoutRepository _workoutRepository;
    private readonly ISyncTombstoneRepository _tombstones;

    /// <summary>Initialises a new instance of <see cref="WorkoutService"/>.</summary>
    /// <param name="tombstones">Which of the caller's ids were deleted.</param>
    /// <param name="workoutRepository">The workout repository.</param>
    public WorkoutService(IWorkoutRepository workoutRepository, ISyncTombstoneRepository tombstones)
    {
        _workoutRepository = workoutRepository;
        _tombstones = tombstones;
    }

    /// <inheritdoc/>
    public async Task<List<WorkoutResponseDto>> GetUserWorkoutsAsync(Guid userId, DateTime? changedSince = null)
    {
        var workouts = await _workoutRepository.GetUserWorkoutsAsync(userId, changedSince);
        return [.. workouts.Select(ToDto)];
    }

    /// <inheritdoc/>
    public Task<Dictionary<Guid, string>> GetNamesByIdsAsync(IReadOnlyCollection<Guid> workoutIds) =>
        _workoutRepository.GetNamesByIdsAsync(workoutIds);

    /// <inheritdoc/>
    public async Task<List<WorkoutExerciseResponseDto>> GetExercisesByIdsAsync(IReadOnlyCollection<Guid> workoutExerciseIds)
    {
        var exercises = await _workoutRepository.GetExercisesByIdsAsync(workoutExerciseIds);
        return [.. exercises.Select(ToExerciseDto)];
    }

    /// <inheritdoc/>
    public async Task<WorkoutResponseDto?> GetWorkoutByIdAsync(Guid id, Guid userId)
    {
        var workout = await _workoutRepository.GetWorkoutByIdAsync(id, userId);
        return workout == null ? null : ToDto(workout);
    }

    /// <inheritdoc/>
    public async Task<WorkoutResponseDto> CreateWorkoutAsync(WorkoutRequestDto dto, Guid userId, Guid? assignedByTrainerId = null)
    {
        var result = await ClientIds.CreateOrResolveAsync(
            dto.Id,
            userId,
            _workoutRepository.GetWorkoutOwnerAsync,
            id => _tombstones.WasDeletedAsync(userId, id),
            id => UpdateWorkoutAsync(id, userId, dto),
            async id => ToDto(await _workoutRepository.CreateWorkoutAsync(new Workout
            {
                Id = id,
                UserId = userId,
                Name = dto.Name,
                Description = dto.Description,
                Difficulty = dto.Difficulty,
                EstimatedDurationMinutes = dto.EstimatedDurationMinutes,
                IsTemplate = dto.IsTemplate,
                ScheduledDate = dto.ScheduledDate,
                Color = dto.Color,
                AssignedByTrainerId = assignedByTrainerId,
            })));
        return result!;
    }

    /// <inheritdoc/>
    public async Task<WorkoutResponseDto?> UpdateWorkoutAsync(Guid id, Guid userId, WorkoutRequestDto dto)
    {
        var updated = await _workoutRepository.UpdateWorkoutAsync(id, userId, dto);
        return updated == null ? null : ToDto(updated);
    }

    /// <inheritdoc/>
    public async Task<WorkoutDeleteResult> DeleteWorkoutAsync(Guid id, Guid userId, bool actingAsTrainer = false)
    {
        return await _workoutRepository.DeleteWorkoutAsync(id, userId, actingAsTrainer);
    }

    /// <inheritdoc/>
    public Task<WorkoutExerciseResponseDto?> AddExerciseToWorkoutAsync(Guid workoutId, Guid userId, WorkoutExerciseRequestDto dto) =>
        // The slot check in the repository still applies to an id it has never seen: an
        // entry for the same exercise at the same position is answered with the row
        // already there, under that row's id — which is the one the app must keep.
        //
        // A workout exercise is never tombstoned (docs/sync-architecture.md §29), so no
        // tombstone lookup could ever match one; asking would be a query per create that
        // always answers no, and would suggest a removed entry's id is refused when it isn't.
        ClientIds.CreateOrResolveAsync(
            dto.Id,
            userId,
            _workoutRepository.GetWorkoutExerciseOwnerAsync,
            _ => Task.FromResult(false),
            id => UpdateWorkoutExerciseAsync(id, userId, dto),
            async id =>
            {
                var created = await _workoutRepository.AddExerciseToWorkoutAsync(new WorkoutExercise
                {
                    Id = id,
                    WorkoutId = workoutId,
                    ExerciseId = dto.ExerciseId,
                    OrderPosition = dto.OrderPosition,
                    Notes = dto.Notes,
                    SupersetGroupId = dto.SupersetGroupId,
                }, userId);
                return created == null ? null : ToExerciseDto(created);
            });

    /// <inheritdoc/>
    public async Task<List<WorkoutExerciseResponseDto>?> AddExercisesToWorkoutBatchAsync(Guid workoutId, Guid userId, List<WorkoutExerciseRequestDto> dtos)
    {
        // Answering 200 with an empty list for someone else's workout read, to the app,
        // exactly like "created nothing" — so it said nothing and never retried.
        if (await _workoutRepository.GetWorkoutOwnerAsync(workoutId) != userId) return null;

        // Each answer says which item it answers. The slot check can answer an item with the
        // entry already in its slot, under that entry's id, so the id alone doesn't say; and
        // the app used to pair the answer with its request by position, which isn't an
        // identity either — an item that failed shifted every pairing after it.
        var results = new List<WorkoutExerciseResponseDto>();
        foreach (var dto in dtos)
        {
            var created = await AddExerciseToWorkoutAsync(workoutId, userId, dto);
            if (created == null) continue;
            created.RequestedId = ClientIds.Requested(dto.Id);
            results.Add(created);
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
    public async Task<List<WorkoutSetTemplateResponseDto>?> AddSetTemplatesBatchAsync(Guid workoutExerciseId, Guid userId, List<WorkoutSetTemplateRequestDto> dtos)
    {
        // The batch is the exercise's whole prescription, not an addition to it: the
        // client rebuilds every set template locally whenever a workout is saved and
        // then pushes the lot. Appending them left the previous generation behind, so
        // an exercise re-saved twice reported three times as many sets as it has.
        //
        // An empty batch changes nothing (unlike ReplaceSetTemplatesAsync below), but still
        // answers 404 for someone else's exercise. A non-empty one leaves the owner check to
        // the replace, which makes it anyway — see AddSetsBatchAsync on sessions.
        if (dtos.Count == 0)
        {
            return await _workoutRepository.GetWorkoutExerciseOwnerAsync(workoutExerciseId) == userId ? [] : null;
        }

        var replaced = await _workoutRepository.ReplaceSetTemplatesAsync(
            workoutExerciseId, userId, ToSetTemplates(workoutExerciseId, dtos));
        return replaced?.Select(ToSetTemplateDto).ToList();
    }

    /// <inheritdoc/>
    public async Task<List<WorkoutSetTemplateResponseDto>?> ReplaceSetTemplatesAsync(Guid workoutExerciseId, Guid userId, List<WorkoutSetTemplateRequestDto> dtos)
    {
        var replaced = await _workoutRepository.ReplaceSetTemplatesAsync(
            workoutExerciseId, userId, ToSetTemplates(workoutExerciseId, dtos));
        return replaced?.Select(ToSetTemplateDto).ToList();
    }

    /// <summary>The rows a replace inserts. Each keeps the id the app sent — a replace that
    /// minted fresh ones left the app holding ids the server had just deleted — and an id
    /// sent twice keeps it only once.</summary>
    private static List<WorkoutSetTemplate> ToSetTemplates(Guid workoutExerciseId, List<WorkoutSetTemplateRequestDto> dtos)
    {
        var seen = new HashSet<Guid>();
        return dtos.Select(dto =>
        {
            var id = ClientIds.Requested(dto.Id) is { } requested && seen.Add(requested)
                ? requested
                : Guid.NewGuid();
            return new WorkoutSetTemplate
            {
                Id = id,
                WorkoutExerciseId = workoutExerciseId,
                SetNumber = dto.SetNumber,
                TargetReps = dto.TargetReps,
                OrderPosition = dto.OrderPosition,
            };
        }).ToList();
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

    /// <inheritdoc/>
    public Task<HashSet<Guid>> GetWorkoutExerciseIdsWithLoggedSetsAsync(IReadOnlyCollection<Guid> workoutExerciseIds) =>
        _workoutRepository.GetWorkoutExerciseIdsWithLoggedSetsAsync(workoutExerciseIds);

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
        AssignedByTrainer = w.AssignedByTrainerId != null,
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
