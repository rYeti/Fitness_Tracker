import 'dart:convert';
import 'dart:typed_data';

import 'package:webcrypto/webcrypto.dart';

import 'package:ForgeForm/feature/chat/data/chat_key_store.dart';
import 'package:ForgeForm/feature/chat/domain/chat_crypto.dart';

/// ECDH P-256 + AES-256-GCM, over the `webcrypto` package.
///
/// Two schemes live here side by side. [ChatEncryption.ecdhP256AesGcm] (v1)
/// derives one shared secret from this device's identity key and the peer's —
/// both sides derive the same 32 bytes from opposite halves, so a message is
/// encrypted once and both can read it, with no separate copy for the sender.
/// That was also its defect: "the peer's key" only means anything when each
/// account has exactly one, and see docs/chat-encryption.md for what a second
/// device cost under that assumption.
///
/// [ChatEncryption.ecdhP256AesGcmPerDevice] (v2) replaces the shared secret
/// with a random per-message content key, wrapped once per target device —
/// every device of both parties, sender's own included — under a secret
/// derived from a fresh ephemeral key pair and that device's public key. A
/// reader needs no cached peer key at all: only its own identity key and the
/// message's own ephemeral public key.
class WebCryptoChatCrypto implements ChatCrypto {
  /// 96 bits — the IV length AES-GCM is specified for.
  ///
  /// Any other length is accepted by the implementation and quietly weaker,
  /// because GCM has to hash a non-96-bit IV down to 96 bits first. Nothing
  /// fails, nothing warns, and every message still decrypts.
  static const _ivLength = 12;

  /// AES-256 content and wrap keys are 32 raw bytes.
  static const _keyLength = 32;

  final ChatKeyStore _keys;

  /// Derived v1 shared keys, per conversation partner. Version 2 has nothing
  /// to cache here — every message carries its own ephemeral key, so there is
  /// no per-partner secret that outlives one message.
  final Map<String, AesGcmSecretKey> _shared = {};

  WebCryptoChatCrypto({required ChatKeyStore keys}) : _keys = keys;

  @override
  Future<EncryptedBody> encrypt({
    required String otherPartyId,
    required String plaintext,
  }) async {
    final targets = await _keys.targetDevices(otherPartyId);
    if (targets.isEmpty) {
      throw StateError('$otherPartyId has no registered devices.');
    }

    final contentKeyBytes = Uint8List(_keyLength);
    fillRandomBytes(contentKeyBytes);
    final contentKey = await AesGcmSecretKey.importRawKey(contentKeyBytes);

    final bodyIv = Uint8List(_ivLength);
    fillRandomBytes(bodyIv);
    final ciphertext = await contentKey.encryptBytes(
      utf8.encode(plaintext),
      bodyIv,
    );

    // One ephemeral pair per message, never reused and never stored anywhere
    // but this call — it exists only to derive the wrap keys below.
    final ephemeral = await EcdhPrivateKey.generateKey(EllipticCurve.p256);
    final ephemeralPublicJwk = jsonEncode(
      await ephemeral.publicKey.exportJsonWebKey(),
    );

    final wraps = <WrappedKey>[];
    for (final device in targets) {
      final devicePublic = await EcdhPublicKey.importJsonWebKey(
        jsonDecode(device.publicKeyJwk) as Map<String, dynamic>,
        EllipticCurve.p256,
      );

      // Same derivation the v1 scheme already used — raw ECDH bits straight
      // into the AES key, no separate KDF pass. See docs/chat-encryption.md
      // for why that gap is accepted for a fresh key pair used exactly once.
      final bits = await ephemeral.privateKey.deriveBits(
        _keyLength * 8,
        devicePublic,
      );
      final wrapKey = await AesGcmSecretKey.importRawKey(bits);

      final wrapIv = Uint8List(_ivLength);
      fillRandomBytes(wrapIv);
      final wrapped = await wrapKey.encryptBytes(contentKeyBytes, wrapIv);

      wraps.add(
        WrappedKey(
          deviceId: device.deviceId,
          key: base64Encode(wrapped),
          iv: base64Encode(wrapIv),
        ),
      );
    }

    return EncryptedBody(
      ciphertext: base64Encode(ciphertext),
      iv: base64Encode(bodyIv),
      version: ChatEncryption.ecdhP256AesGcmPerDevice,
      ephemeralPublicKeyJwk: ephemeralPublicJwk,
      keys: wraps,
    );
  }

