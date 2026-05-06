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
            .Where(p => p.UserId == userId)
            .Include(p => p.PlanWorkouts)
            .ToListAsync();
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
    public async Task<bool> DeletePlanAsync(Guid id, Guid userId)
    {
        var plan = await _context.WorkoutPlans.FirstOrDefaultAsync(p => p.Id == id && p.UserId == userId);
        if (plan == null) return false;

        _context.WorkoutPlans.Remove(plan);
        await _context.SaveChangesAsync();
        return true;
    }

    /// <inheritdoc/>
    public async Task AddWorkoutToPlanAsync(WorkoutPlanWorkout link)
    {
        _context.WorkoutPlanWorkouts.Add(link);
        await _context.SaveChangesAsync();
    }

    /// <inheritdoc/>
    public async Task<bool> RemoveWorkoutFromPlanAsync(Guid planId, Guid workoutId)
    {
        var link = await _context.WorkoutPlanWorkouts
            .FirstOrDefaultAsync(l => l.PlanId == planId && l.WorkoutId == workoutId);
        if (link == null) return false;

        _context.WorkoutPlanWorkouts.Remove(link);
        await _context.SaveChangesAsync();
        return true;
    }
}
