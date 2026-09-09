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

  /// Regressions from the review of this branch. Each pins a failure that is
  /// silent from the sender's side — the message seals, sends and renders as
  /// delivered, and only the reader discovers there is nothing there.
  group('shared-secret cache', () {
    const carol = '33333333-3333-3333-3333-333333333333';

    /// A registered store plus the vault behind it, which every test here
    /// needs to reach into for the device id and exported public key.
    Future<(ChatKeyStore, InMemoryChatKeyVault)> registered(
      String userId, {
      Map<String, Map<String, String>>? published,
    }) async {
      final vault = InMemoryChatKeyVault();
      final store = ChatKeyStore(
        vault: vault,
        api: FakeChatKeyApi(userId: userId, published: published),
      );
      await store.ensureRegistered();
      return (store, vault);
    }

    test(
      'a device whose row was evicted can still read back what it sent after '
      'republishing',
      () async {
        // `ensureRegistered` caches this account's device list from the `me`
        // it fetched *before* republishing, which cannot contain the row the
        // republish is about to write. `_encryptV2` wraps only for the
        // devices in that cache, so the sending device gets no wrap of its
        // own — and a thread reload calls `decrypt` on the stored ciphertext
        // with no plaintext left to fall back on.
        final aliceDevices = <String, Map<String, String>>{};
        final (_, phoneVault) = await registered(
          alice,
          published: aliceDevices,
        );
        await registered(alice, published: aliceDevices); // alice's laptop
        final (_, peerVault) = await registered(bob);

        final phoneDeviceId =
            phoneVault.entries[ChatKeyStore.identityDeviceEntry]!;

        // The per-user cap evicted the phone while it was away. The laptop's
        // row remains, so what the phone caches next is populated but wrong.
        aliceDevices[alice]!.remove(phoneDeviceId);

        final rejoinedKeys = ChatKeyStore(
          vault: phoneVault,
          api: FakeChatKeyApi(userId: alice, published: aliceDevices),
        );
        await rejoinedKeys.ensureRegistered();

        seedPeerDevice(
          phoneVault,
          bob,
          peerVault.entries[ChatKeyStore.identityDeviceEntry]!,
          peerVault.entries[ChatKeyStore.identityPublicEntry]!,
        );

        final phone = WebCryptoChatCrypto(keys: rejoinedKeys);
        final sealed = await phone.encrypt(
          otherPartyId: bob,
          plaintext: 'back after an eviction',
        );

        expect(
          await phone.decrypt(
            otherPartyId: bob,
            ciphertext: sealed.ciphertext,
            iv: sealed.iv,
            version: sealed.version,
          ),
          'back after an eviction',
          reason:
              'the content key was wrapped for every device this account had '
              'except the one that sent the message',
        );
      },
    );

    test('two legacy-only peers do not share one derived secret', () async {
      // The legacy device id is a sentinel every pre-upgrade install shares,
      // not an identity — so a derived-secret cache keyed on the device id
      // alone collides across peers. One `WebCryptoChatCrypto` serves the
      // whole trainer console (`TrainerConsoleHome` builds a single
      // `ChatRepository` for the entire roster), so a trainer with two
      // clients still on an old build is the ordinary case, not a corner.
      final (aliceKeys, aliceVault) = await registered(alice);
      final (bobKeys, bobVault) = await registered(bob);
      final (carolKeys, carolVault) = await registered(carol);

      // Both peers look like pre-upgrade installs from alice's side: one
      // device apiece, filed under the legacy sentinel.
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

      // One crypto instance, two threads — the console's actual shape.
      final console = WebCryptoChatCrypto(keys: aliceKeys);
      final toBob = await console.encrypt(
        otherPartyId: bob,
        plaintext: 'bob only',
      );
      final toCarol = await console.encrypt(
        otherPartyId: carol,
        plaintext: 'carol only',
      );

      // Each peer caches alice's one real device, as a fetch would leave it.
      for (final peerVault in [bobVault, carolVault]) {
        seedPeerDevice(
          peerVault,
          alice,
          aliceVault.entries[ChatKeyStore.identityDeviceEntry]!,
          aliceVault.entries[ChatKeyStore.identityPublicEntry]!,
        );
      }

      expect(
        await WebCryptoChatCrypto(keys: bobKeys).decrypt(
          otherPartyId: alice,
          ciphertext: toBob.ciphertext,
          iv: toBob.iv,
          version: toBob.version,
        ),
        'bob only',
      );
      expect(
        await WebCryptoChatCrypto(keys: carolKeys).decrypt(
          otherPartyId: alice,
          ciphertext: toCarol.ciphertext,
          iv: toCarol.iv,
          version: toCarol.version,
        ),
        'carol only',
        reason:
            'the second send reused the secret cached under the legacy '
            'sentinel by the first, so it is sealed to the wrong peer',
      );
    });

    test(
      "an account's own legacy row does not poison a later send to a legacy "
      'peer',
      () async {
        // After the migration every pre-existing account keeps a legacy row
        // of its own, holding that account's own key. `_encryptV2` wraps for
        // its own devices too, so the first v2 send files a *self*-derived
        // secret under the legacy sentinel — which the next v1 send to a
        // genuinely legacy peer then reuses in place of the peer's.
        final aliceDevices = <String, Map<String, String>>{};
        final (aliceKeys, aliceVault) = await registered(
          alice,
          published: aliceDevices,
        );

        // The row the migration left behind: this account's own key, filed
        // under the sentinel, alongside the real device id it just published.
        aliceDevices[alice]![ChatKeyStore.legacyDeviceId] =
            aliceVault.entries[ChatKeyStore.identityPublicEntry]!;
        // Re-register so the own-device cache picks that legacy row up.
        await aliceKeys.ensureRegistered();

        final (bobKeys, bobVault) = await registered(bob);
        final (_, carolVault) = await registered(carol);

        // carol has upgraded — a real device id, so she gets v2.
        seedPeerDevice(
          aliceVault,
          carol,
          carolVault.entries[ChatKeyStore.identityDeviceEntry]!,
          carolVault.entries[ChatKeyStore.identityPublicEntry]!,
        );
        // bob has not — legacy only, so he gets v1.
        seedPeerDevice(
          aliceVault,
          bob,
          ChatKeyStore.legacyDeviceId,
          bobVault.entries[ChatKeyStore.identityPublicEntry]!,
        );

        final console = WebCryptoChatCrypto(keys: aliceKeys);
        // v2 first: this is what caches a self-derived secret under the
        // legacy sentinel, by wrapping for alice's own legacy row.
        await console.encrypt(otherPartyId: carol, plaintext: 'hello carol');
        final toBob = await console.encrypt(
          otherPartyId: bob,
          plaintext: 'hello bob',
        );

        seedPeerDevice(
          bobVault,
          alice,
          aliceVault.entries[ChatKeyStore.identityDeviceEntry]!,
          aliceVault.entries[ChatKeyStore.identityPublicEntry]!,
        );

        expect(
          await WebCryptoChatCrypto(keys: bobKeys).decrypt(
            otherPartyId: alice,
            ciphertext: toBob.ciphertext,
            iv: toBob.iv,
            version: toBob.version,
          ),
          'hello bob',
          reason:
              'the v1 send reused the secret alice derived against her own '
              'legacy row, not the one against bob',
        );
      },
    );
  });
}
