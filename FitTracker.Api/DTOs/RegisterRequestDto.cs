using System.ComponentModel.DataAnnotations;

namespace FitTracker.Api.DTOs;

/// <summary>Request payload for registering a new user account.</summary>
public class RegisterRequestDto
{
    /// <summary>The desired username for the new account.</summary>
    [Required, MaxLength(50)]
    public string Username { get; set; } = string.Empty;

    /// <summary>The plaintext password chosen by the user.</summary>
    [Required, MinLength(8), MaxLength(128)]
    public string Password { get; set; } = string.Empty;

    /// <summary>The user's first name.</summary>
    [Required, MaxLength(100)]
    public string FirstName { get; set; } = string.Empty;

    /// <summary>The user's last name.</summary>
    [Required, MaxLength(100)]
    public string LastName { get; set; } = string.Empty;

    /// <summary>The user's email address.</summary>
    [Required, EmailAddress, MaxLength(254)]
    public string Email { get; set; } = string.Empty;

    /// <summary>The user's date of birth.</summary>
    public DateTime DateOfBirth { get; set; }

}
