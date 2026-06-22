namespace FitTracker.Api.DTOs;

/// <summary>Response payload for a meal template.</summary>
public class MealTemplateResponseDto
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string Category { get; set; } = string.Empty;
    public decimal? TotalWeightGrams { get; set; }
    public List<MealTemplateItemResponseDto> Items { get; set; } = [];
}
