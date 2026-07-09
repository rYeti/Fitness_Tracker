using System.ComponentModel.DataAnnotations;

namespace FitTracker.Api.DTOs;

/// <summary>Request payload for a single item within a meal template.</summary>
public class MealTemplateItemRequestDto
{
    /// <summary>The client-side food item ID.</summary>
    public Guid FoodId { get; set; }

    /// <summary>The display name of the food.</summary>
    [Required, MaxLength(200)]
    public string FoodName { get; set; } = string.Empty;

    /// <summary>The quantity of this food.</summary>
    [Range(0, 100000)]
    public double Quantity { get; set; }

    /// <summary>The unit of measure (e.g. g, ml, piece).</summary>
    [Required, MaxLength(20)]
    public string Unit { get; set; } = string.Empty;

    /// <summary>Calories contributed by this item.</summary>
    [Range(0, 20000)]
    public double Calories { get; set; }

    /// <summary>Protein contributed by this item (g).</summary>
    [Range(0, 5000)]
    public double Protein { get; set; }

    /// <summary>Carbohydrates contributed by this item (g).</summary>
    [Range(0, 5000)]
    public double Carbs { get; set; }

    /// <summary>Fat contributed by this item (g).</summary>
    [Range(0, 5000)]
    public double Fat { get; set; }
}
