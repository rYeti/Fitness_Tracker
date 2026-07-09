using System.ComponentModel.DataAnnotations;

namespace FitTracker.Api.DTOs;

/// <summary>Request payload for authenticating a user.</summary>
public class LoginRequestDto
{
    /// <summary>The users username.</summary>
    [Required, MaxLength(50)]
    public string Username { get; set; } = string.Empty;

    /// <summary>The users password.</summary>
    [Required, MaxLength(128)]
    public string Password { get; set; } = string.Empty;
}
