namespace FitTracker.Api.DTOs;

/// <summary>Aggregate KPIs for the trainer's whole active roster (Dashboard KPI row).</summary>
public class TrainerDashboardKpisDto
{
    public int ActiveClientCount { get; set; }
    public double AvgAdherencePercent { get; set; }
    public int SessionsThisWeek { get; set; }
    public int AlertCount { get; set; }
}

/// <summary>One client's current plan + attendance + strength progression, for Client Detail.</summary>
public class ClientWorkoutSummaryDto
{
    public WorkoutPlanResponseDto? CurrentPlan { get; set; }
    public List<AttendanceWeekDto> Attendance { get; set; } = [];
    public List<StrengthProgressionDto> StrengthProgression { get; set; } = [];
}

public class AttendanceWeekDto
{
    public DateTime WeekStart { get; set; }
    public int PlannedSessions { get; set; }
    public int CompletedSessions { get; set; }
}

public class StrengthProgressionDto
{
    public Guid ExerciseId { get; set; }
    public string ExerciseName { get; set; } = string.Empty;
    public double CurrentWeight { get; set; }
    public double DeltaFromPrevious { get; set; }
}

/// <summary>One day's fully-logged workout (every exercise/set), for Client Detail's day-switcher.</summary>
public class ClientWorkoutHistoryDto
{
    public DateTime Date { get; set; }
    public ScheduledWorkoutResponseDto? ScheduledWorkout { get; set; }
}

/// <summary>One day's nutrition + a 7-day trend ending on that day, for Nutrition / Client Detail.</summary>
public class ClientNutritionSummaryDto
{
    public DateTime Date { get; set; }
    public List<MealResponseDto> Meals { get; set; } = [];
    public int CalorieGoal { get; set; }
    public List<DailyCalorieTotalDto> SevenDayTrend { get; set; } = [];
}

public class DailyCalorieTotalDto
{
    public DateTime Date { get; set; }
    public int TotalCalories { get; set; }
    public int Goal { get; set; }
}

/// <summary>How a scheduled session turned out. Derived server-side from the
/// scheduled workout's flags — see TrainerConsoleService.DeriveStatus for the rule.</summary>
public enum SessionStatusDto
{
    /// <summary>Marked complete by the client.</summary>
    Done,

    /// <summary>Started and partially logged, but never marked complete.</summary>
    Partial,

    /// <summary>Explicitly skipped, or past-dated with nothing logged at all.</summary>
    Missed
}

/// <summary>What was programmed for one exercise, for the prescribed-vs-logged
/// comparison in Session Review.</summary>
/// <remarks>Deliberately structured rather than a pre-formatted string ("3 × 8 @ 82.5 kg"):
/// the clients are localised (see <c>ExerciseResponseDto.NameDe</c> and the Flutter
/// app's l10n), so number/unit formatting belongs on the client side.
/// <para>Note there is no target <em>weight</em> here because the schema has none —
/// <see cref="WorkoutSetTemplateResponseDto"/> only carries <c>TargetReps</c>. The
/// design mock shows "@ 82.5 kg" against each prescription; backing that needs a new
/// column on the set template, not a computation here.</para></remarks>
public class PrescribedSetsDto
{
    /// <summary>How many sets were programmed.</summary>
    public int SetCount { get; set; }

    /// <summary>Target reps per set, in set order, exactly as authored — each entry is
    /// either a single value ("10") or a range ("8-12"). One entry per programmed set, so
    /// a pyramid reads ["12", "10", "8"]; a uniform prescription repeats ("8", "8", "8")
    /// and the client can collapse it to "3 × 8" for display.</summary>
    public List<string> TargetRepsPerSet { get; set; } = [];
}

/// <summary>One set the client actually recorded.</summary>
public class SessionSetLogDto
{
    public int SetNumber { get; set; }
    public int? Reps { get; set; }
    public double? Weight { get; set; }
    public string? WeightUnit { get; set; }
    public int? Rpe { get; set; }

    /// <summary>Whether <see cref="Reps"/> met the low end of the prescribed target.
    /// Defaults to <c>true</c> when there's no parseable target, so an unprogrammed
    /// exercise doesn't render as a miss.</summary>
    public bool HitTarget { get; set; }
}

/// <summary>One exercise within a logged session: what was prescribed, and every set
/// actually recorded against it.</summary>
public class SessionExerciseLogDto
{
    public Guid WorkoutExerciseId { get; set; }
    public string ExerciseName { get; set; } = "";
    public PrescribedSetsDto? Prescribed { get; set; }

    /// <summary>Programmed but nothing logged against it.</summary>
    public bool Skipped { get; set; }

    /// <summary>A set here beat this client's best-ever weight on this exercise, counting
    /// only strictly-earlier sessions.</summary>
    public bool IsPr { get; set; }

    public List<SessionSetLogDto> Sets { get; set; } = [];
}

/// <summary>One completed/attempted session for the Session Review screen — the history
/// row and its full detail in one payload, so opening a row costs no extra round trip.</summary>
/// <remarks>No duration field: <see cref="ScheduledWorkoutResponseDto"/> has no start/end
/// timestamps, and <c>WorkoutResponseDto.EstimatedDurationMinutes</c> is the template's
/// estimate, not what the client actually spent — surfacing it as logged duration would be
/// wrong. Real duration needs new columns on ScheduledWorkout.</remarks>
public class ClientSessionSummaryDto
{
    public Guid ScheduledWorkoutId { get; set; }
    public DateTime Date { get; set; }
    public string WorkoutName { get; set; } = "";
    public SessionStatusDto Status { get; set; }

    /// <summary>True when any exercise in this session set a new best weight.</summary>
    public bool IsPr { get; set; }

    /// <summary>Sum of reps × weight over every completed set, in the sets' own weight
    /// units (the schema doesn't normalise units, so mixed-unit sessions sum naively).</summary>
    public double TotalVolume { get; set; }

    /// <summary>Mean RPE over completed sets that recorded one, or null if none did.</summary>
    public double? AvgRpe { get; set; }

    /// <summary>The client's own note on the session (<c>ScheduledWorkout.Notes</c>).</summary>
    public string? ClientNote { get; set; }

    public List<SessionExerciseLogDto> Exercises { get; set; } = [];
}
