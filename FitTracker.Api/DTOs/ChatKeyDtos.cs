namespace FitTracker.Api.DTOs;

/// <summary>What a caller sends when publishing their public key.</summary>
public class PublishChatKeyRequestDto
{
    /// <summary>The public half of the caller's ECDH key pair, as a JSON Web Key.</summary>
    public string PublicKeyJwk { get; set; } = string.Empty;
}

/// <summary>One party's published chat key, and who it belongs to.</summary>
/// <remarks>
/// <see cref="PublicKeyJwk"/> is null on the <c>me</c> route when the caller has
/// never published one. That is an ordinary state — a device that has not opened
/// chat since encryption shipped — and the client reads it as "generate one",
/// not as an error.
/// </remarks>
public class ChatKeyDto
{
    public Guid UserId { get; set; }

    public string? PublicKeyJwk { get; set; }
}
