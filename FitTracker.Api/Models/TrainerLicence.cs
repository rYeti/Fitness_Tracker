namespace FitTracker.Api.Models;

/// <summary>The purchasable plans. Free is an entry state, never a downgrade
/// target — see <c>docs/trainer-licensing.md</c> for why that matters.</summary>
public enum LicenceTier
{
    Free = 0,
    Solo = 1,
    Pro = 2,
    Studio = 3,
}

/// <summary>Mirrors the Stripe subscription status we care about. Anything
/// Stripe reports that isn't one of these maps to the nearest of them.</summary>
public enum LicenceStatus
{
    Active = 0,
    Trialing = 1,
    PastDue = 2,
    Canceled = 3,
}

/// <summary>
/// A trainer's plan: how many clients they may take on, and whether their
/// clients get Pro. One row per trainer; its existence is what makes a user a
/// trainer at all (see <c>TrainerClientService.GetStatusAsync</c>).
/// </summary>
public class TrainerLicence
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>The trainer this licence belongs to. Unique — one licence per user.</summary>
    public Guid TrainerId { get; set; }
    public User Trainer { get; set; } = null!;

    public LicenceTier Tier { get; set; } = LicenceTier.Free;

    /// <summary>The enforced seat count. Denormalised from <see cref="Tier"/> when
    /// a subscription changes, but stored rather than derived so a trainer can be
    /// grandfathered or comped above their tier without a code change — the
    /// migration relies on exactly that to avoid breaking existing trainers.</summary>
    public int SeatLimit { get; set; } = FreeSeatLimit;

    public LicenceStatus Status { get; set; } = LicenceStatus.Active;

    /// <summary>Whether this trainer has already consumed their one free trial.
    /// Without it, cancelling and re-subscribing would hand out a fresh 14 days
    /// of Pro every time.</summary>
    public bool HasUsedTrial { get; set; }

    public string? StripeCustomerId { get; set; }
    public string? StripeSubscriptionId { get; set; }
    public DateTime? CurrentPeriodEnd { get; set; }

    /// <summary>When the post-lapse grace window closes. Set when the licence
    /// leaves a healthy status, cleared when it recovers. Null on a healthy
    /// licence.</summary>
    public DateTime? GraceEndsAt { get; set; }

    /// <summary>Timestamp of the most recent Stripe event applied to this
    /// licence. Stripe retries and can deliver out of order, so an event older
    /// than this one is stale and must be ignored — otherwise a delayed
    /// "payment failed" could land after the "payment succeeded" that fixed it
    /// and re-break a healthy licence.</summary>
    public DateTime? LastStripeEventAt { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>Seats granted by the free tier, and the default for a new licence.</summary>
    public const int FreeSeatLimit = 3;

    /// <summary>How long a lapsed licence keeps working. A failed card on a
    /// Sunday shouldn't take a trainer's whole roster down before they can fix it.</summary>
    public static readonly TimeSpan GracePeriod = TimeSpan.FromDays(14);

    /// <summary>Whether the trainer may use the console: paid and current,
    /// trialing, or still inside the grace window after a lapse.</summary>
    public bool IsEntitled =>
        Status is LicenceStatus.Active or LicenceStatus.Trialing
        || (GraceEndsAt is DateTime grace && grace > DateTime.UtcNow);

    /// <summary>Whether this licence grants Pro to the trainer and every one of
    /// their active trainees.
    ///
    /// Free never qualifies, and that is the entire defence against the invite
    /// system being a free Pro dispenser: if a free seat allowance granted Pro,
    /// anyone could register a second account, invite themselves and redeem it.
    /// Do not relax this without replacing it with something equivalent.</summary>
    public bool GrantsPro => Tier != LicenceTier.Free && IsEntitled;
}
