import 'dart:convert';
import 'dart:math';

import 'package:webcrypto/webcrypto.dart';

import 'package:ForgeForm/feature/chat/data/chat_key_api.dart';
import 'package:ForgeForm/feature/chat/data/chat_key_vault.dart';

/// This device's chat identity, and the public keys of everyone it talks to.
///
/// One ECDH P-256 key pair per install. The private half is generated here,
/// written to the platform keystore, and never leaves the device — there is no
/// backup and no recovery, which is the whole reason a reinstall cannot read
/// old messages. See docs/chat-encryption.md.
///
/// Registering this device publishes its key **alongside** every other device
/// of the same account, never in place of one — see [ensureRegistered]. That
/// is what makes a second install (a phone and the Trainer Console's desktop
/// build, most commonly) additive instead of destructive.
class ChatKeyStore {
  /// The private JWK. Deliberately *not* keyed by user id: the background push
  /// isolate has to find this entry with no network and no way to ask who is
  /// signed in, so the key it looks under cannot depend on an answer only the
  /// server has.
  static const identityKeyEntry = 'chat_identity_key';

  /// Which account [identityKeyEntry] belongs to. Checked on every foreground
  /// resolve; a mismatch means somebody else signed in on this device and the
  /// key pair is regenerated from scratch.
  static const identityOwnerEntry = 'chat_identity_owner';

  /// The matching public JWK.
  ///
  /// Stored rather than derived on demand. Stripping `d` out of the private JWK
  /// looks like it would do, but the private key's `key_ops` say `deriveBits`,
  /// which an ECDH *public* key is not allowed to carry — the import rejects
  /// it. Keeping the exported public half is one entry and no surgery.
  static const identityPublicEntry = 'chat_identity_public';

  /// This install's own id — a random, opaque token with no meaning beyond
  /// "which row on the server is this device's". Minted once and kept across
  /// an account switch: it names the *install*, not the account, the same
  /// distinction `DeviceToken` already draws for push registration. The
  /// background push isolate needs to read it with no network, which is why
  /// it lives under a fixed name exactly like [identityKeyEntry].
  static const deviceIdEntry = 'chat_device_id';

  /// One cached legacy (encryption version 1) peer public key per
  /// conversation. Version 2 needs no cached peer key at all — every message
  /// carries its own ephemeral key — so this prefix now serves only the
  /// pairwise scheme kept around to read messages sent before this device
  /// upgraded. See [peerKey].
  static const peerKeyPrefix = 'chat_peer_key:';

  /// How long a fetched device list is trusted before [targetDevices] asks the
  /// server again. Long enough that sending several messages in a row costs
  /// one round trip, short enough that a peer's newly-registered device is
  /// picked up within a session rather than only on the next cold start.
  static const _deviceListTtl = Duration(minutes: 5);

  final ChatKeyVault _vault;

  /// Null in cache-only mode. See [ChatKeyStore.cacheOnly].
  final ChatKeyApi? _api;

  EcdhPrivateKey? _identity;
  final Map<String, EcdhPublicKey> _peers = {};

  final Map<String, (DateTime, List<DeviceKeyEntry>)> _deviceListCache = {};

  ChatKeyStore({ChatKeyVault? vault, ChatKeyApi? api})
    : _vault = vault ?? const SecureChatKeyVault(),
      _api = api ?? ChatKeyApi();

  /// A store that reads the vault and never the network.
  ///
  /// For the push background isolate, which has no service locator, no
  /// configured `ApiClient` and no business making an HTTP request to draw a
  /// notification. A peer whose key is not already cached simply cannot be
  /// decrypted there, and the notification falls back to the sender's name —
  /// which is the same thing that happens on any other decryption failure.
  ChatKeyStore.cacheOnly({ChatKeyVault? vault})
    : _vault = vault ?? const SecureChatKeyVault(),
      _api = null;

