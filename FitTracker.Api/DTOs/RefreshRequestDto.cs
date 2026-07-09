namespace FitTracker.Api.DTOs;

/// <summary>Request payload for refreshing an access token or revoking a session on logout.</summary>
public class RefreshRequestDto
{
    public string RefreshToken { get; set; } = string.Empty;
}
