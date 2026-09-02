import 'package:ForgeForm/core/providers/enums.dart';
import 'package:ForgeForm/feature/chat/domain/chat_timestamps.dart';

class ChatMessage {
  final String id;

  /// The body exactly as the server stored it.
  ///
  /// Ciphertext from [encryptionVersion] 1 onward — this is *not* something to
  /// put on screen. `ChatRepository` decrypts on the way past; every surface
  /// above it sees plaintext or a null it must render as unreadable.
  final String? body;

  /// Base64 of the AES-GCM IV [body] was encrypted under. Null for a legacy row.
  final String? iv;

  /// 0 = plaintext. 1 = pairwise ECDH P-256 + AES-GCM (one key per account).
  /// 2 = per-device ECDH P-256 + AES-GCM (a wrapped content key per device).
  final int encryptionVersion;

  /// The message's own ephemeral ECDH public key. Present only for
  /// [encryptionVersion] 2.
  final String? ephemeralPublicKeyJwk;

  /// This device's own wrapped copy of the content key, resolved server-side
  /// against the `deviceId` this client sent. Null when the message predates
  /// this device, or under version 0/1 — the ordinary shape of "cannot be
  /// decrypted here", not an error.
  final String? wrappedKey;

  /// Base64 IV [wrappedKey] was wrapped under.
  final String? wrappedKeyIv;

  /// True when this message arrived with a body this device could not decrypt.
  ///
  /// Distinct from a null [body] on its own, which also describes an
  /// attachment-only message — a message with nothing to say and a message this
  /// device cannot read are not the same thing, and only one of them needs
  /// explaining to the reader.
  ///
  /// Only ever set by [decrypted]; a message straight off the wire has not been
  /// asked yet.
  final bool isUndecryptable;

  /// When the server says the message was sent, as a UTC instant.
  ///
  /// Always UTC, never a local wall-clock time — see [ChatTimestamps.parseInstant]
  /// for why the difference is not academic. Every surface converts on the way
  /// to the screen and nowhere else.
  final DateTime sentAt;
  final String senderId;
  final String trainerId;
  final String clientId;
  final MediaType? mediaType;
  final String? url;
  final String? thumbnailUrl;

  const ChatMessage({
    required this.id,
    this.body,
    this.iv,
    this.encryptionVersion = 0,
    this.ephemeralPublicKeyJwk,
    this.wrappedKey,
    this.wrappedKeyIv,
    this.isUndecryptable = false,
    required this.sentAt,
    required this.senderId,
    required this.trainerId,
    required this.clientId,
    this.mediaType,
    this.url,
    this.thumbnailUrl,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final media = json['mediaType'] as int?;

    return ChatMessage(
      id: json['id'] as String,
      clientId: json['clientId'] as String,
      senderId: json['senderId'] as String,
      trainerId: json['trainerId'] as String,
      // A message whose timestamp the payload cannot supply is dated to the
      // moment it reached this device rather than left to render as
      // `DateTime.parse`'s idea of nothing. A missing or malformed `sentAt` used
      // to reach the thread as the year 1 and be drawn as a "01/01/0001" day
      // divider; approximately-now is wrong by seconds instead of by two
      // millennia, and puts the bubble where the reader just watched it arrive.
      sentAt: ChatTimestamps.parseInstant(json['sentAt']) ?? DateTime.now().toUtc(),
      body: json['body'] as String?,
      iv: json['iv'] as String?,
      // Defaulted rather than required. A payload with no version is one the
      // server wrote before this field existed, and those bodies really are
      // plaintext -- guessing 1 for them would render every legacy message as
      // undecryptable.
      encryptionVersion: json['encryptionVersion'] as int? ?? 0,
      ephemeralPublicKeyJwk: json['ephemeralPublicKeyJwk'] as String?,
      wrappedKey: json['wrappedKey'] as String?,
      wrappedKeyIv: json['wrappedIv'] as String?,
      mediaType: media == null ? null : MediaType.values[media],
      url: json['url'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }

  /// The same message with [body] replaced by its plaintext.
  ///
  /// Produced by `ChatRepository` the moment a message arrives, so that
  /// everything above it deals in readable text and nothing else has to know
  /// this type ever carried ciphertext. [encryptionVersion] is reset to 0
  /// because that is now true of the copy: the body in hand is plaintext.
  ChatMessage decrypted(String? plaintext) {
    return ChatMessage(
      id: id,
      body: plaintext,
      // A body that arrived with content and came back without it is one the
      // key for is gone. A body that was empty to begin with is just empty.
      isUndecryptable: plaintext == null && body != null,
      sentAt: sentAt,
      senderId: senderId,
      trainerId: trainerId,
      clientId: clientId,
      mediaType: mediaType,
      url: url,
      thumbnailUrl: thumbnailUrl,
    );
  }
}