  /// This install's own id, minting and persisting one on first use.
  ///
  /// A plain random token rather than anything derived from the device or the
  /// account: it must be readable with no network by the background isolate,
  /// and it must survive a sign-out/sign-in on the same device (unlike the key
  /// pair itself) so the server-side row a peer already resolved keeps meaning
  /// the same install.
  Future<String> deviceId() async {
    final existing = await _vault.read(deviceIdEntry);
    if (existing != null) return existing;

    final id = _randomId();
    await _vault.write(deviceIdEntry, id);
    return id;
  }

  static String _randomId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Brings this device's key pair up, generating one only if needed, and
  /// (re)publishing it alongside every other device already registered for
  /// this account.
  ///
  /// Call once when a chat surface comes up — `ChatRepository` does it as part
  /// of connecting. It is the only method that talks to the server about our
  /// own key, and the only one that can decide the account has changed.
  Future<void> ensureRegistered() async {
    final api = _api;
    if (api == null) {
      throw StateError('A cache-only ChatKeyStore cannot register a key.');
    }

    final me = await api.fetchMe();
    final userId = me['userId'] as String;
    final device = await deviceId();

    final owner = await _vault.read(identityOwnerEntry);
    if (owner != null && owner != userId) {
      // A different account signed in on this device. The previous account's
      // private key is not ours to keep, and its cached (legacy) peer keys
      // are about to be wrong for every thread. The device id itself is kept
      // — it names the install, not the account.
      await _forgetEverything();
    }

    final stored = await _vault.read(identityKeyEntry);
    final storedPublic = await _vault.read(identityPublicEntry);

    if (stored != null && storedPublic != null) {
      _identity = await EcdhPrivateKey.importJsonWebKey(
        jsonDecode(stored) as Map<String, dynamic>,
        EllipticCurve.p256,
      );

      // Registering is idempotent and additive, so it is always worth doing
      // again rather than only when the server has "lost" the row — that was
      // the old (single-key-per-user) design's shortcut, and doing it every
      // time here is what keeps LastSeenAt honest for the prune the server
      // applies per account.
      await api.publish(device, storedPublic);
      await _vault.write(identityOwnerEntry, userId);
      return;
    }

    // Either half missing means neither can be trusted -- a private key with no
    // published public half encrypts messages nobody will ever read.
    await _generate(api, device);
  }

  /// The private half, imported once and kept in memory.
  ///
  /// Throws if [ensureRegistered] has not run. That is deliberate: silently
  /// generating a key pair here would mean any code path that forgot to
  /// register could mint an identity the server has never heard of, and every
  /// message it sent would be unreadable by the recipient.
  Future<EcdhPrivateKey> identityKey() async {
    final key = _identity;
    if (key != null) return key;

    final stored = await _vault.read(identityKeyEntry);
    if (stored == null) {
      throw StateError(
        'No chat identity key on this device. Call ensureRegistered() first.',
      );
    }

    return _identity = await EcdhPrivateKey.importJsonWebKey(
      jsonDecode(stored) as Map<String, dynamic>,
      EllipticCurve.p256,
    );
  }

  /// Every device that should be able to read a message sent to
  /// [otherPartyId] — the peer's registered devices *and* this account's own
  /// (the sender's own device included, so the sender can read its own
  /// message back with no special-casing).
  ///
  /// Cached briefly per peer (see [_deviceListTtl]) so sending several
  /// messages in a row, or scrolling a long thread, does not cost one round
  /// trip per message.
  Future<List<DeviceKeyEntry>> targetDevices(String otherPartyId) async {
    final api = _api;
    if (api == null) {
      throw StateError('A cache-only ChatKeyStore cannot fetch device lists.');
    }

    final cached = _deviceListCache[otherPartyId];
    if (cached != null && DateTime.now().difference(cached.$1) < _deviceListTtl) {
      return cached.$2;
    }

    final me = await api.fetchMe();
    final own = ChatKeyApi.devicesOf(me);
    final peer = await api.fetchPeer(otherPartyId) ?? const [];

    final devices = [...own, ...peer];
    _deviceListCache[otherPartyId] = (DateTime.now(), devices);
    return devices;
  }

