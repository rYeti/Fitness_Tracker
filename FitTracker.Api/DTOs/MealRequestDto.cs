namespace FitTracker.Api.DTOs;

/// <summary>Request payload for creating or updating a meal log entry.</summary>
public class MealRequestDto
{
    /// <summary>The date this food was logged.</summary>
    public DateTime Date { get; set; }

    /// <summary>The meal category (e.g. "breakfast", "lunch", "dinner", "snack").</summary>
    public string Category { get; set; } = string.Empty;

    /// <summary>The client-side ID of the food item being logged.</summary>
    public Guid FoodItemId { get; set; }
}
