namespace FitTracker.Api.DTOs;

/// <summary>Request payload for authenticating a user.</summary>
public class LoginRequestDto
{
    /// <summary>The users username.</summary>
    public string Username { get; set; } = string.Empty;

    /// <summary>The users password.</summary>
    public string Password { get; set; } = string.Empty;
}