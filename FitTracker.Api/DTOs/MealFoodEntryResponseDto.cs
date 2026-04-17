namespace FitTracker.Api.DTOs;

/// <summary>Response payload for a food item linked to a meal.</summary>
public class MealFoodEntryResponseDto
{
    /// <summary>The unique identifier of this join record.</summary>
    public Guid Id { get; set; }

    /// <summary>The ID of the parent meal.</summary>
    public Guid MealId { get; set; }

    /// <summary>The client-side ID of the linked food item.</summary>
    public Guid FoodItemId { get; set; }
}
