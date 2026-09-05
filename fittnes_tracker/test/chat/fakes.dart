import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/providers/enums.dart';
import 'package:ForgeForm/feature/chat/data/chat_api.dart';
import 'package:ForgeForm/feature/chat/data/chat_attachment_sender.dart';
import 'package:ForgeForm/feature/chat/data/chat_key_api.dart';
import 'package:ForgeForm/feature/chat/data/chat_key_vault.dart';
import 'package:ForgeForm/feature/chat/data/chat_signalr_client.dart';
import 'package:ForgeForm/feature/chat/data/voice_recorder.dart';
import 'package:ForgeForm/feature/chat/domain/attachment_crypto.dart';
import 'package:ForgeForm/feature/chat/domain/chat_crypto.dart';
import 'package:ForgeForm/feature/chat/domain/models/chat_attachment_ref.dart';
import 'package:ForgeForm/feature/chat/domain/models/chat_message.dart';

/// A real [AppDatabase] on an in-memory Sqlite file.
///
/// The outbox is the part of chat most worth testing directly (roadmap §1), and
/// it only behaves like itself against a real Drift executor — a hand-written
/// fake DAO would let the tests agree with themselves about ordering and
/// filtering rather than checking what Drift actually does.
AppDatabase newTestDatabase() => AppDatabase.test(NativeDatabase.memory());

/// Stands in for the SignalR connection.
///
/// Everything hard about chat happens in states a real socket won't reproduce on
/// demand: a send that never resolves, a send that throws, a reconnect firing at
/// an exact moment, the same message arriving twice. This fake makes each of
/// those a single line in a test, which is the whole reason [ChatSignalRClient]
/// is an interface rather than a concrete class.
class FakeChatSignalRClient implements ChatSignalRClient {
  final _incoming = StreamController<ChatMessage>.broadcast();
  final _reconnected = StreamController<void>.broadcast();
  final _status = StreamController<ChatConnectionStatus>.broadcast();

  /// Every `send` in call order — the assertion target for replay ordering and
  /// for "the retry reused the original messageId".
  ///
  /// Records the envelope as well as the body, so a test can assert that the
  /// wire carried ciphertext and that a replay did not reuse an IV.
  final List<
    ({
      String otherPartyId,
      String messageId,
      String body,
      String? iv,
      int encryptionVersion,
      List<String>? attachmentIds,
    })
  >
  sent = [];

  /// Group membership calls, so a test can assert the previous client's group is
  /// left before the next is joined.
  final List<String> joined = [];
  final List<String> left = [];

  bool connected = false;

  /// When set, `send` throws this instead of acking. Simulates "no ack" — which
  /// from the client's side is indistinguishable from "the server never got it".
  Object? throwOnSend;

  /// When non-null, `send` waits on this before completing, so a test can hold a
  /// message in flight and act while it is still pending.
  Completer<void>? holdSend;

  /// Fails only the first [failFirstNSends] calls, then acks. Models a bounded
  /// outage rather than a permanent one.
  int failFirstNSends = 0;

  /// When set, `joinGroup` throws this.
  ///
  /// Joining is the first network call a thread makes and the one most likely to
  /// fail in practice — the socket may still be opening, or the hub may reject
  /// the pair outright — but nothing exercised that path, so a bug that pinned
  /// the screen in its loading state forever went unnoticed.
  Object? throwOnJoin;

  @override
  Future<void> connect() async {
    connected = true;
    _status.add(ChatConnectionStatus.connected);
  }

  @override
  Future<void> disconnect() async {
    connected = false;
    _status.add(ChatConnectionStatus.disconnected);
  }

  @override
  Future<void> joinGroup(String otherPartyId) async {
    if (throwOnJoin != null) throw throwOnJoin!;
    joined.add(otherPartyId);
  }

  @override
  Future<void> leaveGroup(String otherPartyId) async => left.add(otherPartyId);

