using FitTracker.Api.Data;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Repositories;

/// <summary>Data access for trainer licences.</summary>
public class TrainerLicenceRepository(AppDbContext context) : ITrainerLicenceRepository
{
    private readonly AppDbContext _context = context;

    public async Task<TrainerLicence?> GetByTrainerAsync(Guid trainerId) =>
        await _context.TrainerLicences.FirstOrDefaultAsync(l => l.TrainerId == trainerId);

    /// <summary>Provisions a Free licence on first ask.
    ///
    /// This is what breaks the chicken-and-egg the console used to have: a user
    /// was only "a trainer" if they already had active clients, so a new trainer
    /// was locked out of the very screen they needed in order to invite anyone.
    /// Holding a licence is now the definition.</summary>
    public async Task<TrainerLicence> GetOrCreateAsync(Guid trainerId)
    {
        var existing = await GetByTrainerAsync(trainerId);
        if (existing != null) return existing;

        var licence = new TrainerLicence
        {
            TrainerId = trainerId,
            Tier = LicenceTier.Free,
            SeatLimit = TrainerLicence.FreeSeatLimit,
            Status = LicenceStatus.Active,
        };
        _context.TrainerLicences.Add(licence);
        await _context.SaveChangesAsync();
        return licence;
    }

    public async Task<TrainerLicence?> GetBySubscriptionAsync(string stripeSubscriptionId) =>
        await _context.TrainerLicences
            .FirstOrDefaultAsync(l => l.StripeSubscriptionId == stripeSubscriptionId);

    public async Task<TrainerLicence?> GetByCustomerAsync(string stripeCustomerId) =>
        await _context.TrainerLicences
            .FirstOrDefaultAsync(l => l.StripeCustomerId == stripeCustomerId);

    public async Task SaveAsync(TrainerLicence licence)
    {
        licence.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
    }
}
