namespace FitTracker.Api.DTOs;

/// <summary>Request payload for creating or updating a food item.</summary>
public class FoodItemRequestDto
{
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

    /// <summary>Whether to hide this item from the recently-added list.</summary>
    public bool HiddenFromRecent { get; set; } = false;

    /// <summary>JSON-encoded extended nutrient data. Null if not available.</summary>
    public string? ExtendedNutrientsJson { get; set; }
}