  @override
  Future<ChatMessage> send({
    required String otherPartyId,
    required String messageId,
    required String body,
    required String? iv,
    required int encryptionVersion,
    List<String>? attachmentIds,
  }) async {
    sent.add((
      otherPartyId: otherPartyId,
      messageId: messageId,
      body: body,
      iv: iv,
      encryptionVersion: encryptionVersion,
      attachmentIds: attachmentIds,
    ));

    if (holdSend != null) await holdSend!.future;

    if (failFirstNSends > 0) {
      failFirstNSends--;
      throw StateError('connection lost');
    }
    if (throwOnSend != null) throw throwOnSend!;

    // Acks with what the server would have stored, envelope included. Returning
    // the plaintext here would hide the bug this whole layer exists to prevent:
    // a repository that builds its bubble from `ack.body` rather than from the
    // plaintext it already holds puts base64 on screen.
    return ack(
      messageId: messageId,
      otherPartyId: otherPartyId,
      body: body,
      iv: iv,
      encryptionVersion: encryptionVersion,
    );
  }

  @override
  Stream<ChatMessage> get incomingMessages => _incoming.stream;

  @override
  Stream<void> get onReconnected => _reconnected.stream;

  @override
  Stream<ChatConnectionStatus> get connectionStatus => _status.stream;

  // ── Test controls ─────────────────────────────────────────────────────────

  /// Fires the reconnect signal that drives outbox replay (roadmap §4).
  void fireReconnected() => _reconnected.add(null);

  void emitStatus(ChatConnectionStatus status) => _status.add(status);

  /// Delivers a message as the hub's `ReceiveMessage` broadcast would.
  void emitIncoming(ChatMessage message) => _incoming.add(message);

  Future<void> dispose() async {
    await _incoming.close();
    await _reconnected.close();
    await _status.close();
  }

  /// Builds the DTO the hub returns/broadcasts. `senderId` defaults to the
  /// trainer, i.e. "mine" from the console's point of view.
  ChatMessage ack({
    required String messageId,
    required String otherPartyId,
    required String body,
    String? senderId,
    DateTime? sentAt,
    String? iv,
    int encryptionVersion = 0,
  }) {
    return ChatMessage(
      id: messageId,
      body: body,
      iv: iv,
      encryptionVersion: encryptionVersion,
      sentAt: sentAt ?? DateTime.now().toUtc(),
      senderId: senderId ?? trainerId,
      trainerId: trainerId,
      clientId: otherPartyId,
    );
  }

  /// Fixed id standing in for the signed-in trainer.
  static const trainerId = '11111111-1111-1111-1111-111111111111';
}

/// Serves canned history and conversation payloads without a network.
class FakeChatApi implements ChatApi {
  /// Raw history JSON per otherPartyId, in the shape `ChatMessageDto` serialises to.
  final Map<String, List<Map<String, dynamic>>> history;
  final List<Map<String, dynamic>> conversations;

  /// Set to make the matching call throw, for error-state tests.
  final bool throwOnHistory;
  final bool throwOnConversations;

  /// Fails the first N conversation fetches, then succeeds — so a test can check
  /// that a retry actually clears the error rather than only that it re-runs.
  int failConversationsTimes = 0;

  /// Completes only when a test says so, to hold a screen in its loading state.
  final Completer<void>? gate;

  /// Records `markRead` calls so a test can assert the endpoint was hit once.
  final List<String> markedRead = [];

  FakeChatApi({
    this.history = const {},
    this.conversations = const [],
    this.throwOnHistory = false,
    this.throwOnConversations = false,
    this.gate,
  });

