import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/providers/enums.dart';
import 'package:ForgeForm/feature/chat/domain/chat_body_codec.dart';
import 'package:ForgeForm/feature/chat/domain/chat_timestamps.dart';
import 'package:ForgeForm/feature/chat/domain/models/chat_attachment_ref.dart';
import 'package:ForgeForm/feature/chat/domain/models/chat_message.dart';

/// One bubble in a thread, whatever it was built from.
///
/// A thread mixes two very different things: messages the server has stored
/// ([ChatMessage]) and send attempts this device is still tracking
/// ([ChatOutBoxTableData]). Those stay separate types on purpose — a message
/// being sent has no `sentAt` and may never get one — but the UI has to render
/// them in one ordered list. Collapsing them here rather than in a widget keeps
/// the merge in a single place instead of once per screen.
class ThreadMessage {
  /// The client-generated id. Stable across retries, which is what makes it safe
  /// to dedupe on.
  final String messageId;

  /// The caption, or the whole message for a text-only send. Never the raw
  /// wire body — [ChatBodyCodec] has already been run by the time this type
  /// exists, on both the server-message and the outbox path. See
  /// [ThreadMessage.fromChatMessage] and [ThreadMessage.fromOutbox].
  final String? body;

  /// For a sent message the server's `sentAt`; for an unsent one the moment the
  /// user pressed send. Both answer "where does this sit in the thread?".
  final DateTime timestamp;

  /// Whether this side of the conversation wrote it — see [ThreadMessage.fromChatMessage]
  /// for how that is worked out without the client knowing its own user id.
  final bool isMine;

  final ChatMessageStatus status;

  /// True when this bubble's text could not be decrypted on this device.
  ///
  /// The one user-visible cost of having no key backup: a reinstall on either
  /// side of a conversation leaves the messages sent before it unreadable, and
  /// this is what tells the reader that rather than showing them a blank bubble.
  final bool isUndecryptable;

  /// Never written by the server — see docs/chat-attachments.md §0.1. Kept
  /// only because the wire type still carries it; a media message is
  /// represented by [attachment], not this.
  final MediaType? mediaType;
  final String? url;
  final String? thumbnailUrl;

  /// The attachment this bubble carries, decoded from the envelope by
  /// [ChatBodyCodec] — null for an ordinary text message.
  final ChatAttachmentRef? attachment;

  /// Where [attachment]'s own upload stands. `none` for every message with
  /// no attachment, and for any message this device didn't send (a bubble
  /// built from server history has, by definition, already finished
  /// uploading whatever it carries). Only an outbox-sourced bubble for a
  /// message still in flight carries a value other than `none`/`uploaded`.
  final AttachmentUploadStatus uploadStatus;

  const ThreadMessage({
    required this.messageId,
    required this.body,
    required this.timestamp,
    required this.isMine,
    required this.status,
    this.isUndecryptable = false,
    this.mediaType,
    this.url,
    this.thumbnailUrl,
    this.attachment,
    this.uploadStatus = AttachmentUploadStatus.none,
  });

  /// Projects a stored message, deciding which side of the thread it belongs on.
  ///
  /// [otherPartyId] is the client's id on the Trainer Console and the trainer's
  /// id in the trainee app. A thread has exactly two parties, so "the sender
  /// isn't them" is the same as "the sender is me" — and unlike comparing against
  /// a stored user id, it works on a client that has never been told its own.
  factory ThreadMessage.fromChatMessage(ChatMessage message, {required String otherPartyId}) {
    // An undecryptable message has no plaintext to run the codec over — its
    // body is the ciphertext, and decoding that would be meaningless at best
    // and a crash at worst. isUndecryptable already tells the bubble what to
    // render; there is nothing here to add.
    final decoded = message.isUndecryptable
        ? const ChatBody()
        : ChatBodyCodec.decode(message.body);
    final attachment = decoded.attachments.isEmpty ? null : decoded.attachments.first;

    return ThreadMessage(
      messageId: message.id,
      body: message.isUndecryptable ? message.body : decoded.caption,
      timestamp: message.sentAt,
      isMine: message.senderId != otherPartyId,
      status: ChatMessageStatus.sent,
      isUndecryptable: message.isUndecryptable,
      mediaType: message.mediaType,
      url: message.url,
      thumbnailUrl: message.thumbnailUrl,
      attachment: attachment,
      uploadStatus: attachment == null
          ? AttachmentUploadStatus.none
          : AttachmentUploadStatus.uploaded,
    );
  }

  /// Projects an outbox row. Always mine — the outbox only ever holds messages
  /// this device tried to send.
  factory ThreadMessage.fromOutbox(ChatOutBoxTableData row) {
    return ThreadMessage(
      messageId: row.messageId,
      body: row.body,
      timestamp: ChatTimestamps.sanitize(row.createdAt),
      isMine: true,
      status: ChatMessageStatus.values[row.chatMessageStatus],
      // The outbox stores the attachment's own JSON object directly (the
      // same shape ChatAttachmentRef.toJson produces), not the full
      // note/ff/caption envelope — so this decodes it straight rather than
      // through ChatBodyCodec, which expects the wrapped form.
      attachment: ChatAttachmentRef.tryFromJsonString(row.attachmentManifest),
      uploadStatus: AttachmentUploadStatus.values[row.uploadStatus],
    );
  }

  ThreadMessage copyWith({
    String? body,
    DateTime? timestamp,
    bool? isMine,
    ChatMessageStatus? status,
    bool? isUndecryptable,
    MediaType? mediaType,
    String? url,
    String? thumbnailUrl,
    ChatAttachmentRef? attachment,
    AttachmentUploadStatus? uploadStatus,
  }) {
    return ThreadMessage(
      messageId: messageId,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      isMine: isMine ?? this.isMine,
      status: status ?? this.status,
      isUndecryptable: isUndecryptable ?? this.isUndecryptable,
      mediaType: mediaType ?? this.mediaType,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      attachment: attachment ?? this.attachment,
      uploadStatus: uploadStatus ?? this.uploadStatus,
    );
  }
}
