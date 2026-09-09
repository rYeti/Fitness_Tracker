import 'dart:convert';
import 'dart:typed_data';

import 'package:webcrypto/webcrypto.dart';

import 'package:ForgeForm/feature/chat/data/chat_key_store.dart';
import 'package:ForgeForm/feature/chat/domain/chat_crypto.dart';

/// ECDH P-256 + AES-256-GCM, over the `webcrypto` package.
///
/// Two schemes coexist — see `ChatEncryption`'s own doc comments for why:
///
/// * **v1** (`ecdhP256AesGcm`): the shared secret is derived from this
///   device's private key and one other device's, and encrypts the body
///   directly. Sent only when the peer's sole published device is the legacy
///   one, so a build old enough to have no device id can still read it.
/// * **v2** (`ecdhP256AesGcmWrapped`): the body is sealed once under a random
///   content key, which is then wrapped — itself AES-GCM-encrypted — once per
///   recipient device, using the same per-device ECDH derivation v1 uses for
///   the whole body. This is what makes a message readable on every device of
///   both parties without re-encrypting the body per device.
///
/// Both schemes share the same building block: a shared secret derived from
/// this device's private key and one specific *device's* public key. Both
/// sides of that derivation get the same 32 bytes from opposite halves, which
/// is why nothing has to be encrypted twice for two devices to read the same
/// bytes — a wrap and its unwrap use the same derivation, just run by the two
/// different devices that can each complete it.
class WebCryptoChatCrypto implements ChatCrypto {
  /// 96 bits — the IV length AES-GCM is specified for.
  ///
  /// Any other length is accepted by the implementation and quietly weaker,
  /// because GCM has to hash a non-96-bit IV down to 96 bits first. Nothing
  /// fails, nothing warns, and every message still decrypts.
  static const _ivLength = 12;

  final ChatKeyStore _keys;

  /// Derived secrets, keyed by *device* id rather than by conversation
  /// partner. A device's key pair does not change for the life of that
  /// device id — a reinstall mints a fresh id rather than reusing the old
  /// one — so the secret derived against it never goes stale the way a
  /// per-user cache did: rotation is handled entirely by
  /// `ChatKeyStore.forgetPeer` refreshing *which* devices exist, not by
  /// anything in this map needing to be invalidated.
  ///
  /// The one id that invariant does not hold for is
  /// `ChatKeyStore.legacyDeviceId` — the fixed all-zero sentinel every
  /// pre-migration row of *every* account shares, rather than a value that
  /// identifies one real device. `_sharedKeyFor` never reads or writes this
  /// cache for that id: a single `WebCryptoChatCrypto` instance serves a
  /// whole trainer console session across the entire roster, so caching
  /// under the shared sentinel would let one legacy peer's (or this
  /// account's own un-updated device's) derived secret get reused for an
  /// unrelated legacy peer encrypted or decrypted later in the same
  /// session — silently, since a wrong AES key still "succeeds" until the
  /// GCM tag check fails.
  final Map<String, AesGcmSecretKey> _shared = {};

  WebCryptoChatCrypto({required ChatKeyStore keys}) : _keys = keys;

  @override
  Future<EncryptedBody> encrypt({
    required String otherPartyId,
    required String plaintext,
  }) async {
    // Throws if the peer has never published anything at all — sending a
    // message nobody can read is worse than refusing to send it, per this
    // interface's own contract.
    final peerDevices = await _keys.peerKeys(otherPartyId);

    final isLegacyOnlyPeer =
        peerDevices.length == 1 &&
        peerDevices.containsKey(ChatKeyStore.legacyDeviceId);

    // A peer whose only published device is the legacy one is running a
    // build old enough to have no device id of its own, which also means old
    // enough to have no idea a wrapped envelope exists. v1 is what they can
    // still read.
    if (isLegacyOnlyPeer) {
      return _encryptV1(
        peerKey: peerDevices[ChatKeyStore.legacyDeviceId]!,
        plaintext: plaintext,
      );
    }

    return _encryptV2(peerDevices: peerDevices, plaintext: plaintext);
  }

  Future<EncryptedBody> _encryptV1({
    required EcdhPublicKey peerKey,
    required String plaintext,
  }) async {
    final key = await _sharedKeyFor(ChatKeyStore.legacyDeviceId, peerKey);

    final iv = Uint8List(_ivLength);
    fillRandomBytes(iv);

    final ciphertext = await key.encryptBytes(utf8.encode(plaintext), iv);

    return EncryptedBody(
      ciphertext: base64Encode(ciphertext),
      iv: base64Encode(iv),
      version: ChatEncryption.ecdhP256AesGcm,
    );
  }

  Future<EncryptedBody> _encryptV2({
    required Map<String, EcdhPublicKey> peerDevices,
    required String plaintext,
  }) async {
    final myDeviceId = await _keys.ownDeviceId();
    final myOtherDevices = await _keys.ownDeviceKeys();

    final contentKey = await AesGcmSecretKey.generateKey(256);
    final contentIv = Uint8List(_ivLength);
    fillRandomBytes(contentIv);
    final ciphertext = await contentKey.encryptBytes(
      utf8.encode(plaintext),
      contentIv,
    );
    final contentKeyBytes = await contentKey.exportRawKey();

    final wraps = <String, Map<String, String>>{};

    Future<void> wrapFor(String deviceId, EcdhPublicKey devicePublicKey) async {
      final wrapKey = await _sharedKeyFor(deviceId, devicePublicKey);
      final wrapIv = Uint8List(_ivLength);
      fillRandomBytes(wrapIv);
      final wrapped = await wrapKey.encryptBytes(contentKeyBytes, wrapIv);
      wraps[deviceId] = {'i': base64Encode(wrapIv), 'k': base64Encode(wrapped)};
    }

    for (final entry in peerDevices.entries) {
      await wrapFor(entry.key, entry.value);
    }
    // This account's own devices too — *including* the one sending this
    // message. Skipping it looked like a free optimisation (this device
    // already holds the plaintext it just produced, so it doesn't need its
    // own wrap to render the bubble it is about to show) and was wrong: the
    // plaintext-in-hand shortcut only covers the moment of sending
    // (`ChatRepository._attemptSend` builds the ack's bubble from the
    // plaintext it already has). Every later reload of this thread —
    // including on this exact device — calls `decrypt` on the *stored*
    // message like any other, with no plaintext left to fall back on. A
    // message this device cannot unwrap for itself is a message this device
    // can send once and never read again.
    for (final entry in myOtherDevices.entries) {
      await wrapFor(entry.key, entry.value);
    }

    final envelope = jsonEncode({
      'v': ChatEncryption.ecdhP256AesGcmWrapped,
      's': myDeviceId,
      'ct': base64Encode(ciphertext),
      'w': wraps,
    });

    return EncryptedBody(
      ciphertext: envelope,
      // The content IV travels in the existing Iv column — unlike a wrap's
      // own IV, which is per-device and therefore lives inside the envelope
      // next to the wrap it belongs to.
      iv: base64Encode(contentIv),
      version: ChatEncryption.ecdhP256AesGcmWrapped,
    );
  }

  @override
  Future<String?> decrypt({
    required String otherPartyId,
    required String? ciphertext,
    required String? iv,
    required int version,
  }) async {
    if (ciphertext == null) return null;

    // Written before encryption existed, so the "ciphertext" is the message.
    if (version == ChatEncryption.none) return ciphertext;

    if (version == ChatEncryption.ecdhP256AesGcm) {
      return _decryptV1(otherPartyId: otherPartyId, ciphertext: ciphertext, iv: iv);
    }

    if (version == ChatEncryption.ecdhP256AesGcmWrapped) {
      return _decryptV2(otherPartyId: otherPartyId, envelope: ciphertext, iv: iv);
    }

    return null;
  }

  Future<String?> _decryptV1({
    required String otherPartyId,
    required String ciphertext,
    required String? iv,
  }) async {
    if (iv == null) return null;

    try {
      final peerDevices = await _keys.peerKeys(otherPartyId);
      final ciphertextBytes = base64Decode(ciphertext);
      final ivBytes = base64Decode(iv);

      // v1 carries no sender-device field, unlike v2's explicit "s" — it
      // predates the idea that a party could have more than one key, so
      // there is no way to know from the envelope alone which of the peer's
      // devices actually encrypted it. Two genuinely different situations
      // produce a v1 body, and they don't agree on which device that is:
      // reading *old* history from before any device id existed resolves
      // against whichever of the peer's devices inherited that history's
      // key (their legacy row, ordinarily); a v1 message sent *because this
      // device itself* was the legacy-only party resolves against whichever
      // device the sender actually used, which is never their legacy row —
      // this device doesn't have one.
      //
      // Every currently-known device of the peer is therefore a candidate.
      // Usually there is only one. A wrong key fails the GCM tag check
      // cleanly, so trying a handful in turn against one short ciphertext is
      // safe and cheap — bounded by the per-user device cap, not by history
      // length.
      for (final entry in peerDevices.entries) {
        try {
          final key = await _sharedKeyFor(entry.key, entry.value);
          final plaintext = await key.decryptBytes(ciphertextBytes, ivBytes);
          return utf8.decode(plaintext);
        } catch (_) {
          continue;
        }
      }
      return null;
    } catch (_) {
      // Every failure lands here and every one of them means the same thing
      // to the reader: this device cannot read this message. A rotated peer
      // key, a reinstall, a truncated payload, a tag that does not verify --
      // telling them apart would let an attacker learn which, and there is
      // nothing different to do about any of them.
      return null;
    }
  }

  Future<String?> _decryptV2({
    required String otherPartyId,
    required String envelope,
    required String? iv,
  }) async {
    if (iv == null) return null;

    try {
      final decoded = jsonDecode(envelope) as Map<String, dynamic>;
      final wraps = decoded['w'] as Map<String, dynamic>;
      final senderDeviceId = decoded['s'] as String;

      final myDeviceId = await _keys.ownDeviceId();
      final myWrap = wraps[myDeviceId] as Map<String, dynamic>?;
      // This device was never a recipient of this particular message -- it
      // may have been minted after the message was sent, for instance. Same
      // outcome as any other missing key: unreadable, not an error.
      if (myWrap == null) return null;

      // The sender may be either this account's own other device (reading a
      // message back that was sent from elsewhere) or the peer's — a v2
      // sender is never assumed to be one or the other, because a message
      // from one of this account's own devices reaches every open thread,
      // not just the one whose peer happens to be it.
      final senderPublicKey = await _resolveDeviceKey(
        otherPartyId: otherPartyId,
        deviceId: senderDeviceId,
      );
      if (senderPublicKey == null) return null;

      final wrapKey = await _sharedKeyFor(senderDeviceId, senderPublicKey);
      final contentKeyBytes = await wrapKey.decryptBytes(
        base64Decode(myWrap['k'] as String),
        base64Decode(myWrap['i'] as String),
      );
      final contentKey = await AesGcmSecretKey.importRawKey(contentKeyBytes);

      final plaintext = await contentKey.decryptBytes(
        base64Decode(decoded['ct'] as String),
        base64Decode(iv),
      );
      return utf8.decode(plaintext);
    } catch (_) {
      return null;
    }
  }

  /// Resolves [deviceId]'s public key against this account's own other
  /// devices first, then [otherPartyId]'s — cheap-first, since the former is
  /// a vault read and the latter can be a network round trip.
  Future<EcdhPublicKey?> _resolveDeviceKey({
    required String otherPartyId,
    required String deviceId,
  }) async {
    final own = await _keys.ownDeviceKeys();
    final ownMatch = own[deviceId];
    if (ownMatch != null) return ownMatch;

    try {
      final peers = await _keys.peerKeys(otherPartyId);
      return peers[deviceId];
    } catch (_) {
      return null;
    }
  }

  @override
  // Only the peer's device list needs refreshing on a rotation — a real
  // device id's derived secret never goes stale, so `_shared` itself is
  // never touched here. `ChatKeyStore.legacyDeviceId` is the one id that
  // isn't a stable per-device identity, and `_sharedKeyFor` already refuses
  // to cache it at all, so there is nothing to invalidate for it either.
  Future<void> forget(String otherPartyId) => _keys.forgetPeer(otherPartyId);

  Future<AesGcmSecretKey> _sharedKeyFor(
    String deviceId,
    EcdhPublicKey devicePublicKey,
  ) async {
    // The legacy sentinel is shared by every pre-migration row of every
    // account, so it is not a safe cache key — see the field's own doc
    // comment. Derive fresh every time rather than risk one legacy party's
    // secret being reused for another's. Legacy traffic is inherently
    // transitional and rare, so this costs nothing worth optimising for.
    if (deviceId == ChatKeyStore.legacyDeviceId) {
      final mine = await _keys.identityKey();
      final bits = await mine.deriveBits(256, devicePublicKey);
      return AesGcmSecretKey.importRawKey(bits);
    }

    final cached = _shared[deviceId];
    if (cached != null) return cached;

    final mine = await _keys.identityKey();

    // 256 bits straight into the AES key, which is what the guide this
    // follows does. A KDF over the derived bits would be the textbook step
    // here; see docs/chat-encryption.md for why it is not taken and what
    // taking it later would cost.
    final bits = await mine.deriveBits(256, devicePublicKey);

    return _shared[deviceId] = await AesGcmSecretKey.importRawKey(bits);
  }
}
