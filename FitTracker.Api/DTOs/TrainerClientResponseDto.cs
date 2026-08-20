namespace FitTracker.Api.DTOs;

public class TrainerClientResponseDto
{
    public Guid Id { get; set; }
    public Guid TrainerId { get; set; }
    public string TrainerName { get; set; } = string.Empty;
    public Guid ClientId { get; set; }
    public string ClientName { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public string InviteCode { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime? AcceptedAt { get; set; }
}

public class TrainerClientStatusDto
{
    public bool IsTrainerClient { get; set; }

    /// <summary>Whether this user holds a trainer licence. Note this is no longer
    /// "has at least one client" — a trainer with an empty roster is still a
    /// trainer, and needs the console in order to stop being one.</summary>
    public bool IsTrainer { get; set; }

    public string? TrainerName { get; set; }
    public Guid? TrainerId { get; set; }

    /// <summary>Whether this user gets Pro from a licence: either their trainer's
    /// paid, current one, or their own.
    ///
    /// Computed entirely server-side. The client must not try to derive premium
    /// from the mere existence of a trainer relationship — doing so is what made
    /// any invite code a free Pro dispenser.</summary>
    public bool ProFromLicence { get; set; }

    /// <summary>For a trainee whose trainer's licence has lapsed: when their
    /// derived Pro stops. Null when nothing is expiring.</summary>
    public DateTime? ProEndsAt { get; set; }

    /// <summary>The caller's own plan. Null for users who aren't trainers.</summary>
    public TrainerLicenceDto? Licence { get; set; }
}
