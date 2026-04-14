
namespace FitTracker.Api.DTOs;

public class WeightTrackingResponseDto
{
    public Guid Id { get; set; }

    public DateTime Date { get; set; }

    public decimal Weight { get; set; }

    public string? Note { get; set; }
}