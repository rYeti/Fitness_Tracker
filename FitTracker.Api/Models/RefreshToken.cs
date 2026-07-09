namespace FitTracker.Api.Models;

public class RefreshToken
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public User User { get; set; } = null!;

    /// <summary>SHA-256 hash of the raw token — the raw value is only ever returned to the client, never stored.</summary>
    public string TokenHash { get; set; } = string.Empty;
    public DateTime ExpiresAt { get; set; }
    public DateTime? RevokedAt { get; set; }

    /// <summary>Set when this token was rotated out in favor of a newer one — lets a reused/revoked token be detected as a compromise signal.</summary>
    public Guid? ReplacedByTokenId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
