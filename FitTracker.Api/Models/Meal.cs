namespace FitTracker.Api.Models;

/// <summary>Represents a food log entry — one food item logged in a meal category on a given date.</summary>
public class Meal
{
    /// <summary>The unique identifier of this meal entry.</summary>
    public Guid Id { get; set; }

    /// <summary>The ID of the user who owns this entry.</summary>
    public Guid UserId { get; set; }

    /// <summary>The date this food was logged.</summary>
    public DateTime Date { get; set; }

    /// <summary>The meal category (e.g. "breakfast", "lunch", "dinner", "snack").</summary>
    public string Category { get; set; } = string.Empty;

    /// <summary>
    /// The ID of the food item logged. Treated as an opaque client-side reference —
    /// no FK enforced because food items may be synced independently.
    /// </summary>
    public Guid FoodItemId { get; set; }

    /// <summary>Navigation property to the owning user.</summary>
    public User User { get; set; } = null!;

    /// <summary>The food items linked to this meal via the many-to-many join.</summary>
    public ICollection<MealFoodEntry> FoodEntries { get; set; } = new List<MealFoodEntry>();
}
