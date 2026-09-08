using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

/// <summary>Implementation of <see cref="IWorkoutPlanService"/>.</summary>
public class WorkoutPlanService : IWorkoutPlanService
{
    private readonly IWorkoutPlanRepository _planRepository;
    private readonly IRevenueCatSubscriptionRepository? _revenueCat;
    private readonly ITrainerClientService? _trainerClients;

    /// <summary>Initialises a new instance of <see cref="WorkoutPlanService"/>.</summary>
    /// <param name="planRepository">The workout plan repository.</param>
    /// <param name="revenueCat">The caller's own app-store entitlement. Optional so existing
    /// tests that only exercise plan CRUD can keep passing a single argument; a null here
    /// means "no entitlement from this source", never "allow".</param>
    /// <param name="trainerClients">Licence-derived Pro. Optional on the same terms.</param>
    public WorkoutPlanService(
        IWorkoutPlanRepository planRepository,
        IRevenueCatSubscriptionRepository? revenueCat = null,
        ITrainerClientService? trainerClients = null)
    {
        _planRepository = planRepository;
        _revenueCat = revenueCat;
        _trainerClients = trainerClients;
    }

    /// <summary>Whether <paramref name="userId"/> may set or read their own deload weeks.</summary>
    /// <remarks>
    /// Checks <em>both</em> premium sources explicitly, at this one call site, and does not
    /// introduce a shared "is premium" helper.
    /// <para><c>docs/revenuecat-self-managed-pins.md</c> argues against merging the two into
    /// one method, because every gate already built on <c>DerivesProAsync</c> would silently
    /// start accepting RevenueCat entitlement as well. That concern is about a
    /// platform-wide widening, and it stands. But the client's own
    /// <c>AccessProvider.hasPremiumAccess</c> is <c>_isPremium || _proFromLicence</c>, so
    /// checking only one source here would unlock the UI for a derived-Pro user and then
    /// refuse their write — the client/server disagreement
    /// <c>docs/trainer-console-micronutrients.md</c> calls "the defect". Two explicit calls
    /// at one call site is the narrow version of the fix; do not "simplify" it into one.</para>
    /// </remarks>
    private async Task<bool> IsEntitledAsync(Guid userId)
    {
        if (_revenueCat != null && await _revenueCat.IsEntitledAsync(userId)) return true;
        if (_trainerClients != null && await _trainerClients.DerivesProAsync(userId)) return true;
        return false;
    }

    /// <inheritdoc/>
    public async Task<List<WorkoutPlanResponseDto>> GetUserPlansAsync(Guid userId)
    {
        var plans = await _planRepository.GetUserPlansAsync(userId);
        // Resolved once for the whole list rather than per plan: it is the same answer for
        // every row, and asking per row turns one read into N.
        var entitled = await IsEntitledAsync(userId);
        return [.. plans.Select(p => ToDto(p, entitled))];
    }

    /// <inheritdoc/>
    public Task<Dictionary<Guid, string>> GetActivePlanNamesAsync(IReadOnlyCollection<Guid> userIds) =>
        _planRepository.GetActivePlanNamesAsync(userIds);

    /// <inheritdoc/>
    public async Task<WorkoutPlanResponseDto?> GetPlanByIdAsync(Guid id, Guid userId)
    {
        var plan = await _planRepository.GetPlanByIdAsync(id, userId);
        if (plan == null) return null;
        return ToDto(plan, await IsEntitledAsync(userId));
    }

    /// <inheritdoc/>
    public async Task<SetDeloadWeeksResult> SetDeloadWeeksAsync(
        Guid planId, Guid userId, IEnumerable<DeloadWeek> weeks, bool actingAsTrainer = false)
    {
        var plan = await _planRepository.GetPlanByIdAsync(planId, userId);
        if (plan == null) return new SetDeloadWeeksResult { Status = SetDeloadWeeksStatus.PlanNotFound };

        // Ownership before entitlement, deliberately. A client on a trainer-assigned plan
        // must be told their coach manages this, not that they need to buy something —
        // buying would not give them the pen. Keyed on the plan, not on "has a trainer": a
        // client can have a trainer and still run a programme they wrote themselves, and on
        // that programme the deloads are their own.
        if (!actingAsTrainer && plan.AssignedByTrainerId != null)
        {
            return new SetDeloadWeeksResult { Status = SetDeloadWeeksStatus.AssignedByTrainer };
        }

        if (!actingAsTrainer && !await IsEntitledAsync(userId))
        {
            return new SetDeloadWeeksResult { Status = SetDeloadWeeksStatus.NotEntitled };
        }

        // Rejects rather than normalising. Silently dropping a bad week would save a
        // schedule the caller never asked for and report it as success.
        var requested = weeks.ToList();
        var durationWeeks = plan.DurationDays == null
            ? (int?)null
            : PlanWeeks.WeeksIn(plan.DurationDays.Value);
        if (!DeloadSchedule.AllValid(requested, durationWeeks))
        {
            return new SetDeloadWeeksResult { Status = SetDeloadWeeksStatus.InvalidWeek };
        }

        var normalised = DeloadSchedule.Normalise(requested);
        await _planRepository.SetDeloadWeeksAsync(planId, userId, DeloadSchedule.Serialise(normalised));

        return new SetDeloadWeeksResult
        {
            Status = SetDeloadWeeksStatus.Ok,
            DeloadWeeks = normalised,
        };
    }

    /// <inheritdoc/>
    public async Task<WorkoutPlanResponseDto> CreatePlanAsync(WorkoutPlanRequestDto dto, Guid userId, Guid? assignedByTrainerId = null)
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
            AssignedByTrainerId = assignedByTrainerId,
        };

        var created = await _planRepository.CreatePlanAsync(plan);
        // A new plan has no deload weeks, but the entitlement is still resolved rather than
        // assumed: the field's presence has to mean the same thing on every response, or a
        // client learns to read "absent" as "none" from the one place it is safe to.
        return ToDto(created, await IsEntitledAsync(userId));
    }

    /// <inheritdoc/>
    public async Task<WorkoutPlanResponseDto?> UpdatePlanAsync(Guid id, Guid userId, WorkoutPlanRequestDto dto)
    {
        var updated = await _planRepository.UpdatePlanAsync(id, userId, dto);
        if (updated == null) return null;
        // The plan document carries no deload weeks (§5b), so this echo reports whatever the
        // stored set already was — an unchanged value, not a cleared one. That is the point.
        return ToDto(updated, await IsEntitledAsync(userId));
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

    /// <summary>Maps a plan to its DTO, honouring the deload-weeks entitlement rule.</summary>
    /// <param name="p">The plan.</param>
    /// <param name="entitled">Whether the reader holds premium from either source.</param>
    /// <remarks>
    /// Deload weeks are <em>omitted from the payload</em> rather than emptied when the reader
    /// isn't entitled, per <c>docs/trainer-console-micronutrients.md</c>'s rule that a locked
    /// value is absent, not merely hidden by the client. Null and empty mean different
    /// things here and readers depend on the difference: absent is "not provided", empty is
    /// "there are none".
    /// <para>A trainer-assigned plan always sends them, whatever the client's own
    /// entitlement. A lapsed licence must never hide a programme's own recovery week — the
    /// client did not do anything wrong, and they are still training against it.</para>
    /// </remarks>
    private static WorkoutPlanResponseDto ToDto(WorkoutPlan p, bool entitled) => new()
    {
        DeloadWeeks = entitled || p.AssignedByTrainerId != null
            ? [.. DeloadSchedule.Parse(p.DeloadWeeksJson)]
            : null,
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
