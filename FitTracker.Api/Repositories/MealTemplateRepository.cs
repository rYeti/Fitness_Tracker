using FitTracker.Api.Data;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Repositories;

/// <summary>EF Core implementation of <see cref="IMealTemplateRepository"/>.</summary>
public class MealTemplateRepository(AppDbContext context) : IMealTemplateRepository
{
    /// <inheritdoc/>
    public Task<List<MealTemplate>> GetAllAsync(Guid userId, DateTime? changedSince = null) =>
        context.MealTemplates
            .Where(t => t.UserId == userId)
            .ChangedSince(changedSince)
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
        await context.SaveNewAsync();
        return template;
    }

    /// <inheritdoc/>
    public Task<bool> WasDeletedAsync(Guid userId, Guid id) => context.WasDeletedAsync(userId, id);

    /// <inheritdoc/>
    public async Task<Guid?> GetOwnerAsync(Guid id) =>
        (await context.MealTemplates.AsNoTracking()
            .Where(t => t.Id == id)
            .Select(t => new { t.UserId })
            .FirstOrDefaultAsync())?.UserId;

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
        // Left out until now, so an edited batch size never reached the server: the app
        // scales every portion by it, and a reinstall brought the old one back.
        template.TotalWeightGrams = incoming.TotalWeightGrams;

        // Replace items: delete old ones, add new ones — through the DbSet, not by assigning
        // the navigation. The new items carry the ids they were given, and a row reached
        // only through a navigation with its key already set is taken for a stored one and
        // saved as an UPDATE, which matched nothing: every edit of a template with items
        // failed with a concurrency exception.
        context.MealTemplateItems.RemoveRange(template.Items);
        foreach (var item in incoming.Items) item.TemplateId = template.Id;
        context.MealTemplateItems.AddRange(incoming.Items);

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
