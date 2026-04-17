namespace FitTracker.Api.DTOs;

/// <summary>Request payload for registering a new user account.</summary>
public class RegisterRequestDto
{
    /// <summary>The desired username for the new account.</summary>
    public string Username { get; set; } = string.Empty;

    /// <summary>The plaintext password chosen by the user.</summary>
    public string Password { get; set; } = string.Empty;

    /// <summary>The user's first name.</summary>
    public string FirstName { get; set; } = string.Empty;

    /// <summary>The user's last name.</summary>
    public string LastName { get; set; } = string.Empty;

    /// <summary>The user's email address.</summary>
    public string Email { get; set; } = string.Empty;

    /// <summary>The user's date of birth.</summary>
    public DateTime DateOfBirth { get; set; }

}