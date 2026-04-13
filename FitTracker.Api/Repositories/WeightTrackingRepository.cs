using FitTracker.Api.Data;
using FitTracker.Api.Models;
using Microsoft.EntityFrameworkCore;
using FitTracker.Api.Repositories.Interfaces;
namespace FitTracker.Api.Repositories;

public class WeightTrackingRepository(AppDbContext context) : IWeightTrackingRepository
{
    private readonly AppDbContext _context = context;

    public async Task<WeightTracking?> GetWeightTrackingByIdAsync(Guid id)
    {
        return await _context.WeightTrackings.FindAsync(id);
    }

    public async Task<List<WeightTracking>> GetWeightTrackingsAsync(Guid id)
    {
        return await _context.WeightTrackings.Where(w => w.UserId == id).ToListAsync();
    }

    public async Task<WeightTracking?> CreateWeightTrackingAsync(WeightTracking weightTracking)
    {
        _context.WeightTrackings.Add(weightTracking);
        await _context.SaveChangesAsync();
        return weightTracking;
    }
}
