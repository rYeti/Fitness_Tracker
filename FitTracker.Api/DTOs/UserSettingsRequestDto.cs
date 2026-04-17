namespace FitTracker.Api.DTOs;

/// <summary>Request payload for creating or updating user settings.</summary>
public class UserSettingsRequestDto
{
    /// <summary>The user's daily calorie target (kcal).</summary>
    public int DailyCalorieGoal { get; set; } = 2000;

    /// <summary>The UI theme preference ("light" or "dark").</summary>
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
}
