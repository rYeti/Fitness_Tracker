import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:webcrypto/webcrypto.dart';

import 'package:ForgeForm/feature/chat/data/chat_key_api.dart';
import 'package:ForgeForm/feature/chat/data/chat_key_vault.dart';

/// This device's chat identity, and the public keys of everyone it talks to.
///
/// One ECDH P-256 key pair per install. The private half is generated here,
/// written to the platform keystore, and never leaves the device — there is no
/// backup and no recovery, which is the whole reason a reinstall cannot read
/// old messages. See docs/chat-encryption.md and docs/chat-multi-device-keys.md.
class ChatKeyStore {
  static const _uuid = Uuid();

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

  /// This install's own id — a UUID minted once and kept forever, under a
  /// fixed name for the same reason [identityKeyEntry] is: the push
  /// background isolate has to read it with no network.
  ///
  /// A property of the *install*, not the account: unlike the identity key
  /// pair, this is never cleared on an account switch (see
  /// [_forgetEverything]) — the same physical device keeps the same id no
  /// matter who is signed in on it, which is what lets the server tell two
  /// installs apart even when they take turns being signed into the same
  /// account.
  static const identityDeviceEntry = 'chat_identity_device';

  static const peerKeyPrefix = 'chat_peer_keys:';

  /// Every device *this account* currently has published a key for, cached
  /// from the `devices` list `GET api/chat/keys/me` returns — refreshed on
  /// every [ensureRegistered]. What lets [WebCryptoChatCrypto] wrap a
  /// message's content key for this account's other devices with no extra
  /// network call, and what lets the background push isolate resolve "was
  /// this sent from one of my own other devices" with none at all.
  static const ownKeysEntry = 'chat_own_keys';

  /// The one well-known device id a client built before device ids existed
  /// implicitly publishes under. Mirrors `UserChatKey.LegacyDeviceId` on the
  /// server — see that constant's own remarks for why a single specific id
  /// rather than "no device id" as a distinct state.
  static const legacyDeviceId = '00000000-0000-0000-0000-000000000000';

  final ChatKeyVault _vault;

  /// Null in cache-only mode. See [ChatKeyStore.cacheOnly].
  final ChatKeyApi? _api;

  EcdhPrivateKey? _identity;

  /// One peer's currently-known devices, by device id. A peer with two active
  /// installs (a phone and a laptop, say) needs a secret derived against
  /// *each* of them — see `WebCryptoChatCrypto`, which is what actually reads
  /// this map's values.
  final Map<String, Map<String, EcdhPublicKey>> _peers = {};

  /// This account's own other devices, by device id. Same shape as [_peers],
  /// kept separate because it answers a different question — not "who else
  /// is in this thread" but "who else can already read what I send," which
  /// includes devices with no thread of their own open at all.
  Map<String, EcdhPublicKey>? _ownDevices;

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

  /// Brings this device's key pair up, generating and publishing one if needed.
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
    final userId = me.userId;

    final owner = await _vault.read(identityOwnerEntry);
    if (owner != null && owner != userId) {
      // A different account signed in on this device. The previous account's
      // private key is not ours to keep, and its cached peer keys are about to
      // be wrong for every thread. The device id itself survives — see its
      // own doc comment.
      await _forgetEverything();
    }

    final deviceId = await _ensureDeviceId();

    final stored = await _vault.read(identityKeyEntry);
    final storedPublic = await _vault.read(identityPublicEntry);

