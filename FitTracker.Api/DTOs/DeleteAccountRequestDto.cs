namespace FitTracker.Api.DTOs;

/// <summary>Request payload for permanently deleting a user account.</summary>
public class DeleteAccountRequestDto
{
    /// <summary>The user's current password, used to confirm the deletion.</summary>
    public string Password { get; set; } = string.Empty;
}
