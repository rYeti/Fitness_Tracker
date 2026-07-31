using FitTracker.Api.Enums;

namespace FitTracker.Api.Models;

public class ChatMessage
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public string? Body { get; set; }

    public Guid SenderId { get; set; }

    public DateTime SentAt { get; set; } = DateTime.UtcNow;

    public TrainerClient TrainerClient { get; set; } = null!;

    public Media? MediaType { get; set; }

    public string? Url { get; set; }

    public string? ThumbnailUrl { get; set; }

}