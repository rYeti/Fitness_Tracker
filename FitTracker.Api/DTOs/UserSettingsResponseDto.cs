namespace FitTracker.Api.DTOs;

/// <summary>Response payload returned when reading user settings.</summary>
public class UserSettingsResponseDto
{
    /// <summary>The unique identifier of this settings record.</summary>
    public Guid Id { get; set; }

    /// <summary>The user's daily calorie target (kcal).</summary>
    public int DailyCalorieGoal { get; set; }

    /// <summary>The UI theme preference ("light" or "dark").</summary>
    public string ThemeMode { get; set; } = string.Empty;

    /// <summary>The user's display name inside the app.</summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>The user's age in years.</summary>
    public int Age { get; set; }

    /// <summary>The user's height in centimetres.</summary>
    public int HeightCm { get; set; }

    /// <summary>The user's biological sex ("male" or "female").</summary>
    public string Sex { get; set; } = string.Empty;

    /// <summary>Activity level index.</summary>
    public int ActivityLevel { get; set; }

    /// <summary>Goal type index.</summary>
    public int GoalType { get; set; }

    /// <summary>The user's starting weight in kg.</summary>
    public double StartingWeight { get; set; }

    /// <summary>The user's target weight in kg.</summary>
    public double GoalWeight { get; set; }
}
