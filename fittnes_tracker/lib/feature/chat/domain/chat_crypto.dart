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

  /// ECDH P-256 shared secret between two **accounts'** single key pairs,
  /// AES-256-GCM, fresh IV per message.
  ///
  /// Superseded by [ecdhP256AesGcmPerDevice] because this scheme has exactly
  /// one key per account: a second device registering its own key silently
  /// replaced the first, which made every message either side had already
  /// sent or received unreadable everywhere. See docs/chat-encryption.md.
  /// Kept readable forever — it is never written again, but a message sent
  /// under it still decrypts.
  static const int ecdhP256AesGcm = 1;

  /// A random per-message content key, AES-256-GCM, wrapped once per target
  /// device — every device of both parties, the sender's own included —
  /// under a secret derived from the message's own ephemeral ECDH key pair
  /// and that device's public key.
  ///
  /// A reader needs nothing but its own private key, the message's ephemeral
  /// public key, and its own wrapped entry: no cached peer key, and no
  /// account-level "the" key to collide with a second device's. See
  /// docs/chat-encryption.md.
  static const int ecdhP256AesGcmPerDevice = 2;
}

/// One device's wrapped copy of a message's content key.
class WrappedKey {
  final String deviceId;

  /// Base64 AES-256-GCM ciphertext of the content key.
  final String key;

  /// Base64 IV [key] was wrapped under.
  final String iv;

  const WrappedKey({required this.deviceId, required this.key, required this.iv});
}

/// One encrypted body, split the way the wire carries it.
class EncryptedBody {
  /// Base64 of the AES-GCM ciphertext, tag included.
  final String ciphertext;

  /// Base64 of the 12-byte IV this message was encrypted under. Never reused.
  final String iv;

  final int version;

  /// The message's own ephemeral ECDH public key, as a JSON Web Key. Present
  /// only for [ChatEncryption.ecdhP256AesGcmPerDevice].
  final String? ephemeralPublicKeyJwk;

  /// One wrapped copy of the content key per target device. Empty for
  /// versions 0 and 1.
  final List<WrappedKey> keys;

  const EncryptedBody({
    required this.ciphertext,
    required this.iv,
    required this.version,
    this.ephemeralPublicKeyJwk,
    this.keys = const [],
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
  /// Encrypts [plaintext] for the conversation with [otherPartyId] — every
  /// device of both parties, so every one of them can read it back.
  ///
  /// Throws if there is nobody to encrypt to. That is a real failure: sending
  /// a message nobody can read is worse than refusing to send it.
  Future<EncryptedBody> encrypt({
    required String otherPartyId,
    required String plaintext,
  });

  /// Decrypts one body, or returns null if this device cannot.
  ///
  /// **Null rather than throwing, on every failure path** — a wrong key, a
  /// rotated peer, malformed base64, a failed GCM tag, or (new under version 2)
  /// simply no wrapped key for this device because the message predates it.
  /// This mirrors `ChatTimestamps.parseInstant`: one unreadable message must
  /// cost one bubble, not the whole thread. `loadThread` maps over a list, and
  /// a throw halfway down it is an empty conversation.
  ///
  /// A [version] of [ChatEncryption.none] returns `ciphertext` unchanged.
  /// [ephemeralPublicKeyJwk], [wrappedKey] and [wrappedKeyIv] apply only to
  /// [ChatEncryption.ecdhP256AesGcmPerDevice]; any of them missing there is
  /// read as "no wrapped key for this device", not an error.
  Future<String?> decrypt({
    required String otherPartyId,
    required String? ciphertext,
    required String? iv,
    required int version,
    String? ephemeralPublicKeyJwk,
    String? wrappedKey,
    String? wrappedKeyIv,
  });

  /// Drops all cached key material for [otherPartyId] — the derived secret and
  /// the peer's stored **legacy** public key both — so the next call re-fetches
  /// and re-derives from scratch.
  ///
  /// The recovery path for a peer who reinstalled under the old, single-key
  /// scheme. Version 2 has no equivalent failure: it caches no peer key, so
  /// there is nothing here for it to forget.
  Future<void> forget(String otherPartyId);

  /// This install's own id, or null if this crypto implementation has no
  /// concept of one.
  ///
  /// Lives here rather than being read straight off `ChatKeyStore` by
  /// `ChatRepository`, even though every real implementation just delegates to
  /// its own key store: this is the one property `ChatRepository` needs from
  /// key material on paths that otherwise never touch it in a test (sending,
  /// loading history, listing conversations, all of which use `FakeChatCrypto`
  /// there). Reaching past this interface for it would mean every one of those
  /// tests suddenly needed a working platform keystore just to fetch a device
  /// id nobody in the test cares about.
  Future<String?> deviceId();
}
