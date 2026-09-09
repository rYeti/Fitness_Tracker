import 'package:flutter/foundation.dart';

/// What the server will actually accept, asked once per chat session.
///
/// This exists because the alternative — assuming — is what shipped, and it
/// failed in the one way nobody looked at. `GET api/chat/attachments/capabilities`
/// has been on the API since the attachment feature landed, and
/// `DisabledChatAttachmentStore`'s own remarks say every method of it throws
/// "on the assumption that the one caller of this interface always checks
/// `IsConfigured` first via the capabilities endpoint". No client ever did.
/// With no blob store configured, the attach button was shown anyway, the mint
/// threw, and every upload failed with a retry that could never work. See
/// docs/chat-attachments.md.
///
/// [disabled] is the value a client holds until the real one arrives, and the
/// value it falls back to when the request fails. Fail-closed: an affordance
/// briefly missing is a smaller lie than one that is always offered and always
/// fails.
@immutable
class ChatAttachmentCapabilities {
  final bool enabled;

  /// The ciphertext cap for every kind but video — image, document, audio and
  /// voice note all share it, matching `ChatAttachmentService`'s own split.
  final int maxImageBytes;

  final int maxVideoBytes;

  /// How long a blob survives server-side. Mirrors `Attachments:RetentionDays`,
  /// so `ChatAttachmentProvider` can stop hardcoding it.
  final int retentionDays;

  const ChatAttachmentCapabilities({
    required this.enabled,
    required this.maxImageBytes,
    required this.maxVideoBytes,
    required this.retentionDays,
  });

  /// What a client believes before it has been told otherwise.
  ///
  /// The byte caps are the API's own defaults rather than zero: they are only
  /// ever read on a path that [enabled] already gates, and a zero would turn a
  /// "not yet asked" state into "every file is too large" if that ever stopped
  /// being true.
  static const disabled = ChatAttachmentCapabilities(
    enabled: false,
    maxImageBytes: 8 * 1024 * 1024,
    maxVideoBytes: 16 * 1024 * 1024,
    retentionDays: 45,
  );

  /// Tolerant of a missing field on purpose. A capabilities response that has
  /// grown or lost a key must not be the thing that stops chat working — an
  /// absent number falls back to [disabled]'s, and only `enabled` is really
  /// load-bearing.
  factory ChatAttachmentCapabilities.fromJson(Map<String, dynamic> json) {
    return ChatAttachmentCapabilities(
      enabled: json['enabled'] as bool? ?? false,
      maxImageBytes:
          (json['maxImageBytes'] as num?)?.toInt() ?? disabled.maxImageBytes,
      maxVideoBytes:
          (json['maxVideoBytes'] as num?)?.toInt() ?? disabled.maxVideoBytes,
      retentionDays:
          (json['retentionDays'] as num?)?.toInt() ?? disabled.retentionDays,
    );
  }

  /// The cap that applies to [isVideo], in *ciphertext* bytes.
  ///
  /// Every caller must compare a plaintext length against [plaintextCapFor],
  /// not this — see that method for the 16 bytes that separate them.
  int ciphertextCapFor({required bool isVideo}) =>
      isVideo ? maxVideoBytes : maxImageBytes;

  /// The cap that applies to [isVideo], in *plaintext* bytes.
  ///
  /// AES-256-GCM appends a 16-byte authentication tag, and what the client
  /// declares at mint time is the ciphertext length
  /// (`ChatAttachmentSender.upload`), which the server compares against its
  /// cap. A client that checks the plaintext against the same number therefore
  /// admits a file in the top 16 bytes of the cap, seals it, writes the outbox
  /// row, and only then gets `attachment_too_large` back — surfaced as a
  /// generic "upload failed" with a retry that re-declares the identical
  /// length and fails identically, for ever.
  int plaintextCapFor({required bool isVideo}) =>
      ciphertextCapFor(isVideo: isVideo) - gcmTagBytes;

  /// AES-GCM's authentication tag, appended to every ciphertext.
  static const gcmTagBytes = 16;
}
