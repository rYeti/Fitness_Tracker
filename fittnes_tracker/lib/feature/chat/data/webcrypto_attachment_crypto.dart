import 'dart:typed_data';

import 'package:webcrypto/webcrypto.dart';

import 'package:ForgeForm/feature/chat/domain/attachment_crypto.dart';

/// AES-256-GCM over `webcrypto` — the same primitive [WebCryptoChatCrypto]
/// uses for message bodies, applied to a random per-attachment key instead of
/// an ECDH-derived one. No key store, no peer: see [AttachmentCrypto]'s own
/// doc comment for why this stays a separate class rather than a second pair
/// of methods there.
class WebCryptoAttachmentCrypto implements AttachmentCrypto {
  /// 96 bits, matching [WebCryptoChatCrypto] — see that class's own comment
  /// on why any other length is quietly accepted and quietly weaker.
  static const _ivLength = 12;
  static const _keyLength = 32;

  @override
  Future<SealedAttachment> seal(Uint8List plaintext) async {
    final keyBytes = Uint8List(_keyLength);
    fillRandomBytes(keyBytes);
    final key = await AesGcmSecretKey.importRawKey(keyBytes);

    final iv = Uint8List(_ivLength);
    fillRandomBytes(iv);

    final ciphertext = await key.encryptBytes(plaintext, iv);

    return SealedAttachment(
      ciphertext: Uint8List.fromList(ciphertext),
      key: keyBytes,
      iv: iv,
    );
  }

  @override
  Future<Uint8List?> open(Uint8List ciphertext, {required Uint8List key, required Uint8List iv}) async {
    try {
      final secretKey = await AesGcmSecretKey.importRawKey(key);
      final plaintext = await secretKey.decryptBytes(ciphertext, iv);
      return Uint8List.fromList(plaintext);
    } catch (_) {
      // A GCM tag that doesn't verify, a truncated transfer, a key that
      // doesn't match — all the same signal to the caller: this download is
      // unusable, and it's the same bytes that would need re-fetching either
      // way, so nothing is lost by not distinguishing further here.
      return null;
    }
  }
}
