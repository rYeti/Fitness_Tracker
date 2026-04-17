namespace FitTracker.Api.DTOs;

/// <summary>Request payload for changing a user's password.</summary>
public class ChangePasswordRequestDto
{
    /// <summary>The user's current password, used to verify identity before the change.</summary>
    public string CurrentPassword { get; set; } = string.Empty;

    /// <summary>The new password to set.</summary>
    public string NewPassword { get; set; } = string.Empty;
}
