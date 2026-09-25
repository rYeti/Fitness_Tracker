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
    public async Task<List<WorkoutPlan>> GetUserPlansAsync(Guid userId, DateTime? changedSince = null)
    {
        return await _context.WorkoutPlans
            .AsNoTracking()
            .Where(p => p.UserId == userId)
            .ChangedSince(changedSince)
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
        await _context.SaveNewAsync();
        return plan;
    }

    /// <inheritdoc/>
    public async Task<Guid?> GetOwnerAsync(Guid id) =>
        (await _context.WorkoutPlans.AsNoTracking()
            .Where(p => p.Id == id)
            .Select(p => new { p.UserId })
            .FirstOrDefaultAsync())?.UserId;

    /// <inheritdoc/>
    public async Task<WorkoutPlan?> ReplacePlanWorkoutsAsync(Guid planId, Guid userId, IReadOnlyCollection<Guid> workoutIds)
    {
        var plan = await _context.WorkoutPlans
            .Include(p => p.PlanWorkouts)
            .FirstOrDefaultAsync(p => p.Id == planId && p.UserId == userId);
        if (plan == null) return null;

        var wanted = workoutIds.Distinct().ToList();
        var linkable = (await _context.Workouts
                .Where(w => wanted.Contains(w.Id) && w.UserId == userId)
                .Select(w => w.Id)
                .ToListAsync())
            .ToHashSet();

        // The list is a set of workouts, so a plan holds one link per workout. Keeping every
        // link to a wanted workout was not enough: the batch this replaced stored a link again
        // each time it was sent the same one, so plans already hold twins, and a replace that
        // kept them left the Trainer Console listing the workout twice. The first link to each
        // workout stays; the others go with the links to workouts no longer wanted.
        var linked = new HashSet<Guid>();
        foreach (var link in plan.PlanWorkouts.ToList())
        {
            if (linkable.Contains(link.WorkoutId) && linked.Add(link.WorkoutId)) continue;
            plan.PlanWorkouts.Remove(link);
            _context.WorkoutPlanWorkouts.Remove(link);
        }

        foreach (var workoutId in wanted.Where(id => linkable.Contains(id) && !linked.Contains(id)))
        {
            // Through the DbSet, not the navigation: a row reached only through a navigation
            // with its key already set is taken for an existing one and saved as an UPDATE.
            _context.WorkoutPlanWorkouts.Add(new WorkoutPlanWorkout { Id = Guid.NewGuid(), PlanId = planId, WorkoutId = workoutId });
        }

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

        // The database detaches the plan's sessions itself (ON DELETE SET NULL), out of
        // sight of the change tracking the sync feed reads. They changed, so they are
        // marked here, in the same transaction as the delete that changes them — by
        // predicate, immediately before it, since a list of their ids read first would miss
        // a session scheduled under the plan in between.
        await using var transaction = _context.Database.CurrentTransaction == null
            ? await _context.Database.BeginTransactionAsync()
            : null;
        await _context.TouchWhereAsync<ScheduledWorkout>(sw => sw.WorkoutPlanId == id);

        _context.WorkoutPlans.Remove(plan);
        await _context.SaveChangesAsync();
        if (transaction != null) await transaction.CommitAsync();
        return PlanDeleteResult.Deleted;
    }

    /// <inheritdoc/>
    public async Task<bool> AddWorkoutToPlanAsync(WorkoutPlanWorkout link, Guid userId)
    {
        var ownsPlan = await _context.WorkoutPlans.AnyAsync(p => p.Id == link.PlanId && p.UserId == userId);
        if (!ownsPlan) return false;

        var ownsWorkout = await _context.Workouts.AnyAsync(w => w.Id == link.WorkoutId && w.UserId == userId);
        if (!ownsWorkout) return false;

        // Adding a workout a plan already holds adds nothing. The batch a shipped app sends
        // is "every link I haven't heard back about", so a retry after a lost response
        // posted the same links again — and each one was stored again.
        var alreadyLinked = await _context.WorkoutPlanWorkouts
            .AnyAsync(l => l.PlanId == link.PlanId && l.WorkoutId == link.WorkoutId);
        if (alreadyLinked) return true;

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
