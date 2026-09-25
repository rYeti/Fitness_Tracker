using System.ComponentModel.DataAnnotations;

namespace FitTracker.Api.DTOs;

/// <summary>Request payload for creating or updating a meal log entry.</summary>
public class MealRequestDto
{
    /// <summary>
    /// The id the app minted for this row. Only a create reads it: a repeat of the
    /// same id updates and returns the row it already made, and an id that names
    /// someone else's row is refused with 409. Apps older than client-minted ids send
    /// none, and the server mints one. See <see cref="Services.ClientIds"/>.
    /// </summary>
    public Guid? Id { get; set; }

    /// <summary>The date this food was logged.</summary>
    public DateTime Date { get; set; }

    /// <summary>The meal category (e.g. "breakfast", "lunch", "dinner", "snack").</summary>
    [Required, MaxLength(50)]
    public string Category { get; set; } = string.Empty;

    /// <summary>The client-side ID of the food item being logged.</summary>
    public Guid FoodItemId { get; set; }
}
