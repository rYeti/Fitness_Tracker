using System.ComponentModel.DataAnnotations;

namespace FitTracker.Api.DTOs;

/// <summary>Request payload for logging or updating a weight entry.</summary>
public class WeightTrackingRequestDto
{
    /// <summary>
    /// The id the app minted for this row. Only a create reads it: a repeat of the
    /// same id updates and returns the row it already made, and an id that names
    /// someone else's row is refused with 409. Apps older than client-minted ids send
    /// none, and the server mints one. See <see cref="Services.ClientIds"/>.
    /// </summary>
    public Guid? Id { get; set; }

    /// <summary>The date the weight was recorded.</summary>
    public DateTime Date { get; set; }

    /// <summary>The recorded weight value.</summary>
    [Range(1, 1000)]
    public double Weight { get; set; }

    /// <summary>An optional note to attach to the weight entry.</summary>
    [MaxLength(1000)]
    public string? Note { get; set; }
}