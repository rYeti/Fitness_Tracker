
namespace FitTracker.Api.DTOs;

/// <summary>Response payload returned when reading a weight tracking entry.</summary>
public class WeightTrackingResponseDto
{
    /// <summary>The unique identifier of the weight entry.</summary>
    public Guid Id { get; set; }

    /// <summary>The date the weight was recorded.</summary>
    public DateTime Date { get; set; }

    /// <summary>The recorded weight value.</summary>
    public double Weight { get; set; }

    /// <summary>An optional note attached to the weight entry.</summary>
    public string? Note { get; set; }
}