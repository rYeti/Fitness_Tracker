using System.ComponentModel.DataAnnotations;

namespace FitTracker.Api.DTOs;

/// <summary>Request payload for creating or updating a food item.</summary>
public class FoodItemRequestDto
{
    /// <summary>The display name of the food.</summary>
    [Required, MaxLength(200)]
    public string Name { get; set; } = string.Empty;

    /// <summary>Calories per serving (kcal).</summary>
    [Range(0, 20000)]
    public int Calories { get; set; }

    /// <summary>Protein per serving (g).</summary>
    [Range(0, 5000)]
    public int Protein { get; set; }

    /// <summary>Carbohydrates per serving (g).</summary>
    [Range(0, 5000)]
    public int Carbs { get; set; }

    /// <summary>Fat per serving (g).</summary>
    [Range(0, 5000)]
    public int Fat { get; set; }

    /// <summary>Serving size in grams. Defaults to 100.</summary>
    [Range(1, 100000)]
    public int Gramm { get; set; } = 100;

    /// <summary>Whether to hide this item from the recently-added list.</summary>
    public bool HiddenFromRecent { get; set; } = false;

    /// <summary>JSON-encoded extended nutrient data. Null if not available.</summary>
    [MaxLength(10000)]
    public string? ExtendedNutrientsJson { get; set; }
}
