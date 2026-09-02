namespace FitTracker.Api.Models;

/// <summary>
/// One device's published ECDH public key — the half of that device's chat
/// identity the server is allowed to know.
/// </summary>
/// <remarks>
/// <para>
/// The matching private key never reaches this server. It is generated on the
/// device, written to the platform keystore, and has no backup: that is what
/// makes a message body this device has no key for unreadable here rather than
/// merely inconvenient to read.
/// </para>
/// <para>
/// One row per (user, device), not per user. A user signed into the Trainer
/// Console on a phone and a desktop has two rows here, and a message is
/// encrypted once and wrapped once per row — see <see cref="ChatMessageKey"/>
/// and docs/chat-encryption.md. Replacing the single-key-per-user row on every
/// new install used to be exactly what made a second device destroy a user's
/// own message history; this table exists so registering a device is additive.
/// </para>
/// <para>
/// <see cref="DeviceId"/> is client-generated and opaque to this server — an
/// install's own identifier, not tied to any push token, which is documented as
/// rotatable (see <c>DeviceToken</c>) and therefore unfit to key key material by.
/// </para>
/// </remarks>
public class UserChatDeviceKey
{
    public Guid UserId { get; set; }

    public User User { get; set; } = null!;

    /// <summary>This install's own id, minted once on the client and never reused across accounts on the same install... except it is: see docs/chat-encryption.md for why the device id survives an account switch while the key pair does not.</summary>
    public string DeviceId { get; set; } = string.Empty;

    /// <summary>The public key as a JSON Web Key, stored verbatim as the client exported it.</summary>
    public string PublicKeyJwk { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>Bumped on every re-registration. Also what a prune keeps the most recent of, per user.</summary>
    public DateTime LastSeenAt { get; set; } = DateTime.UtcNow;
}
