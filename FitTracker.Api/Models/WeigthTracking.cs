namespace FitTracker.Api.Models;

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
    /// The weight of the user on the specified date. This property is of type decimal to allow for precise weight measurements, including fractional values.
    /// </summary>
    public decimal Weight { get; set; }

    // Navigation property to the User
    public User User { get; set; } = null!;
}