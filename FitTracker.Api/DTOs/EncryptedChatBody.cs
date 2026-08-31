namespace FitTracker.Api.DTOs;

/// <summary>
/// A message body as it crosses this server: three values that only mean
/// something together.
/// </summary>
/// <param name="Ciphertext">
/// Base64 of the AES-256-GCM ciphertext when <paramref name="EncryptionVersion"/>
/// is 1, or the plaintext itself when it is 0. Either way, opaque here.
/// </param>
/// <param name="Iv">The base64 IV, or null for a version-0 body.</param>
/// <param name="EncryptionVersion">0 = plaintext (legacy), 1 = ECDH P-256 + AES-256-GCM.</param>
/// <remarks>
/// Grouped into one type rather than passed as three loose parameters because
/// they are never individually meaningful and must never be separated: a
/// ciphertext that loses its IV is unreadable, and one that loses its version
/// is worse — it looks exactly like plaintext to anything that guesses.
/// </remarks>
public record EncryptedChatBody(string? Ciphertext, string? Iv, int EncryptionVersion);
