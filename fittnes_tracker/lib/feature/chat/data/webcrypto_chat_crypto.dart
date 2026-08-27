import 'dart:convert';
import 'dart:typed_data';

import 'package:webcrypto/webcrypto.dart';

import 'package:ForgeForm/feature/chat/data/chat_key_store.dart';
import 'package:ForgeForm/feature/chat/domain/chat_crypto.dart';

/// ECDH P-256 + AES-256-GCM, over the `webcrypto` package.
///
/// The shared secret is derived from this device's private key and the other
/// party's public key. Both sides derive the same 32 bytes from opposite
/// halves, which is why nothing has to be encrypted twice: the sender can read
/// their own messages back without a second copy encrypted to themselves.
class WebCryptoChatCrypto implements ChatCrypto {
  /// 96 bits — the IV length AES-GCM is specified for.
  ///
  /// Any other length is accepted by the implementation and quietly weaker,
  /// because GCM has to hash a non-96-bit IV down to 96 bits first. Nothing
  /// fails, nothing warns, and every message still decrypts.
  static const _ivLength = 12;

  final ChatKeyStore _keys;

  /// Derived keys, per conversation partner.
  ///
  /// Cached because deriving is an elliptic-curve operation and a thread asks
  /// for one per bubble — fifty on the first paint of a conversation.
  final Map<String, AesGcmSecretKey> _shared = {};

  WebCryptoChatCrypto({required ChatKeyStore keys}) : _keys = keys;

  @override
  Future<EncryptedBody> encrypt({
    required String otherPartyId,
    required String plaintext,
  }) async {
    final key = await _sharedKey(otherPartyId);

    final iv = Uint8List(_ivLength);
    fillRandomBytes(iv);

    final ciphertext = await key.encryptBytes(utf8.encode(plaintext), iv);

    return EncryptedBody(
      ciphertext: base64Encode(ciphertext),
      iv: base64Encode(iv),
      version: ChatEncryption.ecdhP256AesGcm,
    );
  }

  @override
  Future<String?> decrypt({
    required String otherPartyId,
    required String? ciphertext,
    required String? iv,
    required int version,
  }) async {
    if (ciphertext == null) return null;

    // Written before encryption existed, so the "ciphertext" is the message.
    if (version == ChatEncryption.none) return ciphertext;

    if (version != ChatEncryption.ecdhP256AesGcm || iv == null) return null;

    try {
      final key = await _sharedKey(otherPartyId);
      final plaintext = await key.decryptBytes(
        base64Decode(ciphertext),
        base64Decode(iv),
      );
      return utf8.decode(plaintext);
    } catch (_) {
      // Every failure lands here and every one of them means the same thing to
      // the reader: this device cannot read this message. A rotated peer key, a
      // reinstall, a truncated payload, a tag that does not verify -- telling
      // them apart would let an attacker learn which, and there is nothing
      // different to do about any of them.
      return null;
    }
  }

  @override
  Future<void> forget(String otherPartyId) async {
    // Both layers, always. Dropping the derived secret while leaving the stale
    // public key behind re-derives the identical useless secret on the next
    // call, which is a cache invalidation that looks like it worked.
    _shared.remove(otherPartyId);
    await _keys.forgetPeer(otherPartyId);
  }

  Future<AesGcmSecretKey> _sharedKey(String otherPartyId) async {
    final cached = _shared[otherPartyId];
    if (cached != null) return cached;

    final mine = await _keys.identityKey();
    final theirs = await _keys.peerKey(otherPartyId);

    // 256 bits straight into the AES key, which is what the guide this follows
    // does. A KDF over the derived bits would be the textbook step here; see
    // docs/chat-encryption.md for why it is not taken and what taking it later
    // would cost.
    final bits = await mine.deriveBits(256, theirs);

    return _shared[otherPartyId] = await AesGcmSecretKey.importRawKey(bits);
  }
}
