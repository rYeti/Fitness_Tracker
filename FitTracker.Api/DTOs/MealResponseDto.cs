namespace FitTracker.Api.DTOs;

/// <summary>Response payload returned when reading a meal log entry.</summary>
public class MealResponseDto
{
    /// <summary>The unique identifier of this meal entry.</summary>
    public Guid Id { get; set; }

    /// <summary>The date this food was logged.</summary>
    public DateTime Date { get; set; }

    /// <summary>The meal category (e.g. "breakfast", "lunch", "dinner", "snack").</summary>
    public string Category { get; set; } = string.Empty;

    /// <summary>The client-side ID of the food item logged.</summary>
    public Guid FoodItemId { get; set; }

    /// <summary>Food items linked via the many-to-many join.</summary>
    public List<MealFoodEntryResponseDto> FoodEntries { get; set; } = [];
}
