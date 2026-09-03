using FitTracker.Api.Data;
using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Repositories;

/// <summary>EF Core implementation of <see cref="IWorkoutPlanRepository"/>.</summary>
public class WorkoutPlanRepository : IWorkoutPlanRepository
{
    private readonly AppDbContext _context;

    /// <summary>Initialises a new instance of <see cref="WorkoutPlanRepository"/>.</summary>
    /// <param name="context">The database context.</param>
    public WorkoutPlanRepository(AppDbContext context)
    {
        _context = context;
    }

    /// <inheritdoc/>
    public async Task<List<WorkoutPlan>> GetUserPlansAsync(Guid userId)
    {
        return await _context.WorkoutPlans
            .AsNoTracking()
            .Where(p => p.UserId == userId)
            .Include(p => p.PlanWorkouts)
            .ToListAsync();
    }

    /// <inheritdoc/>
    public async Task<Dictionary<Guid, string>> GetActivePlanNamesAsync(IReadOnlyCollection<Guid> userIds)
    {
        if (userIds.Count == 0) return [];

        var ids = userIds.ToList();
        var rows = await _context.WorkoutPlans
            .AsNoTracking()
            .Where(p => ids.Contains(p.UserId) && p.IsActive)
            .OrderByDescending(p => p.CreatedAt)
            .Select(p => new { p.UserId, p.Name })
            .ToListAsync();

        // Folded here rather than in SQL: First() inside a GroupBy projection doesn't
        // translate, and there are only ever a handful of active plans per user.
        return rows
            .GroupBy(r => r.UserId)
            .ToDictionary(g => g.Key, g => g.First().Name);
    }

    /// <inheritdoc/>
    public async Task<WorkoutPlan?> GetPlanByIdAsync(Guid id, Guid userId)
    {
        return await _context.WorkoutPlans
            .Where(p => p.Id == id && p.UserId == userId)
            .Include(p => p.PlanWorkouts)
            .FirstOrDefaultAsync();
    }

    /// <inheritdoc/>
    public async Task<WorkoutPlan> CreatePlanAsync(WorkoutPlan plan)
    {
        _context.WorkoutPlans.Add(plan);
        await _context.SaveChangesAsync();
        return plan;
    }

    /// <inheritdoc/>
    public async Task<WorkoutPlan?> UpdatePlanAsync(Guid id, Guid userId, WorkoutPlanRequestDto dto)
    {
        var plan = await _context.WorkoutPlans.FirstOrDefaultAsync(p => p.Id == id && p.UserId == userId);
        if (plan == null) return null;

        plan.Name = dto.Name;
        plan.Description = dto.Description;
        plan.StartDate = dto.StartDate;
        plan.CyclePatternJson = dto.CyclePatternJson;
        plan.IsFreeChoice = dto.IsFreeChoice;
        plan.DurationDays = dto.DurationDays;

        await _context.SaveChangesAsync();
        return plan;
    }

    /// <inheritdoc/>
    public async Task<PlanDeleteResult> DeletePlanAsync(Guid id, Guid userId, bool actingAsTrainer = false)
    {
        var plan = await _context.WorkoutPlans.FirstOrDefaultAsync(p => p.Id == id && p.UserId == userId);
        if (plan == null) return PlanDeleteResult.NotFound;

        // See WorkoutRepository.DeleteWorkoutAsync for the same check one level down.
        if (!actingAsTrainer && plan.AssignedByTrainerId != null)
        {
            return PlanDeleteResult.AssignedByTrainer;
        }

        _context.WorkoutPlans.Remove(plan);
        await _context.SaveChangesAsync();
        return PlanDeleteResult.Deleted;
    }

    /// <inheritdoc/>
    public async Task<bool> AddWorkoutToPlanAsync(WorkoutPlanWorkout link, Guid userId)
    {
        var ownsPlan = await _context.WorkoutPlans.AnyAsync(p => p.Id == link.PlanId && p.UserId == userId);
        if (!ownsPlan) return false;

        var ownsWorkout = await _context.Workouts.AnyAsync(w => w.Id == link.WorkoutId && w.UserId == userId);
        if (!ownsWorkout) return false;

        _context.WorkoutPlanWorkouts.Add(link);
        await _context.SaveChangesAsync();
        return true;
    }

    /// <inheritdoc/>
    public async Task<bool> RemoveWorkoutFromPlanAsync(Guid planId, Guid workoutId, Guid userId)
    {
        var link = await _context.WorkoutPlanWorkouts
            .FirstOrDefaultAsync(l => l.PlanId == planId && l.WorkoutId == workoutId && l.WorkoutPlan.UserId == userId);
        if (link == null) return false;

        _context.WorkoutPlanWorkouts.Remove(link);
        await _context.SaveChangesAsync();
        return true;
    }
}
