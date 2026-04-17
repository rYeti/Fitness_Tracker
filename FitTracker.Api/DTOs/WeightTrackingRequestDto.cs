namespace FitTracker.Api.DTOs;

/// <summary>Request payload for logging or updating a weight entry.</summary>
public class WeightTrackingRequestDto
{
    /// <summary>The date the weight was recorded.</summary>
    public DateTime Date { get; set; }

    /// <summary>The recorded weight value.</summary>
    public double Weight { get; set; }

    /// <summary>An optional note to attach to the weight entry.</summary>
    public string? Note { get; set; }
}