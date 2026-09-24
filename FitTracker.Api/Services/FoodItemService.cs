using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

/// <summary>Implementation of <see cref="IFoodItemService"/>.</summary>
public class FoodItemService(IFoodItemRepository repository) : IFoodItemService
{
    /// <inheritdoc/>
    public async Task<List<FoodItemResponseDto>> GetUserFoodItemsAsync(Guid userId)
    {
        var items = await repository.GetUserFoodItemsAsync(userId);
        return items.Select(ToDto).ToList();
    }

    /// <inheritdoc/>
    public async Task<List<FoodItemResponseDto>> GetFoodItemsByIdsAsync(Guid userId, IReadOnlyCollection<Guid> ids)
    {
        var items = await repository.GetFoodItemsByIdsAsync(userId, ids);
        return [.. items.Select(ToDto)];
    }

    /// <inheritdoc/>
    public async Task<FoodItemResponseDto?> GetFoodItemByIdAsync(Guid id, Guid userId)
    {
        var item = await repository.GetFoodItemByIdAsync(id, userId);
        return item is null ? null : ToDto(item);
    }

    /// <inheritdoc/>
    public async Task<FoodItemResponseDto> CreateFoodItemAsync(FoodItemRequestDto dto, Guid userId)
    {
        var result = await ClientIds.CreateOrResolveAsync(
            dto.Id,
            userId,
            repository.GetOwnerAsync,
            id => UpdateFoodItemAsync(id, userId, dto),
            async id => ToDto(await repository.CreateFoodItemAsync(new FoodItem
            {
                Id = id,
                UserId = userId,
                Name = dto.Name,
                Calories = dto.Calories,
                Protein = dto.Protein,
                Carbs = dto.Carbs,
                Fat = dto.Fat,
                Gramm = dto.Gramm,
                HiddenFromRecent = dto.HiddenFromRecent,
                ExtendedNutrientsJson = dto.ExtendedNutrientsJson,
            })));
        return result!;
    }

    /// <inheritdoc/>
    public async Task<FoodItemResponseDto?> UpdateFoodItemAsync(Guid id, Guid userId, FoodItemRequestDto dto)
    {
        var update = new FoodItem
        {
            Name = dto.Name,
            Calories = dto.Calories,
            Protein = dto.Protein,
            Carbs = dto.Carbs,
            Fat = dto.Fat,
            Gramm = dto.Gramm,
            HiddenFromRecent = dto.HiddenFromRecent,
            ExtendedNutrientsJson = dto.ExtendedNutrientsJson,
        };

        var updated = await repository.UpdateFoodItemAsync(id, userId, update);
        return updated is null ? null : ToDto(updated);
    }

    /// <inheritdoc/>
    public Task<bool> DeleteFoodItemAsync(Guid id, Guid userId) =>
        repository.DeleteFoodItemAsync(id, userId);

    private static FoodItemResponseDto ToDto(FoodItem f) => new()
    {
        Id = f.Id,
        Name = f.Name,
        Calories = f.Calories,
        Protein = f.Protein,
        Carbs = f.Carbs,
        Fat = f.Fat,
        Gramm = f.Gramm,
        HiddenFromRecent = f.HiddenFromRecent,
        ExtendedNutrientsJson = f.ExtendedNutrientsJson,
    };
}