  @override
  Future<String?> decrypt({
    required String otherPartyId,
    required String? ciphertext,
    required String? iv,
    required int version,
    String? ephemeralPublicKeyJwk,
    String? wrappedKey,
    String? wrappedKeyIv,
  }) async {
    if (ciphertext == null) return null;

    // Written before encryption existed, so the "ciphertext" is the message.
    if (version == ChatEncryption.none) return ciphertext;

    if (version == ChatEncryption.ecdhP256AesGcm) {
      return _decryptV1(otherPartyId: otherPartyId, ciphertext: ciphertext, iv: iv);
    }

    if (version != ChatEncryption.ecdhP256AesGcmPerDevice) return null;

    // No wrapped key for this device is not malformed input — it is the
    // ordinary shape of "this message predates this device."
    if (iv == null ||
        ephemeralPublicKeyJwk == null ||
        wrappedKey == null ||
        wrappedKeyIv == null) {
      return null;
    }

    try {
      final mine = await _keys.identityKey();
      final epk = await EcdhPublicKey.importJsonWebKey(
        jsonDecode(ephemeralPublicKeyJwk) as Map<String, dynamic>,
        EllipticCurve.p256,
      );

      final bits = await mine.deriveBits(_keyLength * 8, epk);
      final wrapAesKey = await AesGcmSecretKey.importRawKey(bits);

      final contentKeyBytes = await wrapAesKey.decryptBytes(
        base64Decode(wrappedKey),
        base64Decode(wrappedKeyIv),
      );
      final contentKey = await AesGcmSecretKey.importRawKey(contentKeyBytes);

      final plaintext = await contentKey.decryptBytes(
        base64Decode(ciphertext),
        base64Decode(iv),
      );
      return utf8.decode(plaintext);
    } catch (_) {
      // Every failure lands here and every one of them means the same thing to
      // the reader: this device cannot read this message. A malformed epk, a
      // tampered wrap, a tag that does not verify -- telling them apart would
      // let an attacker learn which, and there is nothing different to do
      // about any of them.
      return null;
    }
  }

  Future<String?> _decryptV1({
    required String otherPartyId,
    required String ciphertext,
    required String? iv,
  }) async {
    if (iv == null) return null;

    try {
      final key = await _sharedKey(otherPartyId);
      final plaintext = await key.decryptBytes(
        base64Decode(ciphertext),
        base64Decode(iv),
      );
      return utf8.decode(plaintext);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> deviceId() => _keys.deviceId();

  @override
  Future<void> forget(String otherPartyId) async {
    // Both layers, always. Dropping the derived secret while leaving the stale
    // public key behind re-derives the identical useless secret on the next
    // call, which is a cache invalidation that looks like it worked.
    _shared.remove(otherPartyId);
    await _keys.forgetPeer(otherPartyId);
    _keys.forgetDevices(otherPartyId);
  }

  Future<AesGcmSecretKey> _sharedKey(String otherPartyId) async {
    final cached = _shared[otherPartyId];
    if (cached != null) return cached;

    final mine = await _keys.identityKey();
    final theirs = await _keys.peerKey(otherPartyId);

    // 256 bits straight into the AES key, which is what the guide this follows
    // does. A KDF over the derived bits would be the textbook step here; see
    // docs/chat-encryption.md for why it is not taken and what taking it later
    // would cost. Kept exactly as it was for v1 — this path only ever reads
    // messages sent before a device moved to per-device keys, so changing it
    // now would make them unreadable rather than more readable.
    final bits = await mine.deriveBits(_keyLength * 8, theirs);

    return _shared[otherPartyId] = await AesGcmSecretKey.importRawKey(bits);
  }
}
