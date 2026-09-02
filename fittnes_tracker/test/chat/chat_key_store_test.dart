import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/feature/chat/data/chat_key_store.dart';

import 'fakes.dart';

/// The key lifecycle: generate once, publish alongside every other device,
/// survive sign-out, and start over when a different account signs in.
///
/// None of this is visible from a chat test. A store that regenerated its key
/// pair on every call would still send and receive messages perfectly inside one
/// session — and lose every conversation the moment the app restarted. A store
/// that replaced another device's row instead of adding its own would look
/// identical to this one right up until a second device registered.
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

  test('mints and persists a device id on first use', () async {
    final store = build();
    final id = await store.deviceId();

    expect(id, isNotEmpty);
    expect(vault.entries[ChatKeyStore.deviceIdEntry], id);
    expect(await store.deviceId(), id);
  });

  test('generates and publishes a key pair on first run', () async {
    await build().ensureRegistered();

    expect(api.publishes, hasLength(1));
    expect(vault.entries[ChatKeyStore.identityKeyEntry], isNotNull);
    expect(vault.entries[ChatKeyStore.identityPublicEntry], isNotNull);
    expect(vault.entries[ChatKeyStore.identityOwnerEntry], me);

    // The private half stays here. Whatever went to the server must not carry
    // the `d` parameter, which is the entire private key.
    final publishedJwk =
        jsonDecode(api.publishes.single.$2) as Map<String, dynamic>;
    expect(publishedJwk.containsKey('d'), isFalse);
    expect(publishedJwk['crv'], 'P-256');

    // Published under this install's own device id, not a fixed or user-keyed
    // name — that is what makes a second device additive rather than
    // destructive.
    expect(api.publishes.single.$1, await build().deviceId());
  });

  test('reuses the stored key pair instead of generating a second one', () async {
    await build().ensureRegistered();
    final firstKey = vault.entries[ChatKeyStore.identityKeyEntry];
    final firstPublish = api.publishes.single;

    // A fresh store, as a relaunch of the app would build.
    await build().ensureRegistered();

    // The key pair itself is untouched...
    expect(vault.entries[ChatKeyStore.identityKeyEntry], firstKey);
    // ...but registering republishes every time, refreshing this device's
    // LastSeenAt on the server so it is not the one a prune drops.
    expect(api.publishes, hasLength(2));
    expect(api.publishes.last, firstPublish);
  });

  test('a second device registering does not touch the first device\'s row', () async {
    await build().ensureRegistered();
    final phoneDeviceId = await build().deviceId();

    // A second install for the same account — a fresh vault, so it mints its
    // own device id and key pair, exactly like the Trainer Console's desktop
    // build the first time someone signs in there.
    final desktopVault = InMemoryChatKeyVault();
    await ChatKeyStore(vault: desktopVault, api: api).ensureRegistered();
    final desktopDeviceId = await ChatKeyStore(vault: desktopVault, api: api).deviceId();

    expect(desktopDeviceId, isNot(phoneDeviceId));
    // This is the fix: two rows, not one overwriting the other. Under the old
    // single-key-per-user design this assertion would see exactly one entry —
    // the desktop's — with the phone's already gone.
    expect(api.published[me], hasLength(2));
    expect(api.published[me]!.containsKey(phoneDeviceId), isTrue);
    expect(api.published[me]!.containsKey(desktopDeviceId), isTrue);
  });

  test('regenerates when a different account signs in on this device', () async {
    await build().ensureRegistered();
    final firstKey = vault.entries[ChatKeyStore.identityKeyEntry];
    vault.entries['${ChatKeyStore.peerKeyPrefix}$peer'] = 'someone-elses-peer';

    final theirApi = FakeChatKeyApi(userId: someoneElse);
    await ChatKeyStore(vault: vault, api: theirApi).ensureRegistered();

    expect(vault.entries[ChatKeyStore.identityKeyEntry], isNot(firstKey));
    expect(vault.entries[ChatKeyStore.identityOwnerEntry], someoneElse);
    // The previous account's cached (legacy) peer keys are wrong for every
    // thread the new one has, and are not theirs to keep either.
    expect(vault.entries['${ChatKeyStore.peerKeyPrefix}$peer'], isNull);
  });

  test('keeps the device id across an account switch on the same install', () async {
    await build().ensureRegistered();
    final deviceId = await build().deviceId();

    final theirApi = FakeChatKeyApi(userId: someoneElse);
    await ChatKeyStore(vault: vault, api: theirApi).ensureRegistered();

    // The install did not change, only who is signed into it — the id that
    // names it on the server must survive exactly the wipe that clears
    // everything else.
    expect(await build().deviceId(), deviceId);
  });

  test('regenerates when only half the key pair survived', () async {
    await build().ensureRegistered();
    vault.entries.remove(ChatKeyStore.identityPublicEntry);

    await build().ensureRegistered();

    // A private key with no published public half encrypts messages nobody will
    // ever read, which looks exactly like working.
    expect(vault.entries[ChatKeyStore.identityPublicEntry], isNotNull);
    expect(api.publishes, hasLength(2));
  });

  test('targetDevices unions the peer\'s devices with this account\'s own', () async {
    final store = build();
    await store.ensureRegistered();
    final myDeviceId = await store.deviceId();

    api.published[peer] = {'peer-phone': 'peer-phone-jwk', 'peer-desktop': 'peer-desktop-jwk'};

    final targets = await store.targetDevices(peer);

    expect(targets.map((d) => d.deviceId), containsAll(['peer-phone', 'peer-desktop', myDeviceId]));
  });

  test('targetDevices is cached until forgetDevices clears it', () async {
    final store = build();
    await store.ensureRegistered();
    api.published[peer] = {'peer-phone': 'peer-phone-jwk'};

    await store.targetDevices(peer);
    await store.targetDevices(peer);

    // fetchMe + fetchPeer, once each — the second call must not repeat them.
    expect(api.fetchPeerCalls, 1);

    store.forgetDevices(peer);
    await store.targetDevices(peer);

    expect(api.fetchPeerCalls, 2);
  });

  test('the legacy (version 1) peer key is read from the "legacy" device row', () async {
    final store = build();
    await store.ensureRegistered();
    // The migration that introduced per-device keys republishes every
    // account's old single key under device id "legacy" — see
    // docs/chat-encryption.md.
    api.published[peer] = {'legacy': 'peer-legacy-jwk'};

    await store.peerKey(peer);
    await store.peerKey(peer);

    expect(api.fetchPeerCalls, 1);
    expect(vault.entries['${ChatKeyStore.peerKeyPrefix}$peer'], isNotNull);
  });

  test('forgetPeer forces the next legacy lookup back to the server', () async {
    final store = build();
    await store.ensureRegistered();
    api.published[peer] = {'legacy': 'peer-legacy-jwk'};

    await store.peerKey(peer);
    await store.forgetPeer(peer);
    await store.peerKey(peer);

    // Two fetches, and the vault entry actually cleared — dropping only the
    // in-memory copy would re-read the same stale key straight back off disk.
    expect(api.fetchPeerCalls, 2);
  });

  test('a peer who has never published a legacy key throws rather than encrypting to nothing', () async {
    final store = build();
    await store.ensureRegistered();

    expect(() => store.peerKey(peer), throwsStateError);
  });

  test('a peer with only non-legacy devices has no legacy key either', () async {
    final store = build();
    await store.ensureRegistered();
    api.published[peer] = {'peer-phone': 'peer-phone-jwk'};

    expect(() => store.peerKey(peer), throwsStateError);
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

  group('cache-only', () {
    test('reads a cached legacy peer key without any network', () async {
      final store = build();
      await store.ensureRegistered();
      api.published[peer] = {'legacy': 'peer-legacy-jwk'};
      await store.peerKey(peer);

      // What the push background isolate builds: a vault and nothing else.
      final offline = ChatKeyStore.cacheOnly(vault: vault);

      expect(await offline.identityKey(), isNotNull);
      expect(await offline.peerKey(peer), isNotNull);
      expect(await offline.deviceId(), isNotNull);
    });

    test('throws on an uncached peer rather than reaching for a locator', () async {
      await build().ensureRegistered();
      final offline = ChatKeyStore.cacheOnly(vault: vault);

      expect(() => offline.peerKey(peer), throwsStateError);
    });

    test('refuses to register', () async {
      expect(
        () => ChatKeyStore.cacheOnly(vault: vault).ensureRegistered(),
        throwsStateError,
      );
    });

    test('refuses to fetch a device list', () async {
      final offline = ChatKeyStore.cacheOnly(vault: vault);
      expect(() => offline.targetDevices(peer), throwsStateError);
    });
  });
}
