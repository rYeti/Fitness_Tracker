using FitTracker.Api.Nutrition;

namespace FitTracker.Api.DTOs;

/// <summary>Aggregate KPIs for the trainer's whole active roster (Dashboard KPI row).</summary>
public class TrainerDashboardKpisDto
{
    public int ActiveClientCount { get; set; }
    public double AvgAdherencePercent { get; set; }
    public int SessionsThisWeek { get; set; }
    public int AlertCount { get; set; }
}

/// <summary>One roster row for the Dashboard: the relationship plus the training
/// stats the roster actually displays.</summary>
/// <remarks>Separate from <see cref="TrainerClientResponseDto"/> (which is the bare
/// relationship — invite code, timestamps, no training data) because the roster needs
/// adherence and last-session, and computing those for every relationship lookup
/// would be wasteful.</remarks>
public class TrainerRosterEntryDto
{
    public Guid ClientId { get; set; }
    public string ClientName { get; set; } = string.Empty;

    /// <summary>Name of the client's active plan, or null if they have none.</summary>
    public string? ProgramLabel { get; set; }

    /// <summary>Completed / planned sessions over the trailing 4 weeks, 0-100.
    /// Null when nothing was scheduled, which is different from 0% adherence.</summary>
    public double? AdherencePercent { get; set; }

    /// <summary>Date of their most recent completed session, or null if never.</summary>
    public DateTime? LastSessionDate { get; set; }
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

    /// <summary>Raw meal rows, exactly as stored: they carry only food-item <em>ids</em>
    /// (<see cref="MealFoodEntryResponseDto"/>) rather than nutrition values, and a day
    /// can hold more than one row for the same category. Use <see cref="LoggedMeals"/>
    /// for anything the trainer actually sees.</summary>
    public List<MealResponseDto> Meals { get; set; } = [];

    /// <summary>One entry per meal of the day, with the food-item lookup already
    /// resolved so the trainer doesn't need the client's whole food catalogue to
    /// render a meal list. Rows sharing a category are folded into one entry —
    /// see <see cref="Repositories.MealCategory"/> for why more than one exists.</summary>
    public List<LoggedMealDto> LoggedMeals { get; set; } = [];

    /// <summary>Total kcal consumed on <see cref="Date"/>.</summary>
    public int TotalCalories { get; set; }

    /// <summary>Day totals for the macro bar, in grams.</summary>
    public MacroTotalsDto Macros { get; set; } = new();

    public int CalorieGoal { get; set; }
    public List<DailyCalorieTotalDto> SevenDayTrend { get; set; } = [];

    /// <summary>Day totals for every nutrient <see cref="Models.FoodItem.ExtendedNutrientsJson"/>
    /// carries, folded from <see cref="LoggedMeals"/> — never from a second traversal
    /// of <see cref="Meals"/>, which would double-count exactly as calories once did.
    /// Null when <see cref="MicronutrientsLocked"/> is true; also null (as opposed to
    /// a zero-valued object) when nothing logged today reported any micronutrient
    /// data at all — see <see cref="MicronutrientTotalsDto"/>.</summary>
    public MicronutrientTotalsDto? Micronutrients { get; set; }

    /// <summary>True when either the trainer or the client lacks a paid, current
    /// licence — see <see cref="TrainerConsoleService.GetClientNutritionSummaryAsync"/>.
    /// <see cref="Micronutrients"/> and every <see cref="LoggedFoodDto.Micronutrients"/>
    /// are absent from the payload in that case, not merely hidden client-side.</summary>
    public bool MicronutrientsLocked { get; set; }

    /// <summary>The nutrient keys this trainer has pinned for this client (or the
    /// defaults, if they never chose). Keys match <c>NutrientDef.key</c> on the
    /// Flutter side — see lib/core/nutrition/nutrient_defs.dart.</summary>
    public List<string> PinnedNutrients { get; set; } = [];
}

/// <summary>The 21 nutrients <c>ExtendedNutrients</c> carries, in grams — the same
/// unit the value is stored in everywhere. Display-unit conversion (mg, µg) is a
/// client concern; see lib/core/nutrition/nutrient_defs.dart. Every field stays
/// null when nothing reported it — a fold must never turn "not reported" into "0".</summary>
public class MicronutrientTotalsDto
{
    public double? Fiber { get; set; }
    public double? Sugar { get; set; }
    public double? SaturatedFat { get; set; }
    public double? Salt { get; set; }
    public double? Sodium { get; set; }
    public double? VitaminA { get; set; }
    public double? VitaminC { get; set; }
    public double? VitaminD { get; set; }
    public double? VitaminE { get; set; }
    public double? VitaminK { get; set; }
    public double? VitaminB1 { get; set; }
    public double? VitaminB2 { get; set; }
    public double? VitaminB3 { get; set; }
    public double? VitaminB6 { get; set; }
    public double? VitaminB9 { get; set; }
    public double? VitaminB12 { get; set; }
    public double? Calcium { get; set; }
    public double? Iron { get; set; }
    public double? Magnesium { get; set; }
    public double? Potassium { get; set; }
    public double? Zinc { get; set; }

