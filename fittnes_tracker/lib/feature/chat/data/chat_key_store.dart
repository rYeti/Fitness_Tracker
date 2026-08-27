import 'dart:convert';

import 'package:webcrypto/webcrypto.dart';

import 'package:ForgeForm/feature/chat/data/chat_key_api.dart';
import 'package:ForgeForm/feature/chat/data/chat_key_vault.dart';

/// This device's chat identity, and the public keys of everyone it talks to.
///
/// One ECDH P-256 key pair per install. The private half is generated here,
/// written to the platform keystore, and never leaves the device — there is no
/// backup and no recovery, which is the whole reason a reinstall cannot read
/// old messages. See docs/chat-encryption.md.
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

  static const peerKeyPrefix = 'chat_peer_key:';

  final ChatKeyVault _vault;

  /// Null in cache-only mode. See [ChatKeyStore.cacheOnly].
  final ChatKeyApi? _api;

  EcdhPrivateKey? _identity;
  final Map<String, EcdhPublicKey> _peers = {};

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
    final userId = me['userId'] as String;
    final published = me['publicKeyJwk'] as String?;

    final owner = await _vault.read(identityOwnerEntry);
    if (owner != null && owner != userId) {
      // A different account signed in on this device. The previous account's
      // private key is not ours to keep, and its cached peer keys are about to
      // be wrong for every thread.
      await _forgetEverything();
    }

    final stored = await _vault.read(identityKeyEntry);
    final storedPublic = await _vault.read(identityPublicEntry);

    if (stored != null && storedPublic != null) {
      _identity = await EcdhPrivateKey.importJsonWebKey(
        jsonDecode(stored) as Map<String, dynamic>,
        EllipticCurve.p256,
      );
      // Re-published when the server has none, which covers the case that
      // matters: the row was lost, and this device is still holding the only
      // usable private half.
      if (published == null) {
        await api.publish(storedPublic);
        await _vault.write(identityOwnerEntry, userId);
      }
      return;
    }

    // Either half missing means neither can be trusted -- a private key with no
    // published public half encrypts messages nobody will ever read.
    await _generate(api);
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

  /// The other party's public key.
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
      jwk = await api.fetchPeer(otherPartyId);
      if (jwk == null) {
        throw StateError('$otherPartyId has no published chat key.');
      }
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
  Future<void> forgetPeer(String otherPartyId) async {
    _peers.remove(otherPartyId);
    await _vault.delete('$peerKeyPrefix$otherPartyId');
  }

  Future<void> _generate(ChatKeyApi api) async {
    final pair = await EcdhPrivateKey.generateKey(EllipticCurve.p256);

    final privateJwk = jsonEncode(await pair.privateKey.exportJsonWebKey());
    final publicJwk = jsonEncode(await pair.publicKey.exportJsonWebKey());

    // Published before it is stored. The other order can leave this device
    // holding a private key the world has no public half for, which looks
    // exactly like working right up until the first message is unreadable.
    final userId = await api.publish(publicJwk);

    await _vault.write(identityKeyEntry, privateJwk);
    await _vault.write(identityPublicEntry, publicJwk);
    await _vault.write(identityOwnerEntry, userId);
    _identity = pair.privateKey;
  }

  Future<void> _forgetEverything() async {
    _identity = null;
    _peers.clear();
    await _vault.delete(identityKeyEntry);
    await _vault.delete(identityPublicEntry);
    await _vault.delete(identityOwnerEntry);
    await _vault.deletePrefixed(peerKeyPrefix);
  }
}
