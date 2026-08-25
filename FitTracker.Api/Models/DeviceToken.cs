namespace FitTracker.Api.Models;

/// <summary>Which push transport a token belongs to.</summary>
/// <remarks>
/// Stored so the send path can tell FCM registration tokens apart from anything
/// added later. Only <see cref="Android"/> is issued today — iOS has never been
/// built in this repo (see docs/chat-architecture.md) — but a token with no
/// platform on it is unreadable the moment a second one exists.
/// </remarks>
public enum DevicePlatform
{
    Android = 0,
    IOs = 1,
    Web = 2
}

/// <summary>
/// One push destination: an FCM registration token belonging to one signed-in
/// user on one device.
/// </summary>
/// <remarks>
/// A user has as many rows here as they have devices, which is why the send path
/// fans out rather than looking up a single token.
/// <para>
/// The token — not the user — is the unique key. A registration token identifies
/// an app install, and an install can only be signed into one account at a time,
/// so when someone signs out and a colleague signs in on the same phone the row
/// has to <em>move</em>. Keyed by user instead, the old row would survive and
/// that phone would keep receiving the previous user's messages.
/// </para>
/// </remarks>
public class DeviceToken
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid UserId { get; set; }

    public User User { get; set; } = null!;

    /// <summary>The FCM registration token. Opaque, device-issued, and rotatable.</summary>
    public string Token { get; set; } = string.Empty;

    public DevicePlatform Platform { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Refreshed every time the client re-registers, so a stale row is
    /// identifiable. Nothing prunes on age yet; FCM rejecting a token is the
    /// signal that actually matters (see PushNotificationService).
    /// </summary>
    public DateTime LastSeenAt { get; set; } = DateTime.UtcNow;
}
