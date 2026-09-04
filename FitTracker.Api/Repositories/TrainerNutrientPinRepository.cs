using FitTracker.Api.Data;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Repositories;

/// <summary>See <see cref="ITrainerNutrientPinRepository"/>.</summary>
public class TrainerNutrientPinRepository(AppDbContext context) : ITrainerNutrientPinRepository
{
    private readonly AppDbContext _context = context;

    /// <inheritdoc/>
    public async Task<List<string>> GetPinsAsync(Guid trainerId, Guid clientId) =>
        await _context.TrainerNutrientPins
            .Where(p => p.TrainerId == trainerId && p.ClientId == clientId)
            .OrderBy(p => p.SortOrder)
            .Select(p => p.NutrientKey)
            .ToListAsync();

    /// <inheritdoc/>
    public async Task ReplacePinsAsync(Guid trainerId, Guid clientId, List<string> nutrientKeys)
    {
        // A delete-then-insert in one SaveChanges call, not two round trips: EF
        // batches both into a single transaction, so a request that fails
        // partway never leaves the pair with neither the old set nor the new
        // one.
        var existing = await _context.TrainerNutrientPins
            .Where(p => p.TrainerId == trainerId && p.ClientId == clientId)
            .ToListAsync();
        _context.TrainerNutrientPins.RemoveRange(existing);

        _context.TrainerNutrientPins.AddRange(nutrientKeys.Select((key, index) => new TrainerNutrientPin
        {
            TrainerId = trainerId,
            ClientId = clientId,
            NutrientKey = key,
            SortOrder = index,
        }));

        await _context.SaveChangesAsync();
    }
}
