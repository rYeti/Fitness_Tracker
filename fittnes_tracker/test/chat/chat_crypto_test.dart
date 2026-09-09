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

  /// Records [deviceId]'s [publicKeyJwk] under [otherPartyId] in [vault], the
  /// way a real fetch from `GET api/chat/keys/{otherPartyId}` would leave it —
  /// a JSON list of `{deviceId, publicKeyJwk}`, per `ChatKeyStore.peerKeys`.
  void seedPeerDevice(
    InMemoryChatKeyVault vault,
    String otherPartyId,
    String deviceId,
    String publicKeyJwk,
  ) {
    final entry = '${ChatKeyStore.peerKeyPrefix}$otherPartyId';
    final existing =
        vault.entries[entry] == null
            ? <dynamic>[]
            : jsonDecode(vault.entries[entry]!) as List;
    vault.entries[entry] = jsonEncode([
      ...existing,
      {'deviceId': deviceId, 'publicKeyJwk': publicKeyJwk},
    ]);
  }

  /// Two single-device key stores that know about each other, as two devices
  /// on two different accounts would after both have published and each has
  /// fetched the other's key. Both mint a real, non-legacy device id via the
  /// ordinary [ChatKeyStore.ensureRegistered] path, so every test below
  /// exercises the v2 wrapped envelope unless it deliberately sets up
  /// something else.
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

    seedPeerDevice(
      aliceVault,
      bob,
      bobVault.entries[ChatKeyStore.identityDeviceEntry]!,
      bobVault.entries[ChatKeyStore.identityPublicEntry]!,
    );
    seedPeerDevice(
      bobVault,
      alice,
      aliceVault.entries[ChatKeyStore.identityDeviceEntry]!,
      aliceVault.entries[ChatKeyStore.identityPublicEntry]!,
    );

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

  test('the sender can read their own message back, later, with no plaintext in hand', () async {
    // Not a nicety, and not only about the moment of sending: a thread reload
    // calls decrypt on every stored message, including this device's own
    // outgoing ones, with no shortcut left to fall back on. A content key
    // wrapped for every device but the one that sent it would make a sender
    // unable to reread their own history after a restart.
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

    // The envelope is JSON text carrying the sealed content separately —
    // check the actual sealed bytes too, not just the envelope's own shape.
    final envelope = jsonDecode(sealed.ciphertext) as Map<String, dynamic>;
    final contentCiphertext = base64Decode(envelope['ct'] as String);
    expect(
      utf8.decode(contentCiphertext, allowMalformed: true),
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

    final envelope = jsonDecode(sealed.ciphertext) as Map<String, dynamic>;
    final bytes = base64Decode(envelope['ct'] as String);
    bytes[0] ^= 0xFF;
    envelope['ct'] = base64Encode(bytes);

    expect(
      await bobCrypto.decrypt(
        otherPartyId: alice,
        ciphertext: jsonEncode(envelope),
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
    expect(
      await bobCrypto.decrypt(
        otherPartyId: alice,
        ciphertext: '{"v":2,"s":"x","ct":"AAAA","w":{}}',
        iv: null,
        version: ChatEncryption.ecdhP256AesGcmWrapped,
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

  test('an unparseable v2 envelope decrypts to null rather than throwing', () async {
    final (_, bobCrypto) = await pair();

    expect(
      await bobCrypto.decrypt(
        otherPartyId: alice,
        ciphertext: 'not json at all',
        iv: base64Encode(List.filled(12, 0)),
        version: ChatEncryption.ecdhP256AesGcmWrapped,
      ),
      isNull,
    );
  });

  test(
    'two different legacy-only peers encrypted from the same session do not '
    'share a derived secret',
    () async {
      // Reproduces the exact cross-contamination
      // docs/chat-multi-device-keys.md's legacy-sentinel note describes: one
      // `WebCryptoChatCrypto` instance (as `trainer_console_home.dart` builds
      // for a whole roster) sending v1 to two unrelated legacy-only peers.
      // `ChatKeyStore.legacyDeviceId` is the same fixed sentinel for both, so
      // a cache keyed on device id alone would derive against the first
      // peer's public key and then silently hand that same secret back for
      // the second — the second peer would fail to decrypt with no error
      // anywhere, since a wrong AES key still "succeeds" until the GCM tag
      // check runs.
      const carol = '33333333-3333-3333-3333-333333333333';

      final aliceVault = InMemoryChatKeyVault();
      final aliceKeys = ChatKeyStore(vault: aliceVault, api: FakeChatKeyApi(userId: alice));
      await aliceKeys.ensureRegistered();

      final bobVault = InMemoryChatKeyVault();
      final bobKeys = ChatKeyStore(vault: bobVault, api: FakeChatKeyApi(userId: bob));
      await bobKeys.ensureRegistered();

      final carolVault = InMemoryChatKeyVault();
      final carolKeys = ChatKeyStore(vault: carolVault, api: FakeChatKeyApi(userId: carol));
      await carolKeys.ensureRegistered();

      // Both peers are legacy-only from alice's side — the same sentinel id
      // for each, but different real public keys underneath.
      seedPeerDevice(
        aliceVault,
        bob,
        ChatKeyStore.legacyDeviceId,
        bobVault.entries[ChatKeyStore.identityPublicEntry]!,
      );
      seedPeerDevice(
        aliceVault,
        carol,
        ChatKeyStore.legacyDeviceId,
        carolVault.entries[ChatKeyStore.identityPublicEntry]!,
      );

      final aliceCrypto = WebCryptoChatCrypto(keys: aliceKeys);

      final toBob = await aliceCrypto.encrypt(
        otherPartyId: bob,
        plaintext: 'for bob only',
      );
      final toCarol = await aliceCrypto.encrypt(
        otherPartyId: carol,
        plaintext: 'for carol only',
      );

      expect(toBob.version, ChatEncryption.ecdhP256AesGcm);
      expect(toCarol.version, ChatEncryption.ecdhP256AesGcm);

      seedPeerDevice(
        bobVault,
        alice,
        aliceVault.entries[ChatKeyStore.identityDeviceEntry]!,
        aliceVault.entries[ChatKeyStore.identityPublicEntry]!,
      );
      seedPeerDevice(
        carolVault,
        alice,
        aliceVault.entries[ChatKeyStore.identityDeviceEntry]!,
        aliceVault.entries[ChatKeyStore.identityPublicEntry]!,
      );

      final bobCrypto = WebCryptoChatCrypto(keys: bobKeys);
      final carolCrypto = WebCryptoChatCrypto(keys: carolKeys);

      expect(
        await bobCrypto.decrypt(
          otherPartyId: alice,
          ciphertext: toBob.ciphertext,
          iv: toBob.iv,
          version: toBob.version,
        ),
        'for bob only',
      );
      expect(
        await carolCrypto.decrypt(
          otherPartyId: alice,
          ciphertext: toCarol.ciphertext,
          iv: toCarol.iv,
          version: toCarol.version,
        ),
        'for carol only',
      );
    },
  );

  group('multi-device', () {
    /// Three key stores: two devices of one account (phone, laptop) and one
    /// peer, all mutually aware of each other the way they would be after
    /// each has published and the others have fetched.
    Future<
      ({
        WebCryptoChatCrypto phone,
        WebCryptoChatCrypto laptop,
        WebCryptoChatCrypto peer,
      })
    >
    trio() async {
      final phoneVault = InMemoryChatKeyVault();
      final laptopVault = InMemoryChatKeyVault();
      final peerVault = InMemoryChatKeyVault();
      final aliceDevices = <String, Map<String, String>>{};

      final phoneKeys = ChatKeyStore(
        vault: phoneVault,
        api: FakeChatKeyApi(userId: alice, published: aliceDevices),
      );
      final laptopKeys = ChatKeyStore(
        vault: laptopVault,
        api: FakeChatKeyApi(userId: alice, published: aliceDevices),
      );
      final peerKeys = ChatKeyStore(
        vault: peerVault,
        api: FakeChatKeyApi(userId: bob),
      );

      await phoneKeys.ensureRegistered();
      await laptopKeys.ensureRegistered();
      // Re-registers the phone so its own-device cache picks up the laptop,
      // which published after the phone's own first fetch of `me`.
      await phoneKeys.ensureRegistered();
      await peerKeys.ensureRegistered();

      final phoneDeviceId = phoneVault.entries[ChatKeyStore.identityDeviceEntry]!;
      final peerDeviceId = peerVault.entries[ChatKeyStore.identityDeviceEntry]!;

      // The phone caches the peer's device, as the sender.
      seedPeerDevice(
        phoneVault,
        bob,
        peerDeviceId,
        peerVault.entries[ChatKeyStore.identityPublicEntry]!,
      );
      // The peer caches the phone's device — the one that will actually send.
      seedPeerDevice(
        peerVault,
        alice,
        phoneDeviceId,
        phoneVault.entries[ChatKeyStore.identityPublicEntry]!,
      );

      return (
        phone: WebCryptoChatCrypto(keys: phoneKeys),
        laptop: WebCryptoChatCrypto(keys: laptopKeys),
        peer: WebCryptoChatCrypto(keys: peerKeys),
      );
    }

    test(
      'a message sent from one device is readable by another device of the '
      'same account, by the peer, and by the sender itself later',
      () async {
        final crypto = await trio();

        final sealed = await crypto.phone.encrypt(
          otherPartyId: bob,
          plaintext: 'sent from my phone',
        );
        expect(sealed.version, ChatEncryption.ecdhP256AesGcmWrapped);

        expect(
          await crypto.laptop.decrypt(
            otherPartyId: bob,
            ciphertext: sealed.ciphertext,
            iv: sealed.iv,
            version: sealed.version,
          ),
          'sent from my phone',
        );
        expect(
          await crypto.peer.decrypt(
            otherPartyId: alice,
            ciphertext: sealed.ciphertext,
            iv: sealed.iv,
            version: sealed.version,
          ),
          'sent from my phone',
        );
        expect(
          await crypto.phone.decrypt(
            otherPartyId: bob,
            ciphertext: sealed.ciphertext,
            iv: sealed.iv,
            version: sealed.version,
          ),
          'sent from my phone',
        );
      },
    );

    test('a device that only heard about the message later still can\'t read it', () async {
      // The laptop's own-device cache is only as fresh as its last
      // ensureRegistered call. A device that genuinely never received a
      // wrap for it — not merely one whose cache is stale — must fail
      // cleanly, the same as any other missing key.
      final phoneVault = InMemoryChatKeyVault();
      final lateVault = InMemoryChatKeyVault();
      final aliceDevices = <String, Map<String, String>>{};

      final phoneKeys = ChatKeyStore(
        vault: phoneVault,
        api: FakeChatKeyApi(userId: alice, published: aliceDevices),
      );
      await phoneKeys.ensureRegistered();

      final bobVault = InMemoryChatKeyVault();
      await ChatKeyStore(vault: bobVault, api: FakeChatKeyApi(userId: bob))
          .ensureRegistered();

      final phoneCrypto = WebCryptoChatCrypto(keys: phoneKeys);
      seedPeerDevice(
        phoneVault,
        bob,
        bobVault.entries[ChatKeyStore.identityDeviceEntry]!,
        bobVault.entries[ChatKeyStore.identityPublicEntry]!,
      );

      final sealed = await phoneCrypto.encrypt(
        otherPartyId: bob,
        plaintext: 'before the new device existed',
      );

      // A device for this same account that only registers *after* the
      // message was sent — its own device id was never a wrap target.
      final lateKeys = ChatKeyStore(
        vault: lateVault,
        api: FakeChatKeyApi(userId: alice, published: aliceDevices),
      );
      await lateKeys.ensureRegistered();
      final lateCrypto = WebCryptoChatCrypto(keys: lateKeys);

      expect(
        await lateCrypto.decrypt(
          otherPartyId: bob,
          ciphertext: sealed.ciphertext,
          iv: sealed.iv,
          version: sealed.version,
        ),
        isNull,
      );
    });

    test('a peer whose only device is the legacy one is sent v1, and can read it back', () async {
      // What an unmigrated build looks like on the server: exactly one
      // device, filed under the legacy sentinel because it never sent a
      // device id at all.
      final aliceVault = InMemoryChatKeyVault();
      final bobVault = InMemoryChatKeyVault();

      final aliceKeys = ChatKeyStore(
        vault: aliceVault,
        api: FakeChatKeyApi(userId: alice),
      );
      await aliceKeys.ensureRegistered();

      final bobKeys = ChatKeyStore(vault: bobVault, api: FakeChatKeyApi(userId: bob));
      await bobKeys.ensureRegistered();
      final bobPublicKey = bobVault.entries[ChatKeyStore.identityPublicEntry]!;

      seedPeerDevice(aliceVault, bob, ChatKeyStore.legacyDeviceId, bobPublicKey);

      final aliceCrypto = WebCryptoChatCrypto(keys: aliceKeys);
      final sealed = await aliceCrypto.encrypt(
        otherPartyId: bob,
        plaintext: 'still readable on an old build',
      );

      expect(sealed.version, ChatEncryption.ecdhP256AesGcm);

      // bob's own vault has no idea its identity is filed under the legacy
      // slot from alice's side — v1 carries no sender-device field, so
      // decrypting has to work no matter which of the peer's devices it
      // was actually encrypted against.
      seedPeerDevice(
        bobVault,
        alice,
        aliceVault.entries[ChatKeyStore.identityDeviceEntry]!,
        aliceVault.entries[ChatKeyStore.identityPublicEntry]!,
      );
      final bobCrypto = WebCryptoChatCrypto(keys: bobKeys);

      expect(
        await bobCrypto.decrypt(
          otherPartyId: alice,
          ciphertext: sealed.ciphertext,
          iv: sealed.iv,
          version: sealed.version,
        ),
        'still readable on an old build',
      );
    });

    test('a peer with any real device id gets v2, even alongside a legacy row', () async {
      final aliceVault = InMemoryChatKeyVault();
      final aliceKeys = ChatKeyStore(vault: aliceVault, api: FakeChatKeyApi(userId: alice));
      await aliceKeys.ensureRegistered();

      // A real second key, standing in for bob's laptop, published under a
      // real device id -- alongside a real legacy row nothing has cleaned
      // up. Only the presence of a non-legacy device should matter, not
      // whether the legacy row is also still there.
      final bobLegacyVault = InMemoryChatKeyVault();
      await ChatKeyStore(vault: bobLegacyVault, api: FakeChatKeyApi(userId: bob))
          .ensureRegistered();

      final bobLaptopVault = InMemoryChatKeyVault();
      await ChatKeyStore(vault: bobLaptopVault, api: FakeChatKeyApi(userId: bob))
          .ensureRegistered();

      seedPeerDevice(
        aliceVault,
        bob,
        ChatKeyStore.legacyDeviceId,
        bobLegacyVault.entries[ChatKeyStore.identityPublicEntry]!,
      );
      seedPeerDevice(
        aliceVault,
        bob,
        bobLaptopVault.entries[ChatKeyStore.identityDeviceEntry]!,
        bobLaptopVault.entries[ChatKeyStore.identityPublicEntry]!,
      );

      final aliceCrypto = WebCryptoChatCrypto(keys: aliceKeys);
      final sealed = await aliceCrypto.encrypt(
        otherPartyId: bob,
        plaintext: 'bob updated, so this is v2',
      );

      expect(sealed.version, ChatEncryption.ecdhP256AesGcmWrapped);

      // The laptop can actually read it — proves v2 wrapped for the real
      // device, not merely that the version tag says so.
      seedPeerDevice(
        bobLaptopVault,
        alice,
        aliceVault.entries[ChatKeyStore.identityDeviceEntry]!,
        aliceVault.entries[ChatKeyStore.identityPublicEntry]!,
      );
      final laptopCrypto = WebCryptoChatCrypto(keys: ChatKeyStore(
        vault: bobLaptopVault,
        api: FakeChatKeyApi(userId: bob),
      ));

      expect(
        await laptopCrypto.decrypt(
          otherPartyId: alice,
          ciphertext: sealed.ciphertext,
          iv: sealed.iv,
          version: sealed.version,
        ),
        'bob updated, so this is v2',
      );
    });
  });
}
