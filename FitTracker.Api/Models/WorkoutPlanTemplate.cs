namespace FitTracker.Api.Models;

/// <summary>A global, reusable workout-plan template (e.g. "Push / Pull / Legs")
/// a trainer can start a new client plan from. Not owned by any user — seeded
/// system data, unlike the per-user MealTemplate.</summary>
public class WorkoutPlanTemplate
{
    public Guid Id { get; set; }

    /// <summary>Display name, e.g. "Push / Pull / Legs".</summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>Short meta line, e.g. "4 days · Hypertrophy".</summary>
    public string Description { get; set; } = string.Empty;

    /// <summary>Material Symbols icon name, e.g. "fitness_center".</summary>
    public string Icon { get; set; } = string.Empty;

    /// <summary>Days per week, e.g. 4.</summary>
    public int DaysPerWeek { get; set; }

    // TODO: how the template's actual days/exercises are represented (a
    // fixed JSON blob? a normalized WorkoutPlanTemplateDay/Exercise table?)
    // is an open design question — needs a decision before the "start from
    // template" flow can create a real WorkoutPlan from this row.
}
