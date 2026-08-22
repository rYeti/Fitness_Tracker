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

    /// <summary>Provisions a Free licence — the act of becoming a trainer.
    ///
    /// Holding a licence is the definition of being a trainer, which is why this
    /// is a plain insert rather than a get-or-create. It used to be the latter,
    /// reached from <c>GET api/TrainerLicence/me</c>, so merely opening the plan
    /// screen turned an ordinary user into a permanent trainer. Now the only
    /// caller is trainer registration, and the unique index on TrainerId turns a
    /// second call for the same user into an error rather than a silent no-op.</summary>
    public async Task<TrainerLicence> CreateFreeAsync(Guid trainerId)
    {
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
