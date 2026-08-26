using System.ComponentModel.DataAnnotations;

namespace FitTracker.Api.DTOs;

/// <summary>Request payload for creating or updating user settings.</summary>
public class UserSettingsRequestDto
{
    /// <summary>The user's daily calorie target (kcal).</summary>
    [Range(500, 20000)]
    public int DailyCalorieGoal { get; set; } = Models.UserSettings.DefaultDailyCalorieGoal;

    /// <summary>The UI theme preference ("light" or "dark").</summary>
    [Required, RegularExpression("^(light|dark)$")]
    public string ThemeMode { get; set; } = "light";

    /// <summary>The user's display name inside the app.</summary>
    [MaxLength(100)]
    public string Name { get; set; } = string.Empty;

    /// <summary>The user's age in years.</summary>
    [Range(13, 120)]
    public int Age { get; set; } = 30;

    /// <summary>The user's height in centimetres.</summary>
    [Range(50, 272)]
    public int HeightCm { get; set; } = 170;

    /// <summary>The user's biological sex ("male" or "female").</summary>
    [Required, RegularExpression("^(male|female)$")]
    public string Sex { get; set; } = "male";

    /// <summary>Activity level index (maps to Flutter's ActivityLevel enum: sedentary=0 .. extremelyActive=4).</summary>
    [Range(0, 4)]
    public int ActivityLevel { get; set; } = 1;

    /// <summary>Goal type index (maps to Flutter's GoalType enum: weightLoss=0, muscleGain=1, maintenance=2).</summary>
    [Range(0, 2)]
    public int GoalType { get; set; } = 1;

    /// <summary>The user's starting weight in kg.</summary>
    [Range(1, 1000)]
    public double StartingWeight { get; set; } = 80.0;

    /// <summary>The user's target weight in kg.</summary>
    [Range(1, 1000)]
    public double GoalWeight { get; set; } = 70.0;
}
