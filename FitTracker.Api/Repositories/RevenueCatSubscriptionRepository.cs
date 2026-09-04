using FitTracker.Api.Data;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Repositories;

/// <summary>See <see cref="IRevenueCatSubscriptionRepository"/>.</summary>
public class RevenueCatSubscriptionRepository(AppDbContext context) : IRevenueCatSubscriptionRepository
{
    private readonly AppDbContext _context = context;

    /// <inheritdoc/>
    public async Task<RevenueCatSubscription?> GetByUserAsync(Guid userId) =>
        await _context.RevenueCatSubscriptions.FirstOrDefaultAsync(s => s.UserId == userId);

    /// <inheritdoc/>
    public async Task<bool> IsEntitledAsync(Guid userId)
    {
        var subscription = await GetByUserAsync(userId);
        return subscription?.IsEntitled ?? false;
    }

    /// <inheritdoc/>
    public async Task<RevenueCatSubscription> GetOrCreateAsync(Guid userId)
    {
        var existing = await GetByUserAsync(userId);
        if (existing != null) return existing;

        var created = new RevenueCatSubscription { UserId = userId };
        _context.RevenueCatSubscriptions.Add(created);
        return created;
    }

    /// <inheritdoc/>
    public async Task SaveAsync(RevenueCatSubscription subscription)
    {
        subscription.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
    }
}
