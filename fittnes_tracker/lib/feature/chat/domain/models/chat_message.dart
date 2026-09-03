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

  /// 0 = plaintext, written before encryption existed. 1 = ECDH P-256 + AES-GCM.
  final int encryptionVersion;

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
    // Guarded rather than a bare index lookup: MediaType.values[media] threw
    // RangeError on any value this build doesn't know about, and that throw
    // happened inside loadThread's map over a whole history — one message
    // with an unrecognised kind took down the entire conversation. See
    // docs/chat-attachments.md §0.1. (In practice the server never writes
    // this field at all, for the same reason — but the client stays honest
    // about it independently rather than trusting that.)
    final mediaIndex = json['mediaType'] as int?;
    final media = mediaIndex != null &&
            mediaIndex >= 0 &&
            mediaIndex < MediaType.values.length
        ? MediaType.values[mediaIndex]
        : null;

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
      mediaType: media,
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
