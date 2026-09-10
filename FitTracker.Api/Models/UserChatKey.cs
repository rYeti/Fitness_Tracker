namespace FitTracker.Api.Models;

/// <summary>
/// One device's published ECDH public key — the half of that install's chat
/// identity the server is allowed to know.
/// </summary>
/// <remarks>
/// <para>
/// The matching private key never reaches this server. It is generated on the
/// device, written to the platform keystore, and has no backup: that is what
/// makes the message bodies in <see cref="ChatMessage"/> unreadable here rather
/// than merely inconvenient to read.
/// </para>
/// <para>
/// One row per <em>device</em>, not per user — see docs/chat-multi-device-keys.md
/// for the incident that made this necessary: signing in on a second device used
/// to silently overwrite the first device's row, so the first device could no
/// longer read anything the second sent (including the user's own messages read
/// back on it), sending from the first device succeeded while being unreadable
/// by the peer, and the peer's own decryption-failure recovery path — built for
/// "the peer reinstalled," the only case anyone had considered — permanently
/// discarded its cached key for the *first* device the moment the second one
/// sent anything, taking the whole conversation's history with it.
/// </para>
/// <para>
/// <see cref="DeviceId"/>, not <see cref="UserId"/>, is what changes on a
/// reinstall now: a fresh install mints a fresh <see cref="DeviceId"/> and
/// therefore a fresh row, leaving any other device's row (and the messages
/// still readable through it) untouched. Re-registering the *same* device
/// (the ordinary "app relaunched, publish again" path) still replaces its own
/// key in place, for the same reason it always did — a reinstall on that
/// device has no way to recover its own previous private key either.
/// </para>
/// <para>
/// <see cref="LegacyDeviceId"/> is what a client built before device ids
/// existed publishes under, implicitly. It is one specific, well-known device
/// id rather than "no device id" as a distinct state, so every other part of
/// this table — the composite uniqueness, the seat cap, eviction — can treat
/// it as an ordinary row instead of a special case. Two separate pre-upgrade
/// installs for the same user still collide under it exactly as they did
/// before this table existed; this migration fixes multi-device going
/// forward, not retroactively for builds that predate it.
/// </para>
/// <para>
/// Note what this table means for the threat model: the server hands out these
/// keys, so a hostile server could hand out its own and read everything. That
/// is a known, documented limit of this design, not an oversight.
/// </para>
/// </remarks>
public class UserChatKey
{
    /// <summary>
    /// One well-known device id every client built before multi-device keys
    /// existed implicitly publishes under, since it sends no device id at all.
    /// </summary>
    public const string LegacyDeviceId = "00000000-0000-0000-0000-000000000000";

    /// <summary>
    /// A surrogate id, not <c>(UserId, DeviceId)</c> as the primary key —
    /// matching every other table in this schema, which uses a surrogate
    /// <c>Id</c> rather than a composite key. The one-row-per-device invariant
    /// is instead a unique index on <c>(UserId, DeviceId)</c> — see
    /// <c>AppDbContext</c>.
    /// </summary>
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid UserId { get; set; }

    public User User { get; set; } = null!;

    /// <summary>
    /// This install's own identifier, minted once and stored under a fixed
    /// vault entry on the client so the push background isolate can read it
    /// with no network — see `ChatKeyStore` and docs/chat-multi-device-keys.md.
    /// <see cref="LegacyDeviceId"/> for a client that predates this column.
    /// </summary>
    public string DeviceId { get; set; } = LegacyDeviceId;

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

    /// <summary>
    /// Bumped whenever this device confirms itself still current — every
    /// re-registration, not merely the first. What the per-user device cap's
    /// eviction sorts on: the least-recently-confirmed device is the one
    /// assumed gone, on the same reasoning `ChatAttachmentReaper` already uses
    /// for "nothing has touched this in a while" cleanup elsewhere in chat.
    /// </summary>
    public DateTime LastSeenAt { get; set; } = DateTime.UtcNow;
}
