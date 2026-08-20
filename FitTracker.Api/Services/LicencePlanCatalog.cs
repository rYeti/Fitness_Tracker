using FitTracker.Api.Models;

namespace FitTracker.Api.Services;

/// <summary>
/// The mapping between Stripe prices and what a trainer gets.
///
/// Prices themselves live in Stripe, not here — this only maps a price id to a
/// tier, and a tier to a seat count. That means the whole price ladder can be
/// retuned in the Stripe dashboard without a deploy or a migration; only the
/// seat counts and the set of tiers are code.
/// </summary>
public class LicencePlanCatalog(IConfiguration configuration)
{
    private readonly IConfiguration _configuration = configuration;

    /// <summary>Seats granted by each tier. The only place these numbers live.</summary>
    private static readonly Dictionary<LicenceTier, int> SeatsByTier = new()
    {
        [LicenceTier.Free] = TrainerLicence.FreeSeatLimit, // 3
        [LicenceTier.Solo] = 10,
        [LicenceTier.Pro] = 30,
        [LicenceTier.Studio] = 100,
    };

    /// <summary>Tiers a trainer can actually buy. Free is deliberately absent:
    /// it's an entry state, never a downgrade target. Letting someone move a
    /// full roster down onto Free would hand them those seats permanently,
    /// because going over the limit blocks new invites rather than revoking
    /// existing clients.</summary>
    public static readonly IReadOnlyList<LicenceTier> PurchasableTiers =
        [LicenceTier.Solo, LicenceTier.Pro, LicenceTier.Studio];

    public static int SeatsFor(LicenceTier tier) =>
        SeatsByTier.TryGetValue(tier, out var seats) ? seats : TrainerLicence.FreeSeatLimit;

    /// <summary>The Stripe price id backing a tier, or null if it isn't configured.</summary>
    public string? PriceFor(LicenceTier tier) =>
        tier == LicenceTier.Free ? null : _configuration[$"Stripe:Prices:{tier}"];

    /// <summary>The tier a Stripe price belongs to, or null if the price isn't one
    /// of ours. An unknown price must leave the licence's tier alone rather than
    /// silently downgrading someone to Free.</summary>
    public LicenceTier? TierForPrice(string? priceId)
    {
        if (string.IsNullOrWhiteSpace(priceId)) return null;

        foreach (var tier in PurchasableTiers)
        {
            var configured = PriceFor(tier);
            if (!string.IsNullOrWhiteSpace(configured) &&
                string.Equals(configured, priceId, StringComparison.Ordinal))
            {
                return tier;
            }
        }
        return null;
    }
}
