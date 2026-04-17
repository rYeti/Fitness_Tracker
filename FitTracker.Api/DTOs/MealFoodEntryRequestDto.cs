namespace FitTracker.Api.DTOs;

/// <summary>Request payload for adding a food item to a meal.</summary>
public class MealFoodEntryRequestDto
{
    /// <summary>The client-side ID of the food item to link.</summary>
    public Guid FoodItemId { get; set; }
}
