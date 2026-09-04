import 'dart:convert';

import 'package:ForgeForm/core/providers/enums.dart';
import 'package:ForgeForm/feature/chat/domain/models/chat_attachment_ref.dart';

/// A decoded message body — whatever [ChatBodyCodec.decode] made of the
/// plaintext [ChatCrypto.decrypt] handed back.
class ChatBody {
  /// The caption, or the whole message for a text-only send. Never null: an
  /// attachment with nothing typed alongside it still has to render *some*
  /// text, and that's [ChatAttachmentRef.kind]'s label, decided by the widget
  /// layer — this class only carries what was actually in the envelope.
  final String? caption;

  final List<ChatAttachmentRef> attachments;

  const ChatBody({this.caption, this.attachments = const []});

  bool get hasAttachment => attachments.isNotEmpty;
}

/// The boundary between "what `ChatCrypto` encrypts" and "what a caption and
/// an attachment actually are".
///
/// Everything below [ChatCrypto.encrypt] deals in one opaque plaintext
/// string; everything above this class deals in a caption plus a typed list
/// of attachments. In between, this codec decides whether that string is a
/// plain sentence (the overwhelming common case, and the only case before
/// this feature existed) or a JSON envelope carrying one or more attachment
/// manifests.
///
/// See docs/chat-attachments.md §B.1 for the full reasoning; the load-bearing
/// points are:
///
/// - **Text messages are byte-for-byte unchanged.** [encode] with no
///   attachments returns the caption exactly as typed — nothing on the wire
///   moves for the common case, and every already-shipped build keeps working
///   without modification.
/// - **Detection is a guarded prefix test, never a bare `jsonDecode`.** A
///   user who types a message starting with `{"note"` must still see it
///   rendered as their own text, not misparsed as a manifest.
/// - **No `EncryptionVersion` bump.** That field describes *how* bytes were
///   protected, not *what they mean* — `ChatCrypto` is byte-in/byte-out and
///   cannot tell a manifest from a sentence, and spending the version number
///   on a body-format change would leave the next real cryptographic scheme
///   without one that means what it says.
class ChatBodyCodec {
  ChatBodyCodec._();

  /// The envelope format version — inside the JSON, not `EncryptionVersion`.
  /// Bump this, not the crypto version, if the envelope's shape ever changes.
  static const int _envelopeVersion = 1;

  static const _prefix = '{"note"';

  /// Builds the plaintext to hand to [ChatCrypto.encrypt]. Returns
  /// [caption] unchanged when there are no attachments.
  static String encode({
    String? caption,
    List<ChatAttachmentRef> attachments = const [],
  }) {
    if (attachments.isEmpty) return caption ?? '';

    return jsonEncode({
      // First key, and a human sentence: the one mitigation available for an
      // already-shipped client, which has no idea this envelope format
      // exists and will render the whole body as plain text.
      'note': _noteFor(attachments.first.kind),
      'ff': _envelopeVersion,
      if (caption != null && caption.isNotEmpty) 'caption': caption,
      'att': [for (final a in attachments) a.toJson()],
    });
  }

  /// Decodes plaintext that has already come back from [ChatCrypto.decrypt].
  ///
  /// Never throws. A body that isn't a manifest — including one that merely
  /// *looks* like the start of one — decodes as plain text: [ChatBody.caption]
  /// carries the original string, [ChatBody.attachments] is empty.
  static ChatBody decode(String? plaintext) {
    if (plaintext == null) return const ChatBody();

    if (!plaintext.startsWith(_prefix) || !plaintext.contains('"ff":')) {
      return ChatBody(caption: plaintext);
    }

    try {
      final json = jsonDecode(plaintext);
      if (json is! Map<String, dynamic>) return ChatBody(caption: plaintext);

      final attJson = json['att'];
      if (attJson is! List || attJson.isEmpty) {
        // Has the right shape at a glance but no attachment list — not a
        // manifest this codec recognises. Falls back to the human-readable
        // `note`, which is exactly what an old client would have shown.
        return ChatBody(caption: json['note'] as String? ?? plaintext);
      }

      final attachments = <ChatAttachmentRef>[];
      for (final entry in attJson) {
        if (entry is Map<String, dynamic>) {
          final ref = ChatAttachmentRef.tryFromJson(entry);
          // One malformed attachment costs one list entry, not the message.
          if (ref != null) attachments.add(ref);
        }
      }

      if (attachments.isEmpty) {
        return ChatBody(caption: json['note'] as String? ?? plaintext);
      }

      return ChatBody(
        caption: json['caption'] as String?,
        attachments: attachments,
      );
    } catch (_) {
      // Not valid JSON after all, or some other structural surprise. Falls
      // back to rendering the raw string — which, if this really was a
      // manifest gone wrong, still starts with the readable `note` sentence
      // because encode() always writes that key first.
      return ChatBody(caption: plaintext);
    }
  }

  static String _noteFor(MediaType kind) {
    switch (kind) {
      case MediaType.picture:
        return 'Photo — update ForgeForm to view attachments';
      case MediaType.video:
        return 'Video — update ForgeForm to view attachments';
      case MediaType.audio:
        return 'Audio — update ForgeForm to view attachments';
      case MediaType.document:
        return 'Document — update ForgeForm to view attachments';
      case MediaType.voiceNote:
        return 'Voice message — update ForgeForm to view attachments';
    }
  }
}
