using FitTracker.Api.Data;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Repositories;

/// <summary>EF Core implementation of <see cref="IMealTemplateRepository"/>.</summary>
public class MealTemplateRepository(AppDbContext context) : IMealTemplateRepository
{
    /// <inheritdoc/>
    public Task<List<MealTemplate>> GetAllAsync(Guid userId) =>
        context.MealTemplates
            .Where(t => t.UserId == userId)
            .Include(t => t.Items)
            .ToListAsync();

    /// <inheritdoc/>
    public Task<MealTemplate?> GetByIdAsync(Guid id, Guid userId) =>
        context.MealTemplates
            .Include(t => t.Items)
            .FirstOrDefaultAsync(t => t.Id == id && t.UserId == userId);

    /// <inheritdoc/>
    public async Task<MealTemplate> CreateAsync(MealTemplate template)
    {
        context.MealTemplates.Add(template);
        await context.SaveChangesAsync();
        return template;
    }

    /// <inheritdoc/>
    public async Task<MealTemplate?> UpdateAsync(Guid id, Guid userId, MealTemplate incoming)
    {
        var template = await context.MealTemplates
            .Include(t => t.Items)
            .FirstOrDefaultAsync(t => t.Id == id && t.UserId == userId);

        if (template is null) return null;

        template.Name = incoming.Name;
        template.Description = incoming.Description;
        template.Category = incoming.Category;

        // Replace items: delete old ones, add new ones.
        context.MealTemplateItems.RemoveRange(template.Items);
        template.Items = incoming.Items;

        await context.SaveChangesAsync();
        return template;
    }

    /// <inheritdoc/>
    public async Task<bool> DeleteAsync(Guid id, Guid userId)
    {
        var template = await context.MealTemplates
            .FirstOrDefaultAsync(t => t.Id == id && t.UserId == userId);

        if (template is null) return false;

        context.MealTemplates.Remove(template);
        await context.SaveChangesAsync();
        return true;
    }
}
