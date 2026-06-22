using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

/// <summary>Implementation of <see cref="IMealTemplateService"/>.</summary>
public class MealTemplateService(IMealTemplateRepository repository) : IMealTemplateService
{
    /// <inheritdoc/>
    public async Task<List<MealTemplateResponseDto>> GetAllAsync(Guid userId)
    {
        var templates = await repository.GetAllAsync(userId);
        return templates.Select(ToDto).ToList();
    }

    /// <inheritdoc/>
    public async Task<MealTemplateResponseDto?> GetByIdAsync(Guid id, Guid userId)
    {
        var template = await repository.GetByIdAsync(id, userId);
        return template is null ? null : ToDto(template);
    }

    /// <inheritdoc/>
    public async Task<MealTemplateResponseDto> CreateAsync(MealTemplateRequestDto dto, Guid userId)
    {
        var template = new MealTemplate
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Name = dto.Name,
            Description = dto.Description,
            Category = dto.Category,
            TotalWeightGrams = dto.TotalWeightGrams,
            Items = dto.Items.Select(i => ToItemModel(i)).ToList(),
        };

        var created = await repository.CreateAsync(template);
        return ToDto(created);
    }

    /// <inheritdoc/>
    public async Task<MealTemplateResponseDto?> UpdateAsync(Guid id, Guid userId, MealTemplateRequestDto dto)
    {
        var incoming = new MealTemplate
        {
            Name = dto.Name,
            Description = dto.Description,
            Category = dto.Category,
            TotalWeightGrams = dto.TotalWeightGrams,
            Items = dto.Items.Select(i => ToItemModel(i)).ToList(),
        };

        var updated = await repository.UpdateAsync(id, userId, incoming);
        return updated is null ? null : ToDto(updated);
    }

    /// <inheritdoc/>
    public Task<bool> DeleteAsync(Guid id, Guid userId) =>
        repository.DeleteAsync(id, userId);

    private static MealTemplateItem ToItemModel(MealTemplateItemRequestDto i) => new()
    {
        Id = Guid.NewGuid(),
        FoodId = i.FoodId,
        FoodName = i.FoodName,
        Quantity = i.Quantity,
        Unit = i.Unit,
        Calories = i.Calories,
        Protein = i.Protein,
        Carbs = i.Carbs,
        Fat = i.Fat,
    };

    private static MealTemplateResponseDto ToDto(MealTemplate t) => new()
    {
        Id = t.Id,
        Name = t.Name,
        Description = t.Description,
        Category = t.Category,
        TotalWeightGrams = t.TotalWeightGrams,
        Items = t.Items.Select(i => new MealTemplateItemResponseDto
        {
            Id = i.Id,
            TemplateId = i.TemplateId,
            FoodId = i.FoodId,
            FoodName = i.FoodName,
            Quantity = i.Quantity,
            Unit = i.Unit,
            Calories = i.Calories,
            Protein = i.Protein,
            Carbs = i.Carbs,
            Fat = i.Fat,
        }).ToList(),
    };
}
