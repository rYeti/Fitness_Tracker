using FitTracker.Api.DTOs;

namespace FitTracker.Api.Services.Interfaces;

/// <summary>Business-logic contract for meal template management.</summary>
public interface IMealTemplateService
{
    /// <summary>Returns all templates for the specified user.</summary>
    Task<List<MealTemplateResponseDto>> GetAllAsync(Guid userId);

    /// <summary>Returns a single template by ID, or null if not found.</summary>
    Task<MealTemplateResponseDto?> GetByIdAsync(Guid id, Guid userId);

    /// <summary>Creates a new meal template.</summary>
    Task<MealTemplateResponseDto> CreateAsync(MealTemplateRequestDto dto, Guid userId);

    /// <summary>Replaces an existing meal template. Returns null if not found.</summary>
    Task<MealTemplateResponseDto?> UpdateAsync(Guid id, Guid userId, MealTemplateRequestDto dto);

    /// <summary>Deletes a meal template. Returns false if not found.</summary>
    Task<bool> DeleteAsync(Guid id, Guid userId);
}
