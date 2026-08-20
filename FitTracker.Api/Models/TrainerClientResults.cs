namespace FitTracker.Api.Models;

/// <summary>Why minting an invite did or didn't work.</summary>
public enum CreateInviteStatus
{
    Ok,

    /// <summary>The trainer's active clients plus their outstanding invites
    /// already fill their plan.</summary>
    SeatLimitReached,

    /// <summary>The caller has no licence, so they aren't a trainer yet.</summary>
    NoLicence,

    /// <summary>The trainer's licence has lapsed past its grace window. They
    /// keep the clients they have, but may not take on new ones.</summary>
    NotEntitled,
}

/// <summary>Outcome of minting an invite. <see cref="SeatsUsed"/> and
/// <see cref="SeatLimit"/> are populated on refusal so the caller can tell the
/// trainer how full they are without a second round trip.</summary>
public readonly record struct CreateInviteResult(
    CreateInviteStatus Status,
    TrainerClient? Invite,
    int SeatsUsed,
    int SeatLimit);

/// <summary>Why redeeming an invite code did or didn't work.
///
/// This exists because the repository used to return null for every failure,
/// which left the API able to say only "Invalid or expired invite code" — so a
/// trainee whose trainer had simply run out of seats was told their code was
/// bad, and went looking for the wrong problem.</summary>
public enum AcceptInviteStatus
{
    Ok,
    NotFound,
    Expired,

    /// <summary>The code belongs to the redeeming user's own account.</summary>
    SelfInvite,

    /// <summary>The trainer filled up between minting the code and its
    /// redemption, or downgraded in the meantime.</summary>
    TrainerAtSeatLimit,

    /// <summary>The trainer's licence has lapsed past its grace window.</summary>
    TrainerNotEntitled,
}

public readonly record struct AcceptInviteResult(
    AcceptInviteStatus Status,
    TrainerClient? Relationship);
