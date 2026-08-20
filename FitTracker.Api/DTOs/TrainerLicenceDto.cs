using FitTracker.Api.Models;

namespace FitTracker.Api.DTOs;

/// <summary>A trainer's plan as the console needs to render it.</summary>
public class TrainerLicenceDto
{
    public string Tier { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public int SeatsUsed { get; set; }
    public int SeatLimit { get; set; }

    /// <summary>True while the trainer may use the console at all.</summary>
    public bool IsEntitled { get; set; }

    /// <summary>True when this plan grants Pro to the trainer and their clients.
    /// False on the free tier, whatever its status.</summary>
    public bool GrantsPro { get; set; }

    /// <summary>Set only while the licence has lapsed but is still inside its
    /// grace window; the console shows a banner naming this date.</summary>
    public DateTime? GraceEndsAt { get; set; }

    public DateTime? CurrentPeriodEnd { get; set; }
    public bool HasUsedTrial { get; set; }

    /// <summary>Whether the trainer has a Stripe customer record, and so whether
    /// "Manage billing" can open the portal.</summary>
    public bool HasBillingAccount { get; set; }

    public static TrainerLicenceDto From(TrainerLicence licence, int seatsUsed) => new()
    {
        Tier = licence.Tier.ToString(),
        Status = licence.Status.ToString(),
        SeatsUsed = seatsUsed,
        SeatLimit = licence.SeatLimit,
        IsEntitled = licence.IsEntitled,
        GrantsPro = licence.GrantsPro,
        GraceEndsAt = licence.GraceEndsAt,
        CurrentPeriodEnd = licence.CurrentPeriodEnd,
        HasUsedTrial = licence.HasUsedTrial,
        HasBillingAccount = !string.IsNullOrEmpty(licence.StripeCustomerId),
    };
}

/// <summary>Result of minting an invite. <see cref="Status"/> drives the HTTP
/// status code; the seat numbers let the console explain a refusal without a
/// second round trip.</summary>
public class CreateInviteOutcome
{
    public CreateInviteStatus Status { get; set; }
    public TrainerClientResponseDto? Invite { get; set; }
    public int SeatsUsed { get; set; }
    public int SeatLimit { get; set; }
}

/// <summary>Result of redeeming an invite code.</summary>
public class AcceptInviteOutcome
{
    public AcceptInviteStatus Status { get; set; }
    public TrainerClientResponseDto? Relationship { get; set; }
}

/// <summary>One outstanding invite, as shown in the trainer's pending list.</summary>
public class PendingInviteDto
{
    public Guid Id { get; set; }
    public string InviteCode { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime ExpiresAt { get; set; }
}
