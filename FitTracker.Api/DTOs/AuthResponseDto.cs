namespace FitTracker.Api.DTOs;

/// <summary>Response payload returned after a successful authentication or profile update.</summary>
public class AuthResponseDto
{
    /// <summary>
    /// The authenticated user's server id. The JWT already carries this as its
    /// <c>sub</c> claim, but nothing in the client decodes a JWT — this is the
    /// only place a stable, server-assigned identifier reaches the client
    /// (everything else on this DTO can change, including <see cref="Username"/>).
    /// Callers that need to identify this user to a *third* party (RevenueCat's
    /// <c>appUserID</c>, for one) must use this, not <see cref="Username"/>.
    /// </summary>
    public Guid Id { get; set; }

    /// <summary>
    /// JWT token that can be used for authenticated requests.
    /// </summary>
    public string Token { get; set; } = string.Empty;

    /// <summary>
    /// Expiration time of the JWT token. After this time, the token will no longer be valid and the user will need to log in again to obtain a new token.
    /// </summary>
    public DateTime Expiration { get; set; }

    /// <summary>
    /// Opaque token used to obtain a new access token via <c>POST api/Auth/refresh</c> without re-authenticating.
    /// </summary>
    public string RefreshToken { get; set; } = string.Empty;

    /// <summary>
    /// The username of the authenticated user.
    /// </summary>
    public string Username { get; set; } = string.Empty;

    /// <summary>
    /// The email of the authenticated user.
    /// </summary>
    public string Email { get; set; } = string.Empty;

    /// <summary>
    /// The first name of the authenticated user.
    /// </summary>
    public string FirstName { get; set; } = string.Empty;

    /// <summary>
    /// The last name of the authenticated user.
    /// </summary>
    public string LastName { get; set; } = string.Empty;

    /// <summary>
    /// The date of birth of the authenticated user.
    /// </summary>
    public DateTime DateOfBirth { get; set; }

    /// <summary>Optional URL of the user's profile image.</summary>
    public string? ProfileImageUrl { get; set; }

}