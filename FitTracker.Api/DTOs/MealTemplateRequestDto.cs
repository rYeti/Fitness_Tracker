namespace FitTracker.Api.DTOs;

/// <summary>Request payload for creating or replacing a meal template.</summary>
public class MealTemplateRequestDto
{
    /// <summary>The display name of the template.</summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>Optional description of the template.</summary>
    public string? Description { get; set; }

    /// <summary>Meal category (e.g. Breakfast, Lunch, Dinner, Snack).</summary>
    public string Category { get; set; } = string.Empty;

    /// <summary>The food items that make up this template.</summary>
    public List<MealTemplateItemRequestDto> Items { get; set; } = [];
}
