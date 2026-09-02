namespace FitTracker.Api.DTOs;

/// <summary>One device's wrapped copy of a message's content key.</summary>
/// <param name="DeviceId">Whose device this wraps the content key for.</param>
/// <param name="WrappedKey">Base64 AES-256-GCM ciphertext of the content key.</param>
/// <param name="WrappedIv">Base64 IV <paramref name="WrappedKey"/> was wrapped under.</param>
public record ChatMessageKeyDto(string DeviceId, string WrappedKey, string WrappedIv);

/// <summary>
/// A message body as it crosses this server: the values that only mean
/// something together.
/// </summary>
/// <param name="Ciphertext">
/// Base64 of the AES-256-GCM ciphertext when <paramref name="EncryptionVersion"/>
/// is 1 or 2, or the plaintext itself when it is 0. Either way, opaque here.
/// </param>
/// <param name="Iv">The base64 IV the body itself was encrypted under, or null for a version-0 body.</param>
/// <param name="EncryptionVersion">0 = plaintext (legacy), 1 = pairwise ECDH P-256 + AES-256-GCM (single account key), 2 = per-device ECDH P-256 + AES-256-GCM with a wrapped content key per device.</param>
/// <param name="EphemeralPublicKeyJwk">
/// The message's own ephemeral ECDH public key. Present only for version 2 —
/// every device unwraps its copy of the content key against this, never
/// against the sender's or recipient's long-lived identity key.
/// </param>
/// <param name="Keys">
/// One wrapped copy of the content key per target device — every device of
/// both parties, the sender's own included. Empty for versions 0 and 1.
/// </param>
/// <remarks>
/// Grouped into one type rather than passed as loose parameters because these
/// values are never individually meaningful and must never be separated: a
/// ciphertext that loses its IV is unreadable, one that loses its version is
/// worse — it looks exactly like plaintext to anything that guesses — and a
/// version-2 body with no wrapped key for a given device is unreadable on
/// exactly that device, which is the ordinary, expected shape of "this message
/// predates that device" rather than a bug.
/// </remarks>
public record EncryptedChatBody(
    string? Ciphertext,
    string? Iv,
    int EncryptionVersion,
    string? EphemeralPublicKeyJwk = null,
    IReadOnlyList<ChatMessageKeyDto>? Keys = null);
