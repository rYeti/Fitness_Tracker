using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

/// <summary>Implementation of <see cref="IWorkoutPlanService"/>.</summary>
public class WorkoutPlanService : IWorkoutPlanService
{
    private readonly IWorkoutPlanRepository _planRepository;

    /// <summary>Initialises a new instance of <see cref="WorkoutPlanService"/>.</summary>
    /// <param name="planRepository">The workout plan repository.</param>
    public WorkoutPlanService(IWorkoutPlanRepository planRepository)
    {
        _planRepository = planRepository;
    }

    /// <inheritdoc/>
    public async Task<List<WorkoutPlanResponseDto>> GetUserPlansAsync(Guid userId)
    {
        var plans = await _planRepository.GetUserPlansAsync(userId);
        return [.. plans.Select(ToDto)];
    }

    /// <inheritdoc/>
    public Task<Dictionary<Guid, string>> GetActivePlanNamesAsync(IReadOnlyCollection<Guid> userIds) =>
        _planRepository.GetActivePlanNamesAsync(userIds);

    /// <inheritdoc/>
    public async Task<WorkoutPlanResponseDto?> GetPlanByIdAsync(Guid id, Guid userId)
    {
        var plan = await _planRepository.GetPlanByIdAsync(id, userId);
        return plan == null ? null : ToDto(plan);
    }

    /// <inheritdoc/>
    public async Task<WorkoutPlanResponseDto> CreatePlanAsync(WorkoutPlanRequestDto dto, Guid userId, Guid? assignedByTrainerId = null)
    {
        var result = await ClientIds.CreateOrResolveAsync(
            dto.Id,
            userId,
            _planRepository.GetOwnerAsync,
            id => UpdatePlanAsync(id, userId, dto),
            async id => ToDto(await _planRepository.CreatePlanAsync(new WorkoutPlan
            {
                Id = id,
                UserId = userId,
                Name = dto.Name,
                Description = dto.Description,
                StartDate = dto.StartDate,
                CreatedAt = DateTime.UtcNow,
                IsActive = true,
                CyclePatternJson = dto.CyclePatternJson,
                IsFreeChoice = dto.IsFreeChoice,
                DurationDays = dto.DurationDays,
                AssignedByTrainerId = assignedByTrainerId,
            })));
        return result!;
    }

    /// <inheritdoc/>
    public async Task<WorkoutPlanResponseDto?> UpdatePlanAsync(Guid id, Guid userId, WorkoutPlanRequestDto dto)
    {
        var updated = await _planRepository.UpdatePlanAsync(id, userId, dto);
        return updated == null ? null : ToDto(updated);
    }

    /// <inheritdoc/>
    public async Task<PlanDeleteResult> DeletePlanAsync(Guid id, Guid userId, bool actingAsTrainer = false)
    {
        return await _planRepository.DeletePlanAsync(id, userId, actingAsTrainer);
    }

    /// <inheritdoc/>
    public async Task<bool> AddWorkoutToPlanAsync(Guid planId, Guid workoutId, Guid userId)
    {
        var link = new WorkoutPlanWorkout
        {
            Id = Guid.NewGuid(),
            PlanId = planId,
            WorkoutId = workoutId,
        };

        return await _planRepository.AddWorkoutToPlanAsync(link, userId);
    }

    /// <inheritdoc/>
    public async Task<bool> AddWorkoutsToPlanBatchAsync(Guid planId, List<Guid> workoutIds, Guid userId)
    {
        if (await _planRepository.GetOwnerAsync(planId) != userId) return false;

        foreach (var workoutId in workoutIds)
            await AddWorkoutToPlanAsync(planId, workoutId, userId);
        return true;
    }

    /// <inheritdoc/>
    public async Task<WorkoutPlanResponseDto?> ReplacePlanWorkoutsAsync(Guid planId, List<Guid> workoutIds, Guid userId)
    {
        var plan = await _planRepository.ReplacePlanWorkoutsAsync(planId, userId, workoutIds);
        return plan == null ? null : ToDto(plan);
    }

    /// <inheritdoc/>
    public async Task<bool> RemoveWorkoutFromPlanAsync(Guid planId, Guid workoutId, Guid userId)
    {
        return await _planRepository.RemoveWorkoutFromPlanAsync(planId, workoutId, userId);
    }

    private static WorkoutPlanResponseDto ToDto(WorkoutPlan p) => new()
    {
        Id = p.Id,
        UserId = p.UserId,
        Name = p.Name,
        Description = p.Description,
        StartDate = p.StartDate,
        CreatedAt = p.CreatedAt,
        IsActive = p.IsActive,
        CyclePatternJson = p.CyclePatternJson,
        IsFreeChoice = p.IsFreeChoice,
        DurationDays = p.DurationDays,
        AssignedByTrainer = p.AssignedByTrainerId != null,
        WorkoutIds = [.. p.PlanWorkouts.Select(pw => pw.WorkoutId)],
    };
}
