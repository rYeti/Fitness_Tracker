namespace FitTracker.Api.Repositories;

/// <summary>Per-client session counts for the Trainer Console dashboard, aggregated in SQL.</summary>
/// <remarks>
/// Both the roster's trailing-28-day adherence and the KPI row's current-week totals come
/// from one grouped query, because the week window sits inside the 28-day window. See
/// <see cref="Interfaces.IScheduledWorkoutRepository.GetClientTrainingStatsAsync"/>.
///
/// A client with no sessions in the window has no row here at all. That is deliberate and
/// load-bearing: the roster reports <c>null</c> adherence for such a client, which means
/// "no data" and is not the same as 0%.
/// </remarks>
public readonly record struct ClientTrainingStats(
    Guid ClientId,
    int PlannedInWindow,
    int CompletedInWindow,
    int PlannedThisWeek,
    int CompletedThisWeek);
