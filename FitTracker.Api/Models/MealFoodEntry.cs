namespace FitTracker.Api.Models;

/// <summary>Join record linking a meal to an additional food item (many-to-many).</summary>
public class MealFoodEntry
{
    /// <summary>The unique identifier of this join record.</summary>
    public Guid Id { get; set; }

    /// <summary>The ID of the parent meal.</summary>
    public Guid MealId { get; set; }

    /// <summary>
    /// The ID of the food item. Treated as an opaque client-side reference —
    /// no FK enforced because food items may be synced independently.
    /// </summary>
    public Guid FoodItemId { get; set; }

    /// <summary>Navigation property to the parent meal.</summary>
    public Meal Meal { get; set; } = null!;
}
