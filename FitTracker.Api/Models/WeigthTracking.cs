namespace FitTracker.Api.Models;

/// <summary>Represents a single weight measurement entry recorded by a user.</summary>
public class WeightTracking
{
    /// <summary>
    /// The unique identifier for the weight tracking entry.
    /// </summary>
    public Guid Id { get; set; }
    /// <summary>
    /// The unique identifier for the user associated with this weight tracking entry.
    /// </summary>
    public Guid UserId { get; set; }
    /// <summary>
    /// The date when the weight was recorded.
    /// </summary>
    public DateTime Date { get; set; }
    /// <summary>
    /// The weight of the user on the specified date, stored as a double to match Flutter's real column type.
    /// </summary>
    public double Weight { get; set; }

    /// <summary>An optional note attached to this weight entry.</summary>
    public string? Note { get; set; } = null;

    // Navigation property to the User
    public User User { get; set; } = null!;
}