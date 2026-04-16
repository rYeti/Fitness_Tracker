using FitTracker.Api.Data;
using FitTracker.Api.Models;
using Microsoft.EntityFrameworkCore;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.DTOs;

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

    public async Task<WeightTracking?> UpdateWeightAsync(Guid id, Guid userId, WeightTrackingRequestDto dto)
    {
        var weightTracking = await _context.WeightTrackings.SingleOrDefaultAsync(w => w.Id == id && w.UserId == userId);

        if (weightTracking == null)
        {
            return null;
        }

        weightTracking.Date = DateTime.SpecifyKind(dto.Date, DateTimeKind.Utc);
        weightTracking.Weight = dto.Weight;
        weightTracking.Note = dto.Note;
        await _context.SaveChangesAsync();

        return weightTracking;
    }

    public async Task<bool> DeleteWeightAsync(Guid id, Guid userId)
    {
        var weightTracking = await _context.WeightTrackings.SingleOrDefaultAsync(w => w.Id == id && w.UserId == userId);

        if (weightTracking == null)
        {
            return false;
        }

        _context.WeightTrackings.Remove(weightTracking);
        await _context.SaveChangesAsync();

        return true;
    }
}
