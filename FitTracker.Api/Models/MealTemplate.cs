namespace FitTracker.Api.Models;

/// <summary>A reusable meal template owned by a user.</summary>
public class MealTemplate
{
    /// <summary>The unique identifier of this template.</summary>
    public Guid Id { get; set; }

    /// <summary>The ID of the user who owns this template.</summary>
    public Guid UserId { get; set; }

    /// <summary>The display name of the template.</summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>Optional description of the template.</summary>
    public string? Description { get; set; }

    /// <summary>Meal category (e.g. Breakfast, Lunch, Dinner, Snack).</summary>
    public string Category { get; set; } = string.Empty;

    /// <summary>Navigation property to the owning user.</summary>
    public User User { get; set; } = null!;

    /// <summary>Total weight of the prepared batch in grams (used for portion scaling).</summary>
    public decimal? TotalWeightGrams { get; set; }

    /// <summary>The food items that make up this template.</summary>
    public ICollection<MealTemplateItem> Items { get; set; } = [];
}
