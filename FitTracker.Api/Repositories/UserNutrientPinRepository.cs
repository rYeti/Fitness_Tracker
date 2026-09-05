using FitTracker.Api.Data;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Repositories;

/// <summary>See <see cref="IUserNutrientPinRepository"/>.</summary>
public class UserNutrientPinRepository(AppDbContext context) : IUserNutrientPinRepository
{
    private readonly AppDbContext _context = context;

    /// <inheritdoc/>
    public async Task<List<string>> GetPinsAsync(Guid userId) =>
        await _context.UserNutrientPins
            .Where(p => p.UserId == userId)
            .OrderBy(p => p.SortOrder)
            .Select(p => p.NutrientKey)
            .ToListAsync();

    /// <inheritdoc/>
    public async Task ReplacePinsAsync(Guid userId, List<string> nutrientKeys)
    {
        // A delete-then-insert in one SaveChanges call, not two round trips —
        // see TrainerNutrientPinRepository.ReplacePinsAsync for why.
        var existing = await _context.UserNutrientPins
            .Where(p => p.UserId == userId)
            .ToListAsync();
        _context.UserNutrientPins.RemoveRange(existing);

        _context.UserNutrientPins.AddRange(nutrientKeys.Select((key, index) => new UserNutrientPin
        {
            UserId = userId,
            NutrientKey = key,
            SortOrder = index,
        }));

        await _context.SaveChangesAsync();
    }
}
