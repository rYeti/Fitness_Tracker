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

    /// <summary>
    /// The item's micronutrients, as an opaque JSON blob written by the
    /// client. The server never parses it: every value inside is in grams by
    /// the client's own convention, and a second, independently-maintained
    /// copy of that table here is exactly how the two sides drift apart.
    /// Null when the food carried none — never an empty object, which would
    /// read as "measured, all zero". See
    /// docs/trainer-console-micronutrients.md.
    /// </summary>
    public string? ExtendedNutrientsJson { get; set; }

    /// <summary>Navigation property to the parent template.</summary>
    public MealTemplate Template { get; set; } = null!;
}
