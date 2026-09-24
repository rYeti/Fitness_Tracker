using FitTracker.Api.Data;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Repositories;

/// <summary>Saving rows inserted under an id the client chose.</summary>
internal static class DbContextExtensions
{
    /// <summary>
    /// Saves pending inserts. If the save fails, whatever it was inserting stops being
    /// tracked before the exception goes on.
    /// </summary>
    /// <remarks>
    /// A client-chosen id can lose a race to a concurrent request carrying the same id
    /// (see <c>ClientIds.CreateOrResolveAsync</c>), which then looks the id up again. Left
    /// tracked, the row that failed to insert would answer that lookup itself — a tracking
    /// query returns the instance already in the identity map, not the stored one — and
    /// the next save in the request would try to insert it a second time.
    /// </remarks>
    public static async Task SaveNewAsync(this AppDbContext context)
    {
        try
        {
            await context.SaveChangesAsync();
        }
        catch (DbUpdateException)
        {
            foreach (var entry in context.ChangeTracker.Entries()
                         .Where(e => e.State == EntityState.Added)
                         .ToList())
            {
                entry.State = EntityState.Detached;
            }
            throw;
        }
    }
}
