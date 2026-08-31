import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/feature/chat/data/chat_key_store.dart';

import 'fakes.dart';

/// The key lifecycle: generate once, publish once, survive sign-out, and start
/// over when a different account signs in.
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

    // The private half stays here. Whatever went to the server must not carry
    // the `d` parameter, which is the entire private key.
    final publishedJwk =
        jsonDecode(api.publishes.single) as Map<String, dynamic>;
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

  test('republishes when the server has lost the key but this device has not', () async {
    await build().ensureRegistered();
    final storedKey = vault.entries[ChatKeyStore.identityKeyEntry];

    api.published.remove(me);
    await build().ensureRegistered();

    // Republished, not regenerated. This device still holds the only private
    // half that can read its existing conversations.
    expect(vault.entries[ChatKeyStore.identityKeyEntry], storedKey);
    expect(api.publishes, hasLength(2));
    expect(api.publishes.last, api.publishes.first);
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

  test('regenerates when only half the key pair survived', () async {
    await build().ensureRegistered();
    vault.entries.remove(ChatKeyStore.identityPublicEntry);

    await build().ensureRegistered();

    // A private key with no published public half encrypts messages nobody will
    // ever read, which looks exactly like working.
    expect(vault.entries[ChatKeyStore.identityPublicEntry], isNotNull);
    expect(api.publishes, hasLength(2));
  });

  test('caches a peer key after fetching it once', () async {
    final store = build();
    await store.ensureRegistered();
    api.published[peer] = api.published[me]!;

    await store.peerKey(peer);
    await store.peerKey(peer);

    expect(api.fetchPeerCalls, 1);
    expect(vault.entries['${ChatKeyStore.peerKeyPrefix}$peer'], isNotNull);
  });

  test('forgetPeer forces the next lookup back to the server', () async {
    final store = build();
    await store.ensureRegistered();
    api.published[peer] = api.published[me]!;

    await store.peerKey(peer);
    await store.forgetPeer(peer);
    await store.peerKey(peer);

    // Two fetches, and the vault entry actually cleared — dropping only the
    // in-memory copy would re-read the same stale key straight back off disk.
    expect(api.fetchPeerCalls, 2);
  });

  test('a peer who has never published a key throws rather than encrypting to nothing', () async {
    final store = build();
    await store.ensureRegistered();

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
    test('reads a cached peer key without any network', () async {
      final store = build();
      await store.ensureRegistered();
      api.published[peer] = api.published[me]!;
      await store.peerKey(peer);

      // What the push background isolate builds: a vault and nothing else.
      final offline = ChatKeyStore.cacheOnly(vault: vault);

      expect(await offline.identityKey(), isNotNull);
      expect(await offline.peerKey(peer), isNotNull);
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
  });
}