  /// Drops the cached device list for [otherPartyId], forcing the next
  /// [targetDevices] call to ask the server again. Used the same way
  /// [forgetPeer] is for the legacy scheme: something about who can read this
  /// thread just changed.
  void forgetDevices(String otherPartyId) {
    _deviceListCache.remove(otherPartyId);
  }

  /// The other party's **legacy (version 1)** public key — the pairwise
  /// scheme kept around only so a message sent before this device's account
  /// moved to per-device keys stays readable. Version 2 never calls this: it
  /// carries its own ephemeral key and needs no cached peer key at all.
  ///
  /// Cached in the vault as well as in memory, because the push background
  /// isolate needs it and has no network stack of its own worth setting up for
  /// one lookup.
  ///
  /// Throws if the peer has never published one — sending a message nobody can
  /// read is worse than refusing to send it.
  Future<EcdhPublicKey> peerKey(String otherPartyId) async {
    final cached = _peers[otherPartyId];
    if (cached != null) return cached;

    final entry = '$peerKeyPrefix$otherPartyId';
    var jwk = await _vault.read(entry);

    if (jwk == null) {
      final api = _api;
      if (api == null) {
        throw StateError('No cached chat key for $otherPartyId.');
      }
      final devices = await api.fetchPeer(otherPartyId);
      // The legacy row is always published under device id "legacy" — see the
      // migration that introduced per-device keys.
      final legacy = devices?.where((d) => d.deviceId == 'legacy').firstOrNull;
      if (legacy == null) {
        throw StateError('$otherPartyId has no published chat key.');
      }
      jwk = legacy.publicKeyJwk;
      await _vault.write(entry, jwk);
    }

    return _peers[otherPartyId] = await EcdhPublicKey.importJsonWebKey(
      jsonDecode(jwk) as Map<String, dynamic>,
      EllipticCurve.p256,
    );
  }

  /// Drops a cached peer key so the next [peerKey] refetches it.
  ///
  /// The recovery path for a peer who reinstalled: their published key changed,
  /// ours did not, and every message they send now fails to decrypt against the
  /// key we cached. One forget-and-refetch fixes everything from that point on.
  /// Legacy (version 1) only — version 2 has no equivalent failure mode, since
  /// it never caches a peer key in the first place.
  Future<void> forgetPeer(String otherPartyId) async {
    _peers.remove(otherPartyId);
    await _vault.delete('$peerKeyPrefix$otherPartyId');
  }

  Future<void> _generate(ChatKeyApi api, String deviceId) async {
    final pair = await EcdhPrivateKey.generateKey(EllipticCurve.p256);

    final privateJwk = jsonEncode(await pair.privateKey.exportJsonWebKey());
    final publicJwk = jsonEncode(await pair.publicKey.exportJsonWebKey());

    // Published before it is stored. The other order can leave this device
    // holding a private key the world has no public half for, which looks
    // exactly like working right up until the first message is unreadable.
    final userId = await api.publish(deviceId, publicJwk);

    await _vault.write(identityKeyEntry, privateJwk);
    await _vault.write(identityPublicEntry, publicJwk);
    await _vault.write(identityOwnerEntry, userId);
    _identity = pair.privateKey;
  }

  Future<void> _forgetEverything() async {
    _identity = null;
    _peers.clear();
    _deviceListCache.clear();
    await _vault.delete(identityKeyEntry);
    await _vault.delete(identityPublicEntry);
    await _vault.delete(identityOwnerEntry);
    await _vault.deletePrefixed(peerKeyPrefix);
    // deviceIdEntry is deliberately left alone -- it names this install, not
    // the account that just signed out of it.
  }
}
