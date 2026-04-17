namespace FitTracker.Api.DTOs;

/// <summary>Request payload for updating an authenticated user's profile information.</summary>
public class UpdateProfileRequestDto
{
    /// <summary>The user's updated first name.</summary>
    public string FirstName { get; set; } = string.Empty;

    /// <summary>The user's updated last name.</summary>
    public string LastName { get; set; } = string.Empty;

    /// <summary>The user's updated email address.</summary>
    public string Email { get; set; } = string.Empty;

    /// <summary>The user's updated date of birth.</summary>
    public DateTime DateOfBirth { get; set; }

    /// <summary>Optional URL of the user's profile image.</summary>
    public string? ProfileImageUrl { get; set; }
}
