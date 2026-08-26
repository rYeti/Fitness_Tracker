import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/providers/enums.dart';
import 'package:ForgeForm/feature/chat/domain/chat_timestamps.dart';
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

  final String? body;

  /// For a sent message the server's `sentAt`; for an unsent one the moment the
  /// user pressed send. Both answer "where does this sit in the thread?".
  final DateTime timestamp;

  /// Whether this side of the conversation wrote it — see [ThreadMessage.fromChatMessage]
  /// for how that is worked out without the client knowing its own user id.
  final bool isMine;

  final ChatMessageStatus status;

  final MediaType? mediaType;
  final String? url;
  final String? thumbnailUrl;

  const ThreadMessage({
    required this.messageId,
    required this.body,
    required this.timestamp,
    required this.isMine,
    required this.status,
    this.mediaType,
    this.url,
    this.thumbnailUrl,
  });

  /// Projects a stored message, deciding which side of the thread it belongs on.
  ///
  /// [otherPartyId] is the client's id on the Trainer Console and the trainer's
  /// id in the trainee app. A thread has exactly two parties, so "the sender
  /// isn't them" is the same as "the sender is me" — and unlike comparing against
  /// a stored user id, it works on a client that has never been told its own.
  factory ThreadMessage.fromChatMessage(ChatMessage message, {required String otherPartyId}) {
    return ThreadMessage(
      messageId: message.id,
      body: message.body,
      timestamp: message.sentAt,
      isMine: message.senderId != otherPartyId,
      status: ChatMessageStatus.sent,
      mediaType: message.mediaType,
      url: message.url,
      thumbnailUrl: message.thumbnailUrl,
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
    );
  }

  ThreadMessage copyWith({ChatMessageStatus? status}) {
    return ThreadMessage(
      messageId: messageId,
      body: body,
      timestamp: timestamp,
      isMine: isMine,
      status: status ?? this.status,
      mediaType: mediaType,
      url: url,
      thumbnailUrl: thumbnailUrl,
    );
  }
}