    public static MicronutrientTotalsDto From(ExtendedNutrients n) => new()
    {
        Fiber = n.Fiber,
        Sugar = n.Sugar,
        SaturatedFat = n.SaturatedFat,
        Salt = n.Salt,
        Sodium = n.Sodium,
        VitaminA = n.VitaminA,
        VitaminC = n.VitaminC,
        VitaminD = n.VitaminD,
        VitaminE = n.VitaminE,
        VitaminK = n.VitaminK,
        VitaminB1 = n.VitaminB1,
        VitaminB2 = n.VitaminB2,
        VitaminB3 = n.VitaminB3,
        VitaminB6 = n.VitaminB6,
        VitaminB9 = n.VitaminB9,
        VitaminB12 = n.VitaminB12,
        Calcium = n.Calcium,
        Iron = n.Iron,
        Magnesium = n.Magnesium,
        Potassium = n.Potassium,
        Zinc = n.Zinc,
    };
}

/// <summary>Protein/carbs/fat in grams.</summary>
public class MacroTotalsDto
{
    public int Protein { get; set; }
    public int Carbs { get; set; }
    public int Fat { get; set; }
}

/// <summary>One meal the client logged, totalled across its food entries.</summary>
public class LoggedMealDto
{
    public Guid MealId { get; set; }

    /// <summary>"breakfast" | "lunch" | "dinner" | "snack", as authored by the client app.</summary>
    public string Category { get; set; } = string.Empty;

    /// <summary>Food names in this meal, for the meal row's subtitle.</summary>
    public List<string> FoodNames { get; set; } = [];

    /// <summary>Every food in this meal with its own nutrition, for the meal
    /// detail view. Same order the client logged them in, and repeats when the
    /// same food was logged twice.</summary>
    public List<LoggedFoodDto> Foods { get; set; } = [];

    public int Calories { get; set; }
    public MacroTotalsDto Macros { get; set; } = new();

    /// <summary>This meal's own micronutrient totals — the meal detail screen's
    /// rail sums one meal, not the day. Null when locked (see
    /// <see cref="ClientNutritionSummaryDto.MicronutrientsLocked"/>) or when none
    /// of this meal's foods reported any.</summary>
    public MicronutrientTotalsDto? Micronutrients { get; set; }
}

/// <summary>One food inside a logged meal, resolved against the client's food
/// catalogue. The trainer has no route to that catalogue, so the nutrition
/// values travel with the name rather than as an id to look up.</summary>
public class LoggedFoodDto
{
    public Guid FoodItemId { get; set; }

    public string Name { get; set; } = string.Empty;

    /// <summary>Serving size in grams. 0 when the client's food item never
    /// recorded one.</summary>
    public int Grams { get; set; }

    public int Calories { get; set; }
    public MacroTotalsDto Macros { get; set; } = new();

    /// <summary>Parsed from this food's own <see cref="Models.FoodItem.ExtendedNutrientsJson"/>.
    /// Null when locked, when the food never recorded any, or when its stored
    /// blob doesn't parse.</summary>
    public MicronutrientTotalsDto? Micronutrients { get; set; }
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

/// <summary>Outcome of a trainer replacing their pinned-nutrients selection
/// for a client — see <see cref="Services.Interfaces.ITrainerConsoleService.SetClientNutrientPinsAsync"/>.</summary>
public enum SetNutrientPinsStatus
{
    Ok,

    /// <summary>The caller isn't this client's active trainer — 404 to the
    /// caller, matching every other console endpoint's not-found-rather-than-
    /// forbidden convention (see TrainerConsoleController).</summary>
    NotAuthorized,

    /// <summary>One or more keys didn't match <see cref="Nutrition.NutrientKeys.All"/>.</summary>
    InvalidNutrientKey,
}

public class SetNutrientPinsResult
{
    public SetNutrientPinsStatus Status { get; set; }

    /// <summary>The saved set, in order — echoed back so the console doesn't
    /// need a second read to confirm what was actually stored.</summary>
    public List<string> PinnedNutrients { get; set; } = [];
}
