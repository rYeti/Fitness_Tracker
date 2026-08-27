namespace FitTracker.Api.Models;

/// <summary>
/// One user's published ECDH public key — the half of their chat identity the
/// server is allowed to know.
/// </summary>
/// <remarks>
/// <para>
/// The matching private key never reaches this server. It is generated on the
/// device, written to the platform keystore, and has no backup: that is what
/// makes the message bodies in <see cref="ChatMessage"/> unreadable here rather
/// than merely inconvenient to read.
/// </para>
/// <para>
/// One row per user, overwritten on re-registration. A device that reinstalls
/// generates a fresh pair and replaces this row, which is precisely why the
/// messages it sent before the reinstall can no longer be decrypted by anyone.
/// See docs/chat-encryption.md.
/// </para>
/// <para>
/// Note what this table means for the threat model: the server hands out these
/// keys, so a hostile server could hand out its own and read everything. That
/// is a known, documented limit of this design, not an oversight.
/// </para>
/// </remarks>
public class UserChatKey
{
    /// <summary>The owner. Also the primary key — a user has exactly one current chat key.</summary>
    public Guid UserId { get; set; }

    public User User { get; set; } = null!;

    /// <summary>The public key as a JSON Web Key, stored verbatim as the client exported it.</summary>
    /// <remarks>
    /// Kept as opaque text rather than parsed into columns. The server never
    /// does anything with the contents except hand them back, and a schema that
    /// understood the format would have to be migrated the first time the curve
    /// changed.
    /// </remarks>
    public string PublicKeyJwk { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>Bumped on every re-registration, so a key that suddenly changed is findable.</summary>
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
