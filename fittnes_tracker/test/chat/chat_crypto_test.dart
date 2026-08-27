import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/feature/chat/data/chat_key_store.dart';
import 'package:ForgeForm/feature/chat/data/webcrypto_chat_crypto.dart';
import 'package:ForgeForm/feature/chat/domain/chat_crypto.dart';

import 'fakes.dart';

/// Exercises the real ECDH + AES-GCM path, not a fake.
///
/// Everything else in `test/chat/` runs against [FakeChatCrypto] on purpose, so
/// this is the only place the actual algorithm is checked — and the only place
/// that would notice if `deriveBits` were called with the wrong curve, or an IV
/// were reused, or a failed authentication tag surfaced as a thrown exception
/// instead of a null.
void main() {
  const alice = '11111111-1111-1111-1111-111111111111';
  const bob = '22222222-2222-2222-2222-222222222222';

  /// Two key stores that know about each other, as two devices would after both
  /// have published and each has fetched the other's key.
  Future<(WebCryptoChatCrypto, WebCryptoChatCrypto)> pair() async {
    final aliceVault = InMemoryChatKeyVault();
    final bobVault = InMemoryChatKeyVault();

    final aliceKeys = ChatKeyStore(
      vault: aliceVault,
      api: FakeChatKeyApi(userId: alice),
    );
    final bobKeys = ChatKeyStore(
      vault: bobVault,
      api: FakeChatKeyApi(userId: bob),
    );

    await aliceKeys.ensureRegistered();
    await bobKeys.ensureRegistered();

    // Each side caches the other's published public key.
    aliceVault.entries['${ChatKeyStore.peerKeyPrefix}$bob'] =
        bobVault.entries[ChatKeyStore.identityPublicEntry]!;
    bobVault.entries['${ChatKeyStore.peerKeyPrefix}$alice'] =
        aliceVault.entries[ChatKeyStore.identityPublicEntry]!;

    return (
      WebCryptoChatCrypto(keys: aliceKeys),
      WebCryptoChatCrypto(keys: bobKeys),
    );
  }

  test('a message encrypted by one side decrypts on the other', () async {
    final (aliceCrypto, bobCrypto) = await pair();

    final sealed = await aliceCrypto.encrypt(
      otherPartyId: bob,
      plaintext: 'great set today',
    );

    final plaintext = await bobCrypto.decrypt(
      otherPartyId: alice,
      ciphertext: sealed.ciphertext,
      iv: sealed.iv,
      version: sealed.version,
    );

    expect(plaintext, 'great set today');
  });

  test('the sender can read their own message back', () async {
    // Not a nicety — it is what makes a second copy encrypted to yourself
    // unnecessary. Both sides derive the same secret from opposite halves, so
    // the sender's own thread renders from the same ciphertext the recipient
    // reads.
    final (aliceCrypto, _) = await pair();

    final sealed = await aliceCrypto.encrypt(
      otherPartyId: bob,
      plaintext: 'see you thursday',
    );

    expect(
      await aliceCrypto.decrypt(
        otherPartyId: bob,
        ciphertext: sealed.ciphertext,
        iv: sealed.iv,
        version: sealed.version,
      ),
      'see you thursday',
    );
  });

  test('the same plaintext twice produces a different IV and ciphertext', () async {
    // An IV reused under one AES-GCM key is a total break, not a weakening, and
    // it is invisible: both messages still decrypt perfectly.
    final (aliceCrypto, _) = await pair();

    final first = await aliceCrypto.encrypt(otherPartyId: bob, plaintext: 'ok');
    final second = await aliceCrypto.encrypt(otherPartyId: bob, plaintext: 'ok');

    expect(first.iv, isNot(second.iv));
    expect(first.ciphertext, isNot(second.ciphertext));
  });

  test('the ciphertext does not contain the plaintext', () async {
    final (aliceCrypto, _) = await pair();

    final sealed = await aliceCrypto.encrypt(
      otherPartyId: bob,
      plaintext: 'confidential',
    );

    expect(sealed.ciphertext, isNot(contains('confidential')));
    expect(
      utf8.decode(base64Decode(sealed.ciphertext), allowMalformed: true),
      isNot(contains('confidential')),
    );
  });

  test('an unrelated key pair decrypts to null rather than throwing', () async {
    final (aliceCrypto, _) = await pair();
    final (_, strangerCrypto) = await pair();

    final sealed = await aliceCrypto.encrypt(
      otherPartyId: bob,
      plaintext: 'not for you',
    );

    // Null, not an exception. `loadThread` maps over a whole history, so a throw
    // halfway down it is an empty conversation rather than one unreadable line.
    expect(
      await strangerCrypto.decrypt(
        otherPartyId: alice,
        ciphertext: sealed.ciphertext,
        iv: sealed.iv,
        version: sealed.version,
      ),
      isNull,
    );
  });

  test('a tampered ciphertext decrypts to null', () async {
    final (aliceCrypto, bobCrypto) = await pair();

    final sealed = await aliceCrypto.encrypt(
      otherPartyId: bob,
      plaintext: 'transfer approved',
    );

    final bytes = base64Decode(sealed.ciphertext);
    bytes[0] ^= 0xFF;

    expect(
      await bobCrypto.decrypt(
        otherPartyId: alice,
        ciphertext: base64Encode(bytes),
        iv: sealed.iv,
        version: sealed.version,
      ),
      isNull,
    );
  });

  test('a version-0 body passes through untouched', () async {
    // Every message written before encryption existed. There is no key for
    // these and never will be; the body simply is the message.
    final (_, bobCrypto) = await pair();

    expect(
      await bobCrypto.decrypt(
        otherPartyId: alice,
        ciphertext: 'written in 2026',
        iv: null,
        version: ChatEncryption.none,
      ),
      'written in 2026',
    );
  });

  test('an encrypted body with no IV decrypts to null', () async {
    final (_, bobCrypto) = await pair();

    expect(
      await bobCrypto.decrypt(
        otherPartyId: alice,
        ciphertext: 'AAAA',
        iv: null,
        version: ChatEncryption.ecdhP256AesGcm,
      ),
      isNull,
    );
  });

  test('a null body decrypts to null at any version', () async {
    final (_, bobCrypto) = await pair();

    expect(
      await bobCrypto.decrypt(
        otherPartyId: alice,
        ciphertext: null,
        iv: null,
        version: ChatEncryption.none,
      ),
      isNull,
    );
  });
}
