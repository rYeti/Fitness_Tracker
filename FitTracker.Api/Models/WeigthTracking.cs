using FitTracker.Api.Models;

public class WeightTracking
{
    public Guid UserId { get; set; }
    public DateTime Date { get; set; }
    public decimal Weight { get; set; }

    // Navigation property to the User
    public User User { get; set; } = null!;
}