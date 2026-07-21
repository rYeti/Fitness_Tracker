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
