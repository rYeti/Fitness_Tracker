using FitTracker.Api.Models;

namespace FitTracker.Api.DTOs;

/// <summary>What a caller sends when publishing their public key.</summary>
public class PublishChatKeyRequestDto
{
    /// <summary>The public half of the caller's ECDH key pair, as a JSON Web Key.</summary>
    public string PublicKeyJwk { get; set; } = string.Empty;

    /// <summary>
    /// This install's own id. Null for a client built before multi-device
    /// keys existed, which implicitly publishes under
    /// <see cref="UserChatKey.LegacyDeviceId"/> instead — see that
    /// constant's own remarks, and docs/chat-multi-device-keys.md.
    /// </summary>
    public string? DeviceId { get; set; }
}

/// <summary>One device's published key, as it appears inside <see cref="ChatKeyDto.Devices"/>.</summary>
public class ChatKeyDeviceDto
{
    public string DeviceId { get; set; } = string.Empty;

    public string PublicKeyJwk { get; set; } = string.Empty;
}

/// <summary>One party's published chat key(s), and who they belong to.</summary>
/// <remarks>
/// <para>
/// <see cref="PublicKeyJwk"/> carries the *most-recently-seen* device's key —
/// exactly the single value this DTO always carried, before any device
/// existed to distinguish. A client built before this change reads only that
/// field and behaves exactly as it always did, encrypting to (or checking
/// itself against) whichever device most recently confirmed itself present.
/// It is null on the <c>me</c> route when the caller has never published any
/// key at all. That is an ordinary state — a device that has not opened chat
/// since encryption shipped — and the client reads it as "generate one," not
/// as an error.
/// </para>
/// <para>
/// <see cref="Devices"/> is the field a client that knows about multi-device
/// keys actually uses: every currently-published device for this user, so a
/// sender can wrap a message's content key for each of them, and a device can
/// tell whether its own id is still among them. Empty wherever
/// <see cref="PublicKeyJwk"/> is null.
/// </para>
/// </remarks>
public class ChatKeyDto
{
    public Guid UserId { get; set; }

    public string? PublicKeyJwk { get; set; }

    public List<ChatKeyDeviceDto> Devices { get; set; } = [];
}
