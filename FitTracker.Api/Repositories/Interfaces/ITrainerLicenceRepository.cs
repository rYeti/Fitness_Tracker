using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

public interface ITrainerLicenceRepository
{
    /// <summary>Returns the user's licence, or null if they aren't a trainer.</summary>
    Task<TrainerLicence?> GetByTrainerAsync(Guid trainerId);

    /// <summary>Provisions a Free licence, which is the act of becoming a trainer.
    ///
    /// Deliberately *not* a get-or-create: reads must never mint a licence. This
    /// is called from exactly one place — trainer registration — so that being a
    /// trainer is something an account is created as, never something a user
    /// falls into by opening a screen.</summary>
    Task<TrainerLicence> CreateFreeAsync(Guid trainerId);

    /// <summary>Looks a licence up by Stripe subscription — the webhook's entry point.</summary>
    Task<TrainerLicence?> GetBySubscriptionAsync(string stripeSubscriptionId);

    /// <summary>Looks a licence up by Stripe customer, for events that carry a
    /// customer but no subscription id.</summary>
    Task<TrainerLicence?> GetByCustomerAsync(string stripeCustomerId);

    /// <summary>Persists changes made to a tracked licence, stamping UpdatedAt.</summary>
    Task SaveAsync(TrainerLicence licence);
}
