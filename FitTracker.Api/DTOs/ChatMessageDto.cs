using FitTracker.Api.Enums;

namespace FitTracker.Api.DTOs;

public class ChatMessageDto
{
    public Guid Id { get; set; }
    public string? Body { get; set; }

    public DateTime SentAt { get; set; }

    public Guid SenderId { get; set; }

    public Guid TrainerId { get; set; }

    public Guid ClientId { get; set; }

    public Media? MediaType { get; set; }

    public string? Url { get; set; }

    public string? ThumbnailUrl { get; set; }
}