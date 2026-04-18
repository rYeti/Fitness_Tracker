namespace FitTracker.Api.Models;

/// <summary>A single food entry within a meal template.</summary>
public class MealTemplateItem
{
    /// <summary>The unique identifier of this item.</summary>
    public Guid Id { get; set; }

    /// <summary>The ID of the parent meal template.</summary>
    public Guid TemplateId { get; set; }

    /// <summary>The client-side food item ID (opaque reference, no FK enforced).</summary>
    public Guid FoodId { get; set; }

    /// <summary>The display name of the food at the time it was added.</summary>
    public string FoodName { get; set; } = string.Empty;

    /// <summary>The quantity of this food in the template.</summary>
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

    /// <summary>Navigation property to the parent template.</summary>
    public MealTemplate Template { get; set; } = null!;
}