    if (stored != null && storedPublic != null) {
      _identity = await EcdhPrivateKey.importJsonWebKey(
        jsonDecode(stored) as Map<String, dynamic>,
        EllipticCurve.p256,
      );

      // The comparison the original, single-key version of this method could
      // never make: "the server has no key for this device" and "the server
      // has a *different* device's key" used to be indistinguishable, because
      // there was only ever one row to check against. Republishing here is
      // what stops a second device's sign-in from silently orphaning this
      // one — this device's own row is what gets written, never anyone
      // else's, so there is nothing destructive about it.
      final mine = me.devices.where((d) => d.deviceId == deviceId).firstOrNull;
      if (mine == null || mine.publicKeyJwk != storedPublic) {
        await api.publish(storedPublic, deviceId: deviceId);
        await _vault.write(identityOwnerEntry, userId);
      }
      // [me] was fetched before the publish above, so by definition it does
      // not yet carry this device's own row when one was just written (the
      // `mine == null || ...` branch above). Caching it as-is would mean
      // this device is never among its own wrap targets, so every message it
      // sends becomes unreadable on the very device that sent it, on the
      // next `loadThread` — the self-wrap bug `_encryptV2`'s own doc comment
      // describes, reached from this method rather than from there. Splice
      // this device's own current row in explicitly instead of trusting
      // [me] to already have it; this also self-corrects the "present but
      // stale key" case, since the stale entry is filtered out by id before
      // the fresh one is added.
      final devicesToCache = [
        for (final d in me.devices)
          if (d.deviceId != deviceId) d,
        ChatKeyDevice(deviceId: deviceId, publicKeyJwk: storedPublic),
      ];
      await _cacheOwnDevices(devicesToCache);
      return;
    }

    // Either half missing means neither can be trusted -- a private key with no
    // published public half encrypts messages nobody will ever read.
    await _generate(api, deviceId);
    // The device list [me] carries predates the publish above by definition
    // (this device had no row yet when it was fetched), so it's refetched
    // rather than reused — the same reason a stale [me] would otherwise be
    // one send away from wrapping a content key for a device this account no
    // longer has, or missing the one it just gained.
    await _cacheOwnDevices((await api.fetchMe()).devices);
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

  /// This install's own device id.
  ///
  /// Throws if [ensureRegistered] has never run on this device — the same
  /// contract [identityKey] has, and for the same reason: a code path that
  /// forgot to register has no business encrypting anything.
  Future<String> ownDeviceId() async {
    final id = await _vault.read(identityDeviceEntry);
    if (id == null) {
      throw StateError(
        'No device id on this device. Call ensureRegistered() first.',
      );
    }
    return id;
  }

  /// This account's own other devices, keyed by device id.
  ///
  /// Empty — not an error — if [ensureRegistered] has never populated the
  /// cache, which is a real state: the cache-only background isolate never
  /// can, and an ordinary store that has never come online yet has nothing
  /// to report either. Both are read the same way a peer with no published
  /// key at all would be: nothing to wrap for, rather than a failure.
  Future<Map<String, EcdhPublicKey>> ownDeviceKeys() async {
    final cached = _ownDevices;
    if (cached != null) return cached;

    final stored = await _vault.read(ownKeysEntry);
    if (stored == null) return const {};

    final devices = [
      for (final entry in jsonDecode(stored) as List)
        ChatKeyDevice.fromJson(entry as Map<String, dynamic>),
    ];

    return _ownDevices = await _importAll(devices);
  }

  /// Persists [devices] as this account's own device list and drops the
  /// in-memory cache, so the next [ownDeviceKeys] call re-imports the fresh
  /// set rather than serving whatever was cached before this
  /// [ensureRegistered] call ran.
  Future<void> _cacheOwnDevices(List<ChatKeyDevice> devices) async {
    _ownDevices = null;
    await _vault.write(
      ownKeysEntry,
      jsonEncode([for (final d in devices) d.toJson()]),
    );
  }

  /// This install's own device id, minting one if none exists yet.
  ///
  /// Deliberately not folded into [ensureRegistered]'s body — [_generate] and
  /// the republish path both need it *before* they can talk to the server,
  /// and a background isolate reading [identityDeviceEntry] directly (were
  /// one ever to need to) should see the same minting behaviour rather than a
  /// second copy of it.
  Future<String> _ensureDeviceId() async {
    final existing = await _vault.read(identityDeviceEntry);
    if (existing != null) return existing;

    final id = _uuid.v4();
    await _vault.write(identityDeviceEntry, id);
    return id;
  }

