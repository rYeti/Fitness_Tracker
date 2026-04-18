namespace FitTracker.Api.DTOs;

/// <summary>Request payload for a single item within a meal template.</summary>
public class MealTemplateItemRequestDto
{
    /// <summary>The client-side food item ID.</summary>
    public Guid FoodId { get; set; }

    /// <summary>The display name of the food.</summary>
    public string FoodName { get; set; } = string.Empty;

    /// <summary>The quantity of this food.</summary>
    public double Quantity { get; set; }

    /// <summary>The unit of measure (e.g. g, ml, piece).</summary>
    public string Unit { get; set; } = string.Empty;

    /// <summary>Calories contributed by this item.</summary>
    public double Calories { get; set; }

    /// <summary>Protein contributed by this item (g).</summary>
    public double Protein { get; set; }

    /// <summary>Carbohydrates contributed by this item (g).</summary>
    public double Carbs { get; set; }

    /// <summary>Fat contributed by this item (g).</summary>
    public double Fat { get; set; }
}
