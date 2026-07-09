namespace FitTracker.Api.Models;

public enum TrainerClientStatus { Pending, Active, Revoked }

/// <summary>Relationship between a trainer and one of their clients.</summary>
public class TrainerClient
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid TrainerId { get; set; }
    public User Trainer { get; set; } = null!;

    /// <summary>Null until a client accepts the invite.</summary>
    public Guid? ClientId { get; set; }
    public User? Client { get; set; }

    public TrainerClientStatus Status { get; set; } = TrainerClientStatus.Pending;

    /// <summary>Short code the client uses to accept the invite.</summary>
    public string InviteCode { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? AcceptedAt { get; set; }
}
