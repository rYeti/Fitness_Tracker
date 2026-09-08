using FitTracker.Api.Models;

namespace FitTracker.Api.DTOs;

/// <summary>Why a write to a plan's deload weeks did or didn't go through.</summary>
/// <remarks>
/// Modelled on <see cref="SetMyNutrientPinsStatus"/>, and separate from it for the same
/// reason that one is separate from its trainer-facing sibling: the failure modes differ.
/// <para>The distinction that matters most is <see cref="AssignedByTrainer"/> versus
/// <see cref="NotEntitled"/>. "Your coach manages this" and "you need Premium" point the
/// user at two completely different next steps, and collapsing them into one refusal leaves
/// the app unable to say which applies.</para>
/// </remarks>
public enum SetDeloadWeeksStatus
{
    Ok,

    /// <summary>No such plan belongs to the caller.</summary>
    PlanNotFound,

    /// <summary>A trainer assigned this plan, so its deload weeks are theirs to set, not the
    /// client's. Keyed on the plan rather than on "has a trainer": a client can legitimately
    /// have a trainer <em>and</em> run a programme they wrote themselves, and on that
    /// programme the deloads are their own.</summary>
    AssignedByTrainer,

    /// <summary>The caller holds no premium entitlement from either source.</summary>
    NotEntitled,

    /// <summary>A week outside <c>1..durationWeeks</c>, or a volume outside 10–90.</summary>
    InvalidWeek,
}

/// <summary>Outcome of a deload-weeks write, echoing the saved set on success.</summary>
public class SetDeloadWeeksResult
{
    public SetDeloadWeeksStatus Status { get; set; }

    /// <summary>The saved set, sorted by week — echoed back so the caller doesn't need a
    /// second read to confirm what was actually stored.</summary>
    public IReadOnlyList<DeloadWeek> DeloadWeeks { get; set; } = [];
}
