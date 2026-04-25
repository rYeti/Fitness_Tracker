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
    public bool IsTrainer { get; set; }
    public string? TrainerName { get; set; }
    public Guid? TrainerId { get; set; }
}
