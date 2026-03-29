namespace FitTracker.Api.DTOs;

public class AuthResponseDto
{
    /// <summary>
    /// JWT token that can be used for authenticated requests.
    /// </summary>
    public string Token { get; set; } = string.Empty;

    /// <summary>
    /// Expiration time of the JWT token. After this time, the token will no longer be valid and the user will need to log in again to obtain a new token.
    /// </summary>
    public DateTime Expiration { get; set; }

    /// <summary>   
    /// The username of the authenticated user.
    /// </summary>
    public string Username { get; set; } = string.Empty;

    /// <summary>
    /// The email of the authenticated user.
    /// </summary>
    public string Email { get; set; } = string.Empty;

    public string FirstName { get; set; } = string.Empty;

    public string LastName { get; set; } = string.Empty;

}