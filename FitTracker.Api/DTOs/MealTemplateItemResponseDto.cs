namespace FitTracker.Api.DTOs;

/// <summary>Response payload for a single item within a meal template.</summary>
public class MealTemplateItemResponseDto
{
    public Guid Id { get; set; }
    public Guid TemplateId { get; set; }
    public Guid FoodId { get; set; }
    public string FoodName { get; set; } = string.Empty;
    public double Quantity { get; set; }
    public string Unit { get; set; } = string.Empty;
    public double Calories { get; set; }
    public double Protein { get; set; }
    public double Carbs { get; set; }
    public double Fat { get; set; }
}
