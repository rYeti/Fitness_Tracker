using System.ComponentModel.DataAnnotations;

namespace FitTracker.Api.DTOs;

/// <summary>Request payload for creating or replacing a meal template.</summary>
public class MealTemplateRequestDto
{
    /// <summary>
    /// The id the app minted for this row. Only a create reads it: a repeat of the
    /// same id updates and returns the row it already made, and an id that names
    /// someone else's row is refused with 409. Apps older than client-minted ids send
    /// none, and the server mints one. See <see cref="Services.ClientIds"/>.
    /// </summary>
    public Guid? Id { get; set; }

    /// <summary>The display name of the template.</summary>
    [Required, MaxLength(200)]
    public string Name { get; set; } = string.Empty;

    /// <summary>Optional description of the template.</summary>
    [MaxLength(2000)]
    public string? Description { get; set; }

    /// <summary>Meal category (e.g. Breakfast, Lunch, Dinner, Snack).</summary>
    [Required, MaxLength(50)]
    public string Category { get; set; } = string.Empty;

    /// <summary>Total weight of the prepared batch in grams (used for portion scaling).</summary>
    [Range(0, 100000)]
    public decimal? TotalWeightGrams { get; set; }

    /// <summary>The food items that make up this template.</summary>
    public List<MealTemplateItemRequestDto> Items { get; set; } = [];
}
