import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/feature/chat/data/webcrypto_attachment_crypto.dart';

/// Exercises the real AES-256-GCM path, not a fake — mirrors
/// `chat_crypto_test.dart`'s reasoning: every other attachment test runs
/// against `FakeAttachmentCrypto`, so this is the only place the actual
/// primitive is checked.
void main() {
  late WebCryptoAttachmentCrypto crypto;

  setUp(() {
    crypto = WebCryptoAttachmentCrypto();
  });

  test('seal then open recovers the original plaintext', () async {
    final plaintext = Uint8List.fromList(List.generate(1024, (i) => i % 256));

    final sealed = await crypto.seal(plaintext);
    final opened = await crypto.open(sealed.ciphertext, key: sealed.key, iv: sealed.iv);

    expect(opened, plaintext);
  });

  test('each seal uses a fresh random key', () async {
    final plaintext = Uint8List.fromList([1, 2, 3]);

    final first = await crypto.seal(plaintext);
    final second = await crypto.seal(plaintext);

    expect(first.key, isNot(equals(second.key)));
    expect(first.iv, isNot(equals(second.iv)));
    // Different keys mean different ciphertext for the same plaintext, even
    // before considering the IV.
    expect(first.ciphertext, isNot(equals(second.ciphertext)));
  });

  test('a flipped ciphertext byte fails to open', () async {
    final sealed = await crypto.seal(Uint8List.fromList([9, 9, 9]));
    final tampered = Uint8List.fromList(sealed.ciphertext);
    tampered[0] ^= 0xFF;

    final opened = await crypto.open(tampered, key: sealed.key, iv: sealed.iv);

    expect(opened, isNull);
  });

  test('the wrong key fails to open rather than returning garbage', () async {
    final sealed = await crypto.seal(Uint8List.fromList([1, 2, 3]));
    final wrongKey = Uint8List(32);

    final opened = await crypto.open(sealed.ciphertext, key: wrongKey, iv: sealed.iv);

    expect(opened, isNull);
  });

  test('a truncated ciphertext fails to open', () async {
    final sealed = await crypto.seal(Uint8List.fromList(List.filled(64, 7)));
    final truncated = sealed.ciphertext.sublist(0, sealed.ciphertext.length - 4);

    final opened = await crypto.open(truncated, key: sealed.key, iv: sealed.iv);

    expect(opened, isNull);
  });
}
