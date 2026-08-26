import 'package:ForgeForm/core/providers/enums.dart';
import 'package:ForgeForm/feature/chat/domain/chat_timestamps.dart';

class ChatMessage {
  final String id;
  final String? body;

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
      mediaType: media == null ? null : MediaType.values[media],
      url: json['url'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }
}
