namespace FitTracker.Api.Models;

/// <summary>Stores app-wide settings and fitness profile for a single user (one row per user).</summary>
public class UserSettings
{
    /// <summary>The unique identifier of this settings record.</summary>
    public Guid Id { get; set; }

    /// <summary>The ID of the user these settings belong to.</summary>
    public Guid UserId { get; set; }

    /// <summary>The daily calorie target assumed for a user who has never saved
    /// settings. Named rather than repeated because it has to agree with the
    /// Flutter client's own default (<c>food_tables.dart</c>): when the two
    /// disagreed, a client saw "1733 / 2000 kcal" while their trainer saw
    /// "Target 0 kcal" for the same day.</summary>
    public const int DefaultDailyCalorieGoal = 2000;

    /// <summary>The user's daily calorie target (kcal).</summary>
    public int DailyCalorieGoal { get; set; } = DefaultDailyCalorieGoal;

    /// <summary>The UI theme preference ("light" or "dark"). Defaults to "light".</summary>
    public string ThemeMode { get; set; } = "light";

    /// <summary>The user's display name inside the app.</summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>The user's age in years.</summary>
    public int Age { get; set; } = 30;

    /// <summary>The user's height in centimetres.</summary>
    public int HeightCm { get; set; } = 170;

    /// <summary>The user's biological sex ("male" or "female").</summary>
    public string Sex { get; set; } = "male";

    /// <summary>Activity level index (maps to Flutter's ActivityLevel enum).</summary>
    public int ActivityLevel { get; set; } = 1;

    /// <summary>Goal type index (maps to Flutter's GoalType enum).</summary>
    public int GoalType { get; set; } = 1;

    /// <summary>The user's starting weight in kg.</summary>
    public double StartingWeight { get; set; } = 80.0;

    /// <summary>The user's target weight in kg.</summary>
    public double GoalWeight { get; set; } = 70.0;

    /// <summary>Navigation property to the owning user.</summary>
    public User User { get; set; } = null!;
}
