import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:webcrypto/webcrypto.dart';

import 'package:ForgeForm/feature/chat/data/chat_key_store.dart';
import 'package:ForgeForm/feature/chat/data/webcrypto_chat_crypto.dart';
import 'package:ForgeForm/feature/chat/domain/chat_crypto.dart';

import 'fakes.dart';

/// Exercises the real ECDH + AES-GCM path, not a fake.
///
/// Everything else in `test/chat/` runs against [FakeChatCrypto] on purpose, so
/// this is the only place the actual algorithm is checked — and the only place
/// that would notice if `deriveBits` were called with the wrong curve, an IV
/// were reused, a failed authentication tag surfaced as a thrown exception
/// instead of a null, or a device's own wrap went missing from the fan-out.
void main() {
  const alice = '11111111-1111-1111-1111-111111111111';
  const bob = '22222222-2222-2222-2222-222222222222';

  /// Two accounts that know about each other's registered devices, as they
  /// would after both have published and each has fetched the other's.
  ///
  /// Shares one [FakeChatKeyApi.published] directory between both sides —
  /// the same thing the real server is, from two devices' point of view —
  /// rather than manually seeding a cached peer key. Version 2 has no cached
  /// peer key to seed: [WebCryptoChatCrypto.encrypt] resolves targets through
  /// [ChatKeyStore.targetDevices] on every call.
  Future<(WebCryptoChatCrypto, ChatKeyStore, WebCryptoChatCrypto, ChatKeyStore)> pair() async {
    final published = <String, Map<String, String>>{};

    final aliceKeys = ChatKeyStore(
      vault: InMemoryChatKeyVault(),
      api: FakeChatKeyApi(userId: alice, published: published),
    );
    final bobKeys = ChatKeyStore(
      vault: InMemoryChatKeyVault(),
      api: FakeChatKeyApi(userId: bob, published: published),
    );

    await aliceKeys.ensureRegistered();
    await bobKeys.ensureRegistered();

    return (
      WebCryptoChatCrypto(keys: aliceKeys),
      aliceKeys,
      WebCryptoChatCrypto(keys: bobKeys),
      bobKeys,
    );
  }

  /// The wrapped copy of the content key belonging to [keys]' own device —
  /// what a real client would resolve server-side by sending its own device
  /// id, done by hand here since these tests talk to [WebCryptoChatCrypto]
  /// directly rather than through the wire.
  Future<WrappedKey> ownWrap(EncryptedBody body, ChatKeyStore keys) async {
    final deviceId = await keys.deviceId();
    return body.keys.firstWhere((k) => k.deviceId == deviceId);
  }

  test('a message encrypted by one side decrypts on the other', () async {
    final (aliceCrypto, _, bobCrypto, bobKeys) = await pair();

    final sealed = await aliceCrypto.encrypt(
      otherPartyId: bob,
      plaintext: 'great set today',
    );
    final wrap = await ownWrap(sealed, bobKeys);

    final plaintext = await bobCrypto.decrypt(
      otherPartyId: alice,
      ciphertext: sealed.ciphertext,
      iv: sealed.iv,
      version: sealed.version,
      ephemeralPublicKeyJwk: sealed.ephemeralPublicKeyJwk,
      wrappedKey: wrap.key,
      wrappedKeyIv: wrap.iv,
    );

    expect(plaintext, 'great set today');
  });

  test('the sender can read their own message back', () async {
    // Not a nicety — every device wraps for itself too, so the sender's own
    // thread renders from the same message everyone else reads, with no
    // special-cased "my own message" path.
    final (aliceCrypto, aliceKeys, _, _) = await pair();

    final sealed = await aliceCrypto.encrypt(
      otherPartyId: bob,
      plaintext: 'see you thursday',
    );
    final wrap = await ownWrap(sealed, aliceKeys);

    expect(
      await aliceCrypto.decrypt(
        otherPartyId: bob,
        ciphertext: sealed.ciphertext,
        iv: sealed.iv,
        version: sealed.version,
        ephemeralPublicKeyJwk: sealed.ephemeralPublicKeyJwk,
        wrappedKey: wrap.key,
        wrappedKeyIv: wrap.iv,
      ),
      'see you thursday',
    );
  });

  test('a message is readable on every device of both parties', () async {
    // The property this whole redesign exists for: registering a second
    // device must not narrow who can read a message relative to a single
    // device — it should only ever widen it.
    final published = <String, Map<String, String>>{};

    final aliceKeys = ChatKeyStore(
      vault: InMemoryChatKeyVault(),
      api: FakeChatKeyApi(userId: alice, published: published),
    );
    final bobPhoneKeys = ChatKeyStore(
      vault: InMemoryChatKeyVault(),
      api: FakeChatKeyApi(userId: bob, published: published),
    );
    final bobDesktopKeys = ChatKeyStore(
      vault: InMemoryChatKeyVault(),
      api: FakeChatKeyApi(userId: bob, published: published),
    );

    await aliceKeys.ensureRegistered();
    await bobPhoneKeys.ensureRegistered();
    await bobDesktopKeys.ensureRegistered();

    final sealed = await WebCryptoChatCrypto(
      keys: aliceKeys,
    ).encrypt(otherPartyId: bob, plaintext: 'onboarding call at 5');

    for (final device in [bobPhoneKeys, bobDesktopKeys]) {
      final wrap = await ownWrap(sealed, device);
      final plaintext = await WebCryptoChatCrypto(keys: device).decrypt(
        otherPartyId: alice,
        ciphertext: sealed.ciphertext,
        iv: sealed.iv,
        version: sealed.version,
        ephemeralPublicKeyJwk: sealed.ephemeralPublicKeyJwk,
        wrappedKey: wrap.key,
        wrappedKeyIv: wrap.iv,
      );
      expect(plaintext, 'onboarding call at 5');
    }
  });

  test('a device with no wrapped entry decrypts to null', () async {
    // The ordinary shape of "this message predates this device" — not
    // malformed input, and not a reason to fail the whole thread.
    final (aliceCrypto, _, bobCrypto, _) = await pair();

    final sealed = await aliceCrypto.encrypt(
      otherPartyId: bob,
      plaintext: 'before you had a desktop',
    );

    expect(
      await bobCrypto.decrypt(
        otherPartyId: alice,
        ciphertext: sealed.ciphertext,
        iv: sealed.iv,
        version: sealed.version,
        ephemeralPublicKeyJwk: sealed.ephemeralPublicKeyJwk,
        wrappedKey: null,
        wrappedKeyIv: null,
      ),
      isNull,
    );
  });

  test('the same plaintext twice produces a different IV, ciphertext and epk', () async {
    // An IV reused under one AES-GCM key is a total break, not a weakening, and
    // it is invisible: both messages still decrypt perfectly.
    final (aliceCrypto, _, _, _) = await pair();

    final first = await aliceCrypto.encrypt(otherPartyId: bob, plaintext: 'ok');
    final second = await aliceCrypto.encrypt(otherPartyId: bob, plaintext: 'ok');

    expect(first.iv, isNot(second.iv));
    expect(first.ciphertext, isNot(second.ciphertext));
    expect(first.ephemeralPublicKeyJwk, isNot(second.ephemeralPublicKeyJwk));
  });

  test('the ciphertext does not contain the plaintext', () async {
    final (aliceCrypto, _, _, _) = await pair();

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
    final (aliceCrypto, _, _, bobKeys) = await pair();
    final (_, _, strangerCrypto, _) = await pair();

    final sealed = await aliceCrypto.encrypt(
      otherPartyId: bob,
      plaintext: 'not for you',
    );
    final wrap = await ownWrap(sealed, bobKeys);

    // Null, not an exception. `loadThread` maps over a whole history, so a throw
    // halfway down it is an empty conversation rather than one unreadable line.
    expect(
      await strangerCrypto.decrypt(
        otherPartyId: alice,
        ciphertext: sealed.ciphertext,
        iv: sealed.iv,
        version: sealed.version,
        ephemeralPublicKeyJwk: sealed.ephemeralPublicKeyJwk,
        // A stranger was never wrapped for, so this is the closest a real
        // caller could accidentally get: someone else's wrap for the right
        // epk, which must still fail to unwrap under the stranger's key.
        wrappedKey: wrap.key,
        wrappedKeyIv: wrap.iv,
      ),
      isNull,
    );
  });

  test('a tampered ciphertext decrypts to null', () async {
    final (aliceCrypto, _, bobCrypto, bobKeys) = await pair();

    final sealed = await aliceCrypto.encrypt(
      otherPartyId: bob,
      plaintext: 'transfer approved',
    );
    final wrap = await ownWrap(sealed, bobKeys);

    final bytes = base64Decode(sealed.ciphertext);
    bytes[0] ^= 0xFF;

    expect(
      await bobCrypto.decrypt(
        otherPartyId: alice,
        ciphertext: base64Encode(bytes),
        iv: sealed.iv,
        version: sealed.version,
        ephemeralPublicKeyJwk: sealed.ephemeralPublicKeyJwk,
        wrappedKey: wrap.key,
        wrappedKeyIv: wrap.iv,
      ),
      isNull,
    );
  });

  test('a tampered wrapped key decrypts to null', () async {
    final (aliceCrypto, _, bobCrypto, bobKeys) = await pair();

    final sealed = await aliceCrypto.encrypt(
      otherPartyId: bob,
      plaintext: 'transfer approved',
    );
    final wrap = await ownWrap(sealed, bobKeys);

    final wrapBytes = base64Decode(wrap.key);
    wrapBytes[0] ^= 0xFF;

    expect(
      await bobCrypto.decrypt(
        otherPartyId: alice,
        ciphertext: sealed.ciphertext,
        iv: sealed.iv,
        version: sealed.version,
        ephemeralPublicKeyJwk: sealed.ephemeralPublicKeyJwk,
        wrappedKey: base64Encode(wrapBytes),
        wrappedKeyIv: wrap.iv,
      ),
      isNull,
    );
  });

  test('a version-0 body passes through untouched', () async {
    // Every message written before encryption existed. There is no key for
    // these and never will be; the body simply is the message.
    final (_, _, bobCrypto, _) = await pair();

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

  test('a version-1 (legacy pairwise) message still decrypts', () async {
    // Kept readable forever even though nothing writes it any more — a device
    // that upgraded to per-device keys must still be able to read whatever it
    // sent or received before that. `encrypt` never produces version 1 any
    // more, so this builds the envelope the way a pre-upgrade client did:
    // straight ECDH `deriveBits` into an AES-256-GCM key, no wrapping.
    final aliceVault = InMemoryChatKeyVault();
    final bobVault = InMemoryChatKeyVault();
    final aliceKeys = ChatKeyStore(vault: aliceVault, api: FakeChatKeyApi(userId: alice));
    final bobKeys = ChatKeyStore(vault: bobVault, api: FakeChatKeyApi(userId: bob));
    await aliceKeys.ensureRegistered();
    await bobKeys.ensureRegistered();

    // The pairwise scheme's own peer-key cache, seeded by hand exactly as it
    // would be from a "legacy" device row.
    aliceVault.entries['${ChatKeyStore.peerKeyPrefix}$bob'] =
        bobVault.entries[ChatKeyStore.identityPublicEntry]!;
    bobVault.entries['${ChatKeyStore.peerKeyPrefix}$alice'] =
        aliceVault.entries[ChatKeyStore.identityPublicEntry]!;

    final alicePrivate = await aliceKeys.identityKey();
    final bobPublicForAlice = await aliceKeys.peerKey(bob);
    final sharedBits = await alicePrivate.deriveBits(256, bobPublicForAlice);
    final sharedKey = await AesGcmSecretKey.importRawKey(sharedBits);

    final iv = Uint8List(12);
    fillRandomBytes(iv);
    final ciphertext = await sharedKey.encryptBytes(
      utf8.encode('a message from before the upgrade'),
      iv,
    );

    final bobCrypto = WebCryptoChatCrypto(keys: bobKeys);
    expect(
      await bobCrypto.decrypt(
        otherPartyId: alice,
        ciphertext: base64Encode(ciphertext),
        iv: base64Encode(iv),
        version: ChatEncryption.ecdhP256AesGcm,
      ),
      'a message from before the upgrade',
    );
  });

  test('an encrypted body with no IV decrypts to null', () async {
    final (_, _, bobCrypto, _) = await pair();

    expect(
      await bobCrypto.decrypt(
        otherPartyId: alice,
        ciphertext: 'AAAA',
        iv: null,
        version: ChatEncryption.ecdhP256AesGcmPerDevice,
      ),
      isNull,
    );
  });

  test('a null body decrypts to null at any version', () async {
    final (_, _, bobCrypto, _) = await pair();

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

  test('encrypting to a party with no registered devices throws', () async {
    final aliceKeys = ChatKeyStore(
      vault: InMemoryChatKeyVault(),
      api: FakeChatKeyApi(userId: alice),
    );
    await aliceKeys.ensureRegistered();

    expect(
      () => WebCryptoChatCrypto(keys: aliceKeys).encrypt(
        otherPartyId: 'never-opened-the-app',
        plaintext: 'hello?',
      ),
      throwsStateError,
    );
  });
}
