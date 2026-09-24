namespace FitTracker.Api.DTOs;

/// <summary>One food in a meal, as <c>PUT api/Meal/{id}/foods</c> takes the meal's whole list.</summary>
public class MealFoodEntryRequestDto
{
    /// <summary>
    /// The id the app minted for this entry. The replace keeps it; absent, the server
    /// mints one. An id that names an entry in someone else's meal is refused with 409.
    /// </summary>
    public Guid? Id { get; set; }

    /// <summary>The client-side ID of the food item to link.</summary>
    public Guid FoodItemId { get; set; }
}
