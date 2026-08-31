/// The encryption boundary for chat message bodies.
///
/// Everything above this line deals in plaintext; everything below it deals in
/// an opaque blob the server stores and forwards without being able to read.
/// See docs/chat-encryption.md for why the boundary sits exactly here.
library;

/// How a stored body was protected.
///
/// The number travels with every message rather than being inferred from
/// "is there an IV?", because the day a second scheme exists, guessing is how
/// the old one gets decrypted with the new one's rules.
class ChatEncryption {
  ChatEncryption._();

  /// Written before end-to-end encryption existed. The body *is* the plaintext.
  ///
  /// These rows are not backfilled and never can be: the server cannot encrypt
  /// what it was never given a key for. They stay readable, and stay marked.
  static const int none = 0;

  /// ECDH P-256 shared secret, AES-256-GCM, fresh IV per message.
  static const int ecdhP256AesGcm = 1;
}

/// One encrypted body, split the way the wire carries it.
class EncryptedBody {
  /// Base64 of the AES-GCM ciphertext, tag included.
  final String ciphertext;

  /// Base64 of the 12-byte IV this message was encrypted under. Never reused.
  final String iv;

  final int version;

  const EncryptedBody({
    required this.ciphertext,
    required this.iv,
    required this.version,
  });
}

/// Encrypts and decrypts message bodies for one conversation partner.
///
/// Kept as an interface for the same reason `ChatSignalRClient` is one: the
/// states that matter here — a peer whose key has rotated, a body encrypted
/// under a key this device no longer holds, a truncated ciphertext — cannot be
/// staged against real key material on demand, but are one line each against a
/// fake.
abstract class ChatCrypto {
  /// Encrypts [plaintext] for the conversation with [otherPartyId].
  ///
  /// Throws if the peer has no published key. That is a real failure: sending a
  /// message nobody can read is worse than refusing to send it.
  Future<EncryptedBody> encrypt({
    required String otherPartyId,
    required String plaintext,
  });

  /// Decrypts one body, or returns null if this device cannot.
  ///
  /// **Null rather than throwing, on every failure path** — a wrong key, a
  /// rotated peer, malformed base64, a failed GCM tag. This mirrors
  /// `ChatTimestamps.parseInstant`: one unreadable message must cost one
  /// bubble, not the whole thread. `loadThread` maps over a list, and a throw
  /// halfway down it is an empty conversation.
  ///
  /// A [version] of [ChatEncryption.none] returns `ciphertext` unchanged; those
  /// bodies were always plaintext.
  Future<String?> decrypt({
    required String otherPartyId,
    required String? ciphertext,
    required String? iv,
    required int version,
  });

  /// Drops all cached key material for [otherPartyId] — the derived secret and
  /// the peer's stored public key both — so the next call re-fetches and
  /// re-derives from scratch.
  ///
  /// This is the recovery path for a peer who reinstalled: their published key
  /// changed, so everything they send now fails to decrypt against the one this
  /// device cached, and nothing improves until the cache is dropped.
  Future<void> forget(String otherPartyId);
}
