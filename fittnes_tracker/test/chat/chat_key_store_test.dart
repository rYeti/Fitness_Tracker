import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/feature/chat/data/chat_key_store.dart';

import 'fakes.dart';

/// The key lifecycle: generate once, publish once, survive sign-out, start
/// over when a different account signs in — and, since
/// docs/chat-multi-device-keys.md, never displace a second device's key
/// signing in on the same account does.
///
/// None of this is visible from a chat test. A store that regenerated its key
/// pair on every call would still send and receive messages perfectly inside one
/// session — and lose every conversation the moment the app restarted.
void main() {
  const me = '11111111-1111-1111-1111-111111111111';
  const someoneElse = '99999999-9999-9999-9999-999999999999';
  const peer = '22222222-2222-2222-2222-222222222222';

  late InMemoryChatKeyVault vault;
  late FakeChatKeyApi api;

  setUp(() {
    vault = InMemoryChatKeyVault();
    api = FakeChatKeyApi(userId: me);
  });

  ChatKeyStore build() => ChatKeyStore(vault: vault, api: api);

  test('generates and publishes a key pair on first run', () async {
    await build().ensureRegistered();

    expect(api.publishes, hasLength(1));
    expect(vault.entries[ChatKeyStore.identityKeyEntry], isNotNull);
    expect(vault.entries[ChatKeyStore.identityPublicEntry], isNotNull);
    expect(vault.entries[ChatKeyStore.identityOwnerEntry], me);
    // A real, freshly minted device id -- never the legacy sentinel a client
    // with no device id concept implicitly publishes under.
    expect(vault.entries[ChatKeyStore.identityDeviceEntry], isNotNull);
    expect(
      vault.entries[ChatKeyStore.identityDeviceEntry],
      isNot(ChatKeyStore.legacyDeviceId),
    );
    expect(api.publishes.single.deviceId, vault.entries[ChatKeyStore.identityDeviceEntry]);

    // The private half stays here. Whatever went to the server must not carry
    // the `d` parameter, which is the entire private key.
    final publishedJwk =
        jsonDecode(api.publishes.single.publicKeyJwk) as Map<String, dynamic>;
    expect(publishedJwk.containsKey('d'), isFalse);
    expect(publishedJwk['crv'], 'P-256');
  });

  test('reuses the stored key pair instead of generating a second one', () async {
    await build().ensureRegistered();
    final firstKey = vault.entries[ChatKeyStore.identityKeyEntry];

    // A fresh store, as a relaunch of the app would build.
    await build().ensureRegistered();

    expect(vault.entries[ChatKeyStore.identityKeyEntry], firstKey);
    expect(api.publishes, hasLength(1));
  });

  test('republishes when the server has lost every device but this one has not', () async {
    await build().ensureRegistered();
    final storedKey = vault.entries[ChatKeyStore.identityKeyEntry];

    api.published.remove(me);
    await build().ensureRegistered();

    // Republished, not regenerated. This device still holds the only private
    // half that can read its existing conversations.
    expect(vault.entries[ChatKeyStore.identityKeyEntry], storedKey);
    expect(api.publishes, hasLength(2));
    expect(api.publishes.last.publicKeyJwk, api.publishes.first.publicKeyJwk);
    expect(api.publishes.last.deviceId, api.publishes.first.deviceId);
  });

  test('regenerates when a different account signs in on this device', () async {
    await build().ensureRegistered();
    final firstKey = vault.entries[ChatKeyStore.identityKeyEntry];
    vault.entries['${ChatKeyStore.peerKeyPrefix}$peer'] = 'someone-elses-peer';

    final theirApi = FakeChatKeyApi(userId: someoneElse);
    await ChatKeyStore(vault: vault, api: theirApi).ensureRegistered();

    expect(vault.entries[ChatKeyStore.identityKeyEntry], isNot(firstKey));
    expect(vault.entries[ChatKeyStore.identityOwnerEntry], someoneElse);
    // The previous account's cached peer keys are wrong for every thread the
    // new one has, and are not theirs to keep either.
    expect(vault.entries['${ChatKeyStore.peerKeyPrefix}$peer'], isNull);
  });

  test('keeps the same device id across an account switch on this device', () async {
    // The device id names this physical install, not the account signed
    // into it — a phone that takes turns between two accounts is still one
    // device as far as the server needs to know.
    await build().ensureRegistered();
    final deviceId = vault.entries[ChatKeyStore.identityDeviceEntry];

    final theirApi = FakeChatKeyApi(userId: someoneElse);
    await ChatKeyStore(vault: vault, api: theirApi).ensureRegistered();

    expect(vault.entries[ChatKeyStore.identityDeviceEntry], deviceId);
  });

  test('regenerates when only half the key pair survived', () async {
    await build().ensureRegistered();
    vault.entries.remove(ChatKeyStore.identityPublicEntry);

    await build().ensureRegistered();

    // A private key with no published public half encrypts messages nobody will
    // ever read.
    expect(vault.entries[ChatKeyStore.identityPublicEntry], isNotNull);
    expect(api.publishes, hasLength(2));
  });

  test('caches a peer\'s devices after fetching them once', () async {
    final store = build();
    await store.ensureRegistered();
    api.published[peer] = Map.of(api.published[me]!);

    await store.peerKeys(peer);
    await store.peerKeys(peer);

    expect(api.fetchPeerCalls, 1);
    expect(vault.entries['${ChatKeyStore.peerKeyPrefix}$peer'], isNotNull);
  });

  test('forgetPeer forces the next lookup back to the server', () async {
    final store = build();
    await store.ensureRegistered();
    api.published[peer] = Map.of(api.published[me]!);

    await store.peerKeys(peer);
    await store.forgetPeer(peer);
    await store.peerKeys(peer);

    // Two fetches, and the vault entry actually cleared — dropping only the
    // in-memory copy would re-read the same stale key straight back off disk.
    expect(api.fetchPeerCalls, 2);
  });

  test('a peer who has never published a key throws rather than encrypting to nothing', () async {
    final store = build();
    await store.ensureRegistered();

    expect(() => store.peerKeys(peer), throwsStateError);
  });

  test('one malformed cached device costs that device, not every device of the peer', () async {
    // A future JWK shape this build doesn't recognise, or a corrupted write,
    // must not make every *other*, perfectly good device of the same peer
    // unreachable too -- the same failure shape ChatBodyCodec.decode and
    // ChatAttachmentRef.tryFromJson already guard against.
    final store = build();
    await store.ensureRegistered();
    final goodDeviceId = api.published[me]!.keys.single;
    final goodJwk = api.published[me]!.values.single;

    vault.entries['${ChatKeyStore.peerKeyPrefix}$peer'] = jsonEncode([
      {'deviceId': 'broken-device', 'publicKeyJwk': 'not valid json at all'},
      {'deviceId': goodDeviceId, 'publicKeyJwk': goodJwk},
    ]);

    final resolved = await store.peerKeys(peer);

    expect(resolved.keys, [goodDeviceId]);
  });

  test('the identity key survives a sign-out that clears the session', () async {
    // Sign-out clears the token, refresh token and cached user. It must not
    // clear this: signing back in on the same device would otherwise throw away
    // every conversation the account has.
    await build().ensureRegistered();
    final key = vault.entries[ChatKeyStore.identityKeyEntry];

    vault.entries.removeWhere((k, _) => const {
      'token',
      'refresh_token',
      'user',
    }.contains(k));

    expect(vault.entries[ChatKeyStore.identityKeyEntry], key);
    expect(await build().identityKey(), isNotNull);
  });

  group('multi-device', () {
    test(
      'a second device signing in does not displace the first, on either side',
      () async {
        // Reproduces the actual production incident this table's redesign
        // fixes: before device ids existed, both devices below would have
        // published to the same single row, and the second publish would
        // have silently discarded the first's key. Two vaults sharing one
        // server directory are what a phone and a laptop signed into the
        // same account look like from the server's point of view.
        final phoneVault = InMemoryChatKeyVault();
        final laptopVault = InMemoryChatKeyVault();
        final shared = <String, Map<String, String>>{};

        final phone = ChatKeyStore(
          vault: phoneVault,
          api: FakeChatKeyApi(userId: me, published: shared),
        );
        final laptop = ChatKeyStore(
          vault: laptopVault,
          api: FakeChatKeyApi(userId: me, published: shared),
        );

        await phone.ensureRegistered();
        final phoneKey = phoneVault.entries[ChatKeyStore.identityKeyEntry];
        await laptop.ensureRegistered();

        // The phone's own vault is untouched by the laptop signing in.
        expect(phoneVault.entries[ChatKeyStore.identityKeyEntry], phoneKey);

        // The server holds both, under two distinct device ids.
        expect(shared[me], hasLength(2));

        // Re-registering the phone must not think it was displaced and
        // regenerate — its own row is still exactly as it left it.
        await phone.ensureRegistered();
        expect(phoneVault.entries[ChatKeyStore.identityKeyEntry], phoneKey);
        expect(shared[me], hasLength(2));
      },
    );

    test(
      'each device sees the other among its own devices after re-registering',
      () async {
        final phoneVault = InMemoryChatKeyVault();
        final laptopVault = InMemoryChatKeyVault();
        final shared = <String, Map<String, String>>{};

        final phone = ChatKeyStore(
          vault: phoneVault,
          api: FakeChatKeyApi(userId: me, published: shared),
        );
        final laptop = ChatKeyStore(
          vault: laptopVault,
          api: FakeChatKeyApi(userId: me, published: shared),
        );

        await phone.ensureRegistered();
        await laptop.ensureRegistered();
        // Re-register the phone so its own-device cache picks up the laptop,
        // which was published after the phone's first fetch of `me`.
        await phone.ensureRegistered();

        final phoneDeviceId = phoneVault.entries[ChatKeyStore.identityDeviceEntry]!;
        final laptopDeviceId =
            laptopVault.entries[ChatKeyStore.identityDeviceEntry]!;

        // Includes the phone's own entry too -- `ownDeviceKeys` reports every
        // device this account has, exactly as the server's `me.devices` did;
        // it is `WebCryptoChatCrypto`'s job to skip the sending device when
        // deciding who to wrap a content key for, not this method's.
        final phoneOwnDevices = await phone.ownDeviceKeys();
        expect(phoneOwnDevices.keys, containsAll([phoneDeviceId, laptopDeviceId]));
      },
    );

    test(
      'a device that had to republish is in its own device cache afterwards',
      () async {
        // The three cases this whole table redesign exists for — a row
        // evicted by the per-user cap, a row displaced by another device,
        // and the first run after upgrading from a build with no device id —
        // all reach `ensureRegistered` with this device's row *absent* from
        // the server, so it republishes.
        //
        // The device list cached after that republish has to contain the row
        // it just wrote. `WebCryptoChatCrypto._encryptV2` wraps a message's
        // content key for exactly the devices in this cache, so a cache
        // missing this device produces a message this device can send once
        // and never read again — the same self-wrap failure
        // docs/chat-multi-device-keys.md §8 describes, reached down a
        // different path.
        final phoneVault = InMemoryChatKeyVault();
        final laptopVault = InMemoryChatKeyVault();
        final shared = <String, Map<String, String>>{};

        final phone = ChatKeyStore(
          vault: phoneVault,
          api: FakeChatKeyApi(userId: me, published: shared),
        );
        final laptop = ChatKeyStore(
          vault: laptopVault,
          api: FakeChatKeyApi(userId: me, published: shared),
        );

        await phone.ensureRegistered();
        await laptop.ensureRegistered();

        final phoneDeviceId =
            phoneVault.entries[ChatKeyStore.identityDeviceEntry]!;

        // The per-user device cap evicted this phone while it was away. The
        // laptop's row stays, so the cache this test checks is populated but
        // wrong, rather than merely empty.
        shared[me]!.remove(phoneDeviceId);

        // Coming back: a fresh store on the same vault, as a relaunch builds.
        final rejoined = ChatKeyStore(
          vault: phoneVault,
          api: FakeChatKeyApi(userId: me, published: shared),
        );
        await rejoined.ensureRegistered();

        // It noticed and republished, so the server has it back...
        expect(shared[me], contains(phoneDeviceId));
        // ...and its own cache has to agree, or it will not wrap for itself.
        expect(
          (await rejoined.ownDeviceKeys()).keys,
          contains(phoneDeviceId),
          reason:
              'the device list is cached from the `me` fetched *before* the '
              'republish, which by definition cannot contain this device',
        );
      },
    );
  });

  group('cache-only', () {
    test('reads a cached peer key without any network', () async {
      final store = build();
      await store.ensureRegistered();
      api.published[peer] = Map.of(api.published[me]!);
      await store.peerKeys(peer);

      // What the push background isolate builds: a vault and nothing else.
      final offline = ChatKeyStore.cacheOnly(vault: vault);

      expect(await offline.identityKey(), isNotNull);
      expect(await offline.peerKeys(peer), isNotNull);
    });

    test('throws on an uncached peer rather than reaching for a locator', () async {
      await build().ensureRegistered();
      final offline = ChatKeyStore.cacheOnly(vault: vault);

      expect(() => offline.peerKeys(peer), throwsStateError);
    });

    test('refuses to register', () async {
      expect(
        () => ChatKeyStore.cacheOnly(vault: vault).ensureRegistered(),
        throwsStateError,
      );
    });

    test('reads cached own-device keys without any network', () async {
      await build().ensureRegistered();
      final offline = ChatKeyStore.cacheOnly(vault: vault);

      // Populated by ensureRegistered's own fetch of `me` -- one entry, this
      // device's own, since nothing else has registered yet.
      expect(await offline.ownDeviceKeys(), hasLength(1));
    });

    test('reports no own devices, not an error, before anything is cached', () async {
      // A cache-only store built against a vault that has never registered
      // at all -- the state the push isolate is genuinely in the first time
      // it ever runs, before any foreground session has completed once.
      final offline = ChatKeyStore.cacheOnly(vault: InMemoryChatKeyVault());

      expect(await offline.ownDeviceKeys(), isEmpty);
    });
  });
}