  /// Every currently-published device for [otherPartyId], keyed by device id.
  ///
  /// Cached in the vault as well as in memory, because the push background
  /// isolate needs it and has no network stack of its own worth setting up for
  /// one lookup.
  ///
  /// Throws if the peer has never published one — sending a message nobody can
  /// read is worse than refusing to send it.
  Future<Map<String, EcdhPublicKey>> peerKeys(String otherPartyId) async {
    final cached = _peers[otherPartyId];
    if (cached != null) return cached;

    final entry = '$peerKeyPrefix$otherPartyId';
    var stored = await _vault.read(entry);

    List<ChatKeyDevice> devices;
    if (stored != null) {
      devices = [
        for (final entry in jsonDecode(stored) as List)
          ChatKeyDevice.fromJson(entry as Map<String, dynamic>),
      ];
    } else {
      final api = _api;
      if (api == null) {
        throw StateError('No cached chat key for $otherPartyId.');
      }
      final response = await api.fetchPeer(otherPartyId);
      if (response == null || response.devices.isEmpty) {
        throw StateError('$otherPartyId has no published chat key.');
      }
      devices = response.devices;
      await _vault.write(
        entry,
        jsonEncode([for (final d in devices) d.toJson()]),
      );
    }

    return _peers[otherPartyId] = await _importAll(devices);
  }

  /// Drops every cached device key for [otherPartyId] so the next
  /// [peerKeys] refetches the whole set.
  ///
  /// The recovery path for a peer whose device set changed: one of their
  /// installs reinstalled, or published a device id this cache has never
  /// seen. One forget-and-refetch fixes everything from that point on.
  Future<void> forgetPeer(String otherPartyId) async {
    _peers.remove(otherPartyId);
    await _vault.delete('$peerKeyPrefix$otherPartyId');
  }

  /// Imports every device's public JWK, skipping — not failing on — one that
  /// doesn't parse.
  ///
  /// One malformed entry must cost one device, not every device this party
  /// has: an unguarded loop here would let a single bad row (a future JWK
  /// shape this build doesn't recognise, a corrupted cache write) make every
  /// *other*, perfectly good device of that same peer unreachable too — the
  /// same failure shape `ChatBodyCodec.decode` and `ChatAttachmentRef.tryFromJson`
  /// already guard against for the same reason.
  Future<Map<String, EcdhPublicKey>> _importAll(
    List<ChatKeyDevice> devices,
  ) async {
    final imported = <String, EcdhPublicKey>{};
    for (final device in devices) {
      try {
        imported[device.deviceId] = await EcdhPublicKey.importJsonWebKey(
          jsonDecode(device.publicKeyJwk) as Map<String, dynamic>,
          EllipticCurve.p256,
        );
      } catch (_) {
        continue;
      }
    }
    return imported;
  }

  Future<void> _generate(ChatKeyApi api, String deviceId) async {
    final pair = await EcdhPrivateKey.generateKey(EllipticCurve.p256);

    final privateJwk = jsonEncode(await pair.privateKey.exportJsonWebKey());
    final publicJwk = jsonEncode(await pair.publicKey.exportJsonWebKey());

    // Published before it is stored. The other order can leave this device
    // holding a private key the world has no public half for, which looks
    // exactly like working right up until the first message is unreadable.
    final userId = await api.publish(publicJwk, deviceId: deviceId);

    await _vault.write(identityKeyEntry, privateJwk);
    await _vault.write(identityPublicEntry, publicJwk);
    await _vault.write(identityOwnerEntry, userId);
    _identity = pair.privateKey;
  }

  Future<void> _forgetEverything() async {
    _identity = null;
    _peers.clear();
    _ownDevices = null;
    await _vault.delete(identityKeyEntry);
    await _vault.delete(identityPublicEntry);
    await _vault.delete(identityOwnerEntry);
    await _vault.delete(ownKeysEntry);
    await _vault.deletePrefixed(peerKeyPrefix);
    // identityDeviceEntry is deliberately not cleared — see its own doc
    // comment. This physical install keeps its own id across an account
    // switch; only the identity *key*, the cached peers and the previous
    // account's own-device list belong to the account.
  }
}
