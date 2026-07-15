namespace FitTracker.Api.DTOs;

public class WorkoutPlanTemplateResponseDto
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string Icon { get; set; } = string.Empty;
    public int DaysPerWeek { get; set; }
}
