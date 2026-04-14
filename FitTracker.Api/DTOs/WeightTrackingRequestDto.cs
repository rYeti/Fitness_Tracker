namespace FitTracker.Api.DTOs;

public class WeightTrackingRequestDto
{
    /// <summary>
    /// 
    /// </summary>
    public DateTime Date { get; set; }

    /// <summary>
    /// 
    /// </summary>
    public decimal Weight { get; set; }

    /// <summary>
    /// 
    /// </summary>
    public string? Note { get; set; }
}