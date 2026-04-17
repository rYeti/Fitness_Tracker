namespace FitTracker.Api.DTOs;

/// <summary>Response payload returned when reading a food item.</summary>
public class FoodItemResponseDto
{
    /// <summary>The unique identifier of the food item.</summary>
    public Guid Id { get; set; }

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

    /// <summary>Serving size in grams.</summary>
    public int Gramm { get; set; }

    /// <summary>Whether this item is hidden from the recently-added list.</summary>
    public bool HiddenFromRecent { get; set; }

    /// <summary>JSON-encoded extended nutrient data. Null if not available.</summary>
    public string? ExtendedNutrientsJson { get; set; }
}
