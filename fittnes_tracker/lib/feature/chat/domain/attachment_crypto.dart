import 'dart:typed_data';

/// One sealed attachment — a fresh random key, the IV it was sealed under,
/// and the resulting ciphertext.
class SealedAttachment {
  final Uint8List ciphertext;

  /// The 32-byte AES-256-GCM key, random and thrown away by the sender once
  /// it has travelled inside the encrypted message envelope. Independent of
  /// the ECDH conversation key — see docs/chat-attachments.md §B.1.
  final Uint8List key;

  /// The 12-byte IV.
  final Uint8List iv;

  const SealedAttachment({
    required this.ciphertext,
    required this.key,
    required this.iv,
  });
}

/// Encrypts and decrypts attachment bytes — separate from [ChatCrypto], and
/// deliberately so.
///
/// [ChatCrypto] is keyed by conversation partner and derives its secret from
/// an ECDH key store; sealing an attachment has no peer and no derivation —
/// the key is random per attachment and never stored anywhere but the
/// message envelope itself. One interface for both would mean every
/// implementation and every test fake carries key-store plumbing it never
/// uses.
///
/// The failure contract also differs, and that is the more important reason.
/// [ChatCrypto.decrypt] returns null on every failure because one bad row in
/// a mapped list must cost one bubble, never the whole thread. An attachment
/// failure is already scoped to one bubble and wants to stay
/// *distinguishable* — "the object is corrupt" and "the object never
/// arrived" lead to different UI (retry vs. don't) — so [open] is allowed to
/// distinguish what [ChatCrypto.decrypt] deliberately cannot.
abstract class AttachmentCrypto {
  /// Encrypts [plaintext] under a freshly generated key and IV.
  Future<SealedAttachment> seal(Uint8List plaintext);

  /// Decrypts [ciphertext] under the given [key] and [iv].
  ///
  /// Returns null only when the bytes fail to authenticate (wrong key,
  /// flipped bit, truncated transfer) — a corrupt-download signal the caller
  /// can offer to retry. A missing key or absent ciphertext is the caller's
  /// problem to check before calling this at all; this method assumes both
  /// are present and well-formed apart from their content.
  Future<Uint8List?> open(
    Uint8List ciphertext, {
    required Uint8List key,
    required Uint8List iv,
  });
}