  @override
  Future<List<Map<String, dynamic>>> fetchHistory(
    String otherPartyId, {
    int range = 50,
  }) async {
    if (gate != null) await gate!.future;
    if (throwOnHistory) throw Exception('boom');
    return history[otherPartyId] ?? const [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchConversations() async {
    if (gate != null) await gate!.future;
    if (failConversationsTimes > 0) {
      failConversationsTimes--;
      throw Exception('boom');
    }
    if (throwOnConversations) throw Exception('boom');
    return conversations;
  }

  @override
  Future<void> markRead(String otherPartyId) async =>
      markedRead.add(otherPartyId);
}

/// One server-side message in the JSON shape `ChatMessageDto` serialises to.
///
/// Guids and DateTimes cross the wire as strings and `MediaType` as an int (the
/// API configures no `JsonStringEnumConverter`), so the fixtures use those types
/// rather than Dart-native ones — otherwise the tests would exercise a parser
/// that never sees real input.
/// One history row as `ChatMessageDto` serialises it.
///
/// Defaults to encryption version 0 — a legacy plaintext row — so a test that
/// does not care about encryption reads exactly as it did before there was any.
/// Pass [encryptionVersion] and [iv] to write a row the way a current client
/// would.
Map<String, dynamic> messageJson({
  required String id,
  required String body,
  required String senderId,
  required String clientId,
  String trainerId = FakeChatSignalRClient.trainerId,
  DateTime? sentAt,
  String? iv,
  int encryptionVersion = 0,
}) {
  return {
    'id': id,
    'body': body,
    'iv': iv,
    'encryptionVersion': encryptionVersion,
    'sentAt': (sentAt ?? DateTime.now().toUtc()).toIso8601String(),
    'senderId': senderId,
    'trainerId': trainerId,
    'clientId': clientId,
    'mediaType': null,
    'url': null,
    'thumbnailUrl': null,
  };
}

/// Writes an outbox row directly, for tests that need a pre-existing unsent
/// message (e.g. "a pending message from a previous launch is replayed").
Future<void> seedOutboxRow(
  AppDatabase db, {
  required String messageId,
  required String otherPartyId,
  required String body,
  required DateTime createdAt,
  ChatMessageStatus status = ChatMessageStatus.pending,
}) {
  return db.chatoutboxDao.insertMessagePending(
    ChatOutBoxTableCompanion.insert(
      messageId: messageId,
      otherPartyId: otherPartyId,
      body: body,
      createdAt: createdAt,
      chatMessageStatus: Value(status.index),
    ),
  );
}

/// Stands in for the encryption boundary.
///
/// Reversible and inspectable rather than real: the point of most chat tests is
/// the outbox, the dedup and the replay, and running actual key derivation
/// through them would slow every one of them down to prove something
/// `chat_crypto_test.dart` already proves.
///
/// The transform is deliberately *not* the identity. A repository that forgot to
/// encrypt, or that rendered `ack.body` instead of the plaintext it was holding,
/// passes an identity-transform test and ships base64 to a user.
class FakeChatCrypto implements ChatCrypto {
  static const _marker = 'enc:';

  /// The ciphertext this fake produces for [plaintext].
  ///
  /// Tests assert against this rather than against a literal, so the marker is
  /// stated in one place — and so an assertion reads as "the wire carried the
  /// encrypted form" rather than as an unexplained string prefix.
  static String sealed(String plaintext) => '$_marker$plaintext';

  /// Peers whose messages cannot be decrypted, whichever direction they go.
  /// Models the peer having reinstalled since this device cached their key.
  final Set<String> undecryptablePeers = {};

  /// Peers with no published key at all, so `encrypt` throws as the real one
  /// does rather than silently sending something unreadable.
  final Set<String> keylessPeers = {};

  /// Every peer passed to [forget], in call order.
  final List<String> forgotten = [];

  /// Bumped per call so two encryptions of the same text differ, the way a fresh
  /// IV makes them differ for real.
  int _ivCounter = 0;

  @override
  Future<EncryptedBody> encrypt({
    required String otherPartyId,
    required String plaintext,
  }) async {
    if (keylessPeers.contains(otherPartyId)) {
      throw StateError('$otherPartyId has no published chat key.');
    }
    return EncryptedBody(
      ciphertext: '$_marker$plaintext',
      iv: 'iv-${_ivCounter++}',
      version: ChatEncryption.ecdhP256AesGcm,
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
    if (version == ChatEncryption.none) return ciphertext;
    if (undecryptablePeers.contains(otherPartyId)) return null;
    if (!ciphertext.startsWith(_marker)) return null;
    return ciphertext.substring(_marker.length);
  }

  @override
  Future<void> forget(String otherPartyId) async {
    forgotten.add(otherPartyId);
    undecryptablePeers.remove(otherPartyId);
  }
}

/// Stands in for the raw AES-256-GCM primitive [WebCryptoAttachmentCrypto]
/// wraps.
///
/// Deliberately *not* the identity transform, for the same reason
/// [FakeChatCrypto] isn't: an [AttachmentCrypto] fake that returns its input
/// unchanged makes ciphertext and plaintext indistinguishable, and a bug that
/// renders one where the other belongs passes every assertion.
class FakeAttachmentCrypto implements AttachmentCrypto {
  static const _xorByte = 0x5A;
  int sealCount = 0;

  /// When set, [open] returns null regardless of input — models a GCM tag
  /// that fails to verify.
  bool failOpen = false;

  static Uint8List _xor(Uint8List bytes) =>
      Uint8List.fromList([for (final b in bytes) b ^ _xorByte]);

  @override
  Future<SealedAttachment> seal(Uint8List plaintext) async {
    sealCount++;
    final key = Uint8List.fromList(List.filled(32, sealCount));
    final iv = Uint8List.fromList(List.filled(12, sealCount));
    return SealedAttachment(ciphertext: _xor(plaintext), key: key, iv: iv);
  }

  @override
  Future<Uint8List?> open(
    Uint8List ciphertext, {
    required Uint8List key,
    required Uint8List iv,
  }) async {
    if (failOpen) return null;
    return _xor(ciphertext);
  }
}

/// Stands in for [ChatAttachmentSender] — the mint/upload/PUT triangle — with
/// everything held in memory. `uploadCount` is the assertion target for "a
/// replay does not re-upload": [ChatRepository.replayPending] re-encrypts the
/// message envelope on every attempt, but the sealed attachment itself is
/// only ever supposed to reach this fake's `upload` once.
class FakeChatAttachmentSender implements ChatAttachmentSender {
  int sealCount = 0;
  int uploadCount = 0;

  /// Every attachment id this fake has accepted a PUT for, mapped to the
  /// bytes it received.
  final Map<String, Uint8List> uploaded = {};

  /// A fake filesystem — local path to bytes, so [readSealedBytes] and
  /// [deleteSealedBytes] behave like the real disk-backed implementation
  /// without touching one.
  final Map<String, Uint8List> localFiles = {};

  /// When set, the next [upload] call throws this instead of succeeding.
  Object? throwOnUpload;

  static const _xorByte = 0x5A;
  static Uint8List _xor(Uint8List bytes) =>
      Uint8List.fromList([for (final b in bytes) b ^ _xorByte]);

  @override
  Future<SealedAttachmentResult> seal({
    required Uint8List plaintext,
    required MediaType kind,
    required String mime,
    required String name,
    int? width,
    int? height,
    String? avgColor,
    int? durationSeconds,
    ChatAttachmentThumbRef? thumb,
  }) async {
    sealCount++;
    final id = 'fake-attachment-$sealCount';
    final ciphertext = _xor(plaintext);
    final ref = ChatAttachmentRef(
      id: id,
      kind: kind,
      mime: mime,
      name: name,
      size: plaintext.length,
      key: 'fake-key-$id',
      iv: 'fake-iv-$id',
      sha256: 'fake-sha-$id',
      width: width,
      height: height,
      avgColor: avgColor,
      durationSeconds: durationSeconds,
      thumb: thumb,
    );
    final localPath = 'fake:///$id';
    localFiles[localPath] = ciphertext;
    return SealedAttachmentResult(
      ref: ref,
      ciphertext: ciphertext,
      localPath: localPath,
    );
  }

  @override
  Future<void> upload({
    required String otherPartyId,
    required ChatAttachmentRef ref,
    required Uint8List ciphertext,
    void Function(int sent, int total)? onProgress,
  }) async {
    uploadCount++;
    if (throwOnUpload != null) {
      final error = throwOnUpload!;
      throwOnUpload = null;
      throw error;
    }
    uploaded[ref.id] = ciphertext;
  }

  @override
  Future<Uint8List?> readSealedBytes(String localPath) async =>
      localFiles[localPath];

  @override
  Future<void> deleteSealedBytes(String localPath) async =>
      localFiles.remove(localPath);
}

/// A [ChatKeyVault] backed by a plain map, so key-lifecycle tests do not need a
/// platform channel.
class InMemoryChatKeyVault implements ChatKeyVault {
  final Map<String, String> entries = {};

  @override
  Future<String?> read(String key) async => entries[key];

  @override
  Future<void> write(String key, String value) async => entries[key] = value;

  @override
  Future<void> delete(String key) async => entries.remove(key);

  @override
  Future<void> deletePrefixed(String prefix) async =>
      entries.removeWhere((key, _) => key.startsWith(prefix));
}

/// Stands in for `api/chat/keys`.
///
/// Holds one directory of published keys, so two [ChatKeyStore]s sharing an
/// instance behave like two devices talking to the same server.
class FakeChatKeyApi implements ChatKeyApi {
  /// Who this store's owner is, as the real `GET keys/me` would report.
  final String userId;

  /// Published public keys, by user id. Shared between instances when a test
  /// passes the same map, which is how one device sees another's key.
  final Map<String, String> published;

  /// Every `publish` in call order, so a test can assert a key was replaced
  /// rather than merely written locally.
  final List<String> publishes = [];

  int fetchMeCalls = 0;
  int fetchPeerCalls = 0;

  FakeChatKeyApi({required this.userId, Map<String, String>? published})
    : published = published ?? {};

  @override
  Future<Map<String, dynamic>> fetchMe() async {
    fetchMeCalls++;
    return {'userId': userId, 'publicKeyJwk': published[userId]};
  }

  @override
  Future<String> publish(String publicKeyJwk) async {
    publishes.add(publicKeyJwk);
    published[userId] = publicKeyJwk;
    return userId;
  }

  @override
  Future<String?> fetchPeer(String otherPartyId) async {
    fetchPeerCalls++;
    return published[otherPartyId];
  }
}

/// Stands in for [VoiceRecorder] — records nothing real, so composer tests
/// never touch a microphone or a platform channel.
class FakeVoiceRecorder implements VoiceRecorder {
  /// When false, [start] reports permission denied, like a real device whose
  /// user refused the mic prompt.
  bool permissionGranted = true;

  /// Fed to the [VoiceRecording] a subsequent [stop] returns.
  int nextDurationSeconds = 3;

  bool _recording = false;
  int stopCalls = 0;
  int cancelCalls = 0;

  @override
  bool get isRecording => _recording;

  @override
  int get elapsedSeconds => _recording ? nextDurationSeconds : 0;

  @override
  Future<bool> start() async {
    if (!permissionGranted) return false;
    _recording = true;
    return true;
  }

  @override
  Future<VoiceRecording?> stop() async {
    stopCalls++;
    if (!_recording) return null;
    _recording = false;
    if (nextDurationSeconds < 1) return null;
    return VoiceRecording(
      path: 'fake:///voice-note.m4a',
      durationSeconds: nextDurationSeconds,
    );
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    _recording = false;
  }

  @override
  Future<void> dispose() async {}
}
