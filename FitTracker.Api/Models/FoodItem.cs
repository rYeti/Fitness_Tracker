namespace FitTracker.Api.Models;

/// <summary>Represents a food definition in the user's food library.</summary>
public class FoodItem
{
    /// <summary>The unique identifier of this food item.</summary>
    public Guid Id { get; set; }

    /// <summary>The ID of the user who owns this food item.</summary>
    public Guid UserId { get; set; }

    /// <summary>The display name of the food.</summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>Calories per serving (kcal).</summary>
    public int Calories { get; set; }

    /// <summary>Protein per serving (g).</summary>
    public int Protein { get; set; }

    /// <summary>Carbohydrates per serving (g).</summary>
    public int Carbs { get; set; }

    /// <summary>Fat per serving (g).</summary>
    public int Fat { get; set; }

    /// <summary>Serving size in grams. Defaults to 100.</summary>
    public int Gramm { get; set; } = 100;

    /// <summary>Whether this item is hidden from the recently-added list.</summary>
    public bool HiddenFromRecent { get; set; } = false;

    /// <summary>JSON-encoded extended nutrient data. Null for custom foods.</summary>
    public string? ExtendedNutrientsJson { get; set; }

    /// <summary>Navigation property to the owning user.</summary>
    public User User { get; set; } = null!;
}
