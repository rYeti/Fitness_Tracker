namespace FitTracker.Api.DTOs;

/// <summary>What a caller sends when publishing one device's public key.</summary>
public class PublishChatKeyRequestDto
{
    /// <summary>This install's own id — see docs/chat-encryption.md for why it is not a user id.</summary>
    public string DeviceId { get; set; } = string.Empty;

    /// <summary>The public half of this device's ECDH key pair, as a JSON Web Key.</summary>
    public string PublicKeyJwk { get; set; } = string.Empty;
}

/// <summary>One registered device and its published public key.</summary>
public class ChatDeviceKeyDto
{
    public string DeviceId { get; set; } = string.Empty;

    public string PublicKeyJwk { get; set; } = string.Empty;
}

/// <summary>One party's registered devices, and who they belong to.</summary>
/// <remarks>
/// <see cref="Devices"/> is empty rather than the response being 404 when the
/// <c>me</c> route is asked before this account has published anything — that
/// is an ordinary state, not an error, and the client reads it as "generate and
/// publish one," not as a failure.
/// </remarks>
public class ChatKeyDto
{
    public Guid UserId { get; set; }

    public List<ChatDeviceKeyDto> Devices { get; set; } = [];
}
