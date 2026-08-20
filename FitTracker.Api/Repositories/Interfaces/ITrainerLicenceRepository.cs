using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

public interface ITrainerLicenceRepository
{
    /// <summary>Returns the user's licence, or null if they aren't a trainer.</summary>
    Task<TrainerLicence?> GetByTrainerAsync(Guid trainerId);

    /// <summary>Returns the user's licence, provisioning a Free one if they don't
    /// have it yet. This is the act of becoming a trainer.</summary>
    Task<TrainerLicence> GetOrCreateAsync(Guid trainerId);

    /// <summary>Looks a licence up by Stripe subscription — the webhook's entry point.</summary>
    Task<TrainerLicence?> GetBySubscriptionAsync(string stripeSubscriptionId);

    /// <summary>Looks a licence up by Stripe customer, for events that carry a
    /// customer but no subscription id.</summary>
    Task<TrainerLicence?> GetByCustomerAsync(string stripeCustomerId);

    /// <summary>Persists changes made to a tracked licence, stamping UpdatedAt.</summary>
    Task SaveAsync(TrainerLicence licence);
}
