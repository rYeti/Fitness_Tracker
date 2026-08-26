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
    public async Task<WorkoutPlanResponseDto> CreatePlanAsync(WorkoutPlanRequestDto dto, Guid userId)
    {
        var plan = new WorkoutPlan
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Name = dto.Name,
            Description = dto.Description,
            StartDate = dto.StartDate,
            CreatedAt = DateTime.UtcNow,
            IsActive = true,
            CyclePatternJson = dto.CyclePatternJson,
            IsFreeChoice = dto.IsFreeChoice,
            DurationDays = dto.DurationDays,
        };

        var created = await _planRepository.CreatePlanAsync(plan);
        return ToDto(created);
    }

    /// <inheritdoc/>
    public async Task<WorkoutPlanResponseDto?> UpdatePlanAsync(Guid id, Guid userId, WorkoutPlanRequestDto dto)
    {
        var updated = await _planRepository.UpdatePlanAsync(id, userId, dto);
        return updated == null ? null : ToDto(updated);
    }

    /// <inheritdoc/>
    public async Task<bool> DeletePlanAsync(Guid id, Guid userId)
    {
        return await _planRepository.DeletePlanAsync(id, userId);
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
    public async Task AddWorkoutsToPlanBatchAsync(Guid planId, List<Guid> workoutIds, Guid userId)
    {
        foreach (var workoutId in workoutIds)
            await AddWorkoutToPlanAsync(planId, workoutId, userId);
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
        WorkoutIds = [.. p.PlanWorkouts.Select(pw => pw.WorkoutId)],
    };
}
