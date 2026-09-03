import 'dart:convert';

import 'package:ForgeForm/core/providers/enums.dart';

/// A thumbnail's own encrypted object, separate from the attachment it belongs
/// to. Kept tiny and inline in the manifest deliberately — see
/// [ChatAttachmentRef]'s own doc comment.
class ChatAttachmentThumbRef {
  final String id;

  /// Base64 of the 32-byte AES-256-GCM key this thumbnail is sealed under.
  /// Independent of the full attachment's own key — see docs/chat-attachments.md.
  final String key;

  /// Base64 of the 12-byte IV.
  final String iv;

  /// Base64 SHA-256 of the *ciphertext* — lets the client detect a swapped or
  /// truncated object before spending time decrypting it, and doubles as the
  /// device media store's cache key.
  final String sha256;

  const ChatAttachmentThumbRef({
    required this.id,
    required this.key,
    required this.iv,
    required this.sha256,
  });

  factory ChatAttachmentThumbRef.fromJson(Map<String, dynamic> json) {
    return ChatAttachmentThumbRef(
      id: json['id'] as String,
      key: json['key'] as String,
      iv: json['iv'] as String,
      sha256: json['sha256'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'key': key,
    'iv': iv,
    'sha256': sha256,
  };
}

/// One attachment, as it travels inside the encrypted message body.
///
/// This is the whole reason the manifest can stay small enough to fit in a
/// push notification (see `PushNotificationService.MaxCiphertextBytes` on the
/// API side, 2600 bytes): the thumbnail is a *separate* encrypted object
/// referenced by [thumb], not inlined as base64 here. [avgColor] — eight
/// bytes — is the inline placeholder instead, rendered as a solid tile at the
/// right aspect ratio while the real bytes are still downloading.
///
/// The per-attachment key ([key]) is independent of the ECDH conversation key
/// the envelope itself travels under. That is what makes replay cheap: a
/// resend re-encrypts this whole manifest (a few hundred bytes) under a fresh
/// IV, never the file, because the file was never encrypted under the
/// conversation key in the first place. See docs/chat-attachments.md §B.1 and
/// §B.5.
class ChatAttachmentRef {
  /// Client-generated — the same id the mint/commit endpoints and the object
  /// key on the server are keyed by.
  final String id;

  final MediaType kind;
  final String mime;
  final String name;

  /// The size of the plaintext, in bytes — what a human reads on the bubble.
  /// The ciphertext the store actually holds is a little larger (the GCM tag).
  final int size;

  /// Base64 of the 32-byte AES-256-GCM key this attachment is sealed under.
  final String key;

  /// Base64 of the 12-byte IV.
  final String iv;

  /// Base64 SHA-256 of the ciphertext.
  final String sha256;

  /// Pixel dimensions, images and video only — lets the bubble reserve the
  /// right box before the bytes arrive, so the thread doesn't jump as each
  /// image loads in.
  final int? width;
  final int? height;

  /// A single average colour ("#8a7f6e") — the inline placeholder. See this
  /// class's own doc comment for why it's a colour and not a thumbnail.
  final String? avgColor;

  /// Duration in seconds, audio/video/voice notes only.
  final int? durationSeconds;

  final ChatAttachmentThumbRef? thumb;

  const ChatAttachmentRef({
    required this.id,
    required this.kind,
    required this.mime,
    required this.name,
    required this.size,
    required this.key,
    required this.iv,
    required this.sha256,
    this.width,
    this.height,
    this.avgColor,
    this.durationSeconds,
    this.thumb,
  });

  /// Null on any structurally invalid entry — an unparseable attachment must
  /// cost one item out of the manifest's list, never the whole message. The
  /// `kind` index is guarded the same way `ChatMessage.fromJson` guards
  /// `mediaType`: an index this build doesn't recognise renders as a generic
  /// document rather than throwing. See docs/chat-attachments.md §0.1 — this
  /// is the same lesson, applied where an *appended* enum value can actually
  /// reach a client for real (the server never writes `MediaType` on
  /// `ChatMessage`, but a manifest's `kind` is exactly that field, sent for
  /// real, by design).
  static ChatAttachmentRef? tryFromJson(Map<String, dynamic> json) {
    try {
      final kindIndex = json['kind'] as int?;
      final kind = kindIndex != null &&
              kindIndex >= 0 &&
              kindIndex < MediaType.values.length
          ? MediaType.values[kindIndex]
          : MediaType.document;

      final thumbJson = json['thumb'] as Map<String, dynamic>?;

      return ChatAttachmentRef(
        id: json['id'] as String,
        kind: kind,
        mime: json['mime'] as String? ?? 'application/octet-stream',
        name: json['name'] as String? ?? '',
        size: json['size'] as int,
        key: json['key'] as String,
        iv: json['iv'] as String,
        sha256: json['sha256'] as String,
        width: json['w'] as int?,
        height: json['h'] as int?,
        avgColor: json['avg'] as String?,
        durationSeconds: json['dur'] as int?,
        thumb: thumbJson == null ? null : ChatAttachmentThumbRef.fromJson(thumbJson),
      );
    } catch (_) {
      // Missing a required field, a wrong type — anything at all. One bad
      // entry becomes a document tile the user can't open, not a crash that
      // costs the whole message.
      return null;
    }
  }

  /// [tryFromJson] over a JSON string rather than an already-decoded map —
  /// what the outbox's `attachmentManifest` column stores. Null on anything
  /// that isn't valid JSON, same fail-soft contract as [tryFromJson] itself.
  static ChatAttachmentRef? tryFromJsonString(String? json) {
    if (json == null) return null;
    try {
      final decoded = jsonDecode(json);
      return decoded is Map<String, dynamic> ? tryFromJson(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  String toJsonString() => jsonEncode(toJson());

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.index,
    'mime': mime,
    'name': name,
    'size': size,
    'key': key,
    'iv': iv,
    'sha256': sha256,
    if (width != null) 'w': width,
    if (height != null) 'h': height,
    if (avgColor != null) 'avg': avgColor,
    if (durationSeconds != null) 'dur': durationSeconds,
    if (thumb != null) 'thumb': thumb!.toJson(),
  };
}
