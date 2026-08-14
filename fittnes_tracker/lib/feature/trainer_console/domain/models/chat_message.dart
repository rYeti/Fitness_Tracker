import 'package:ForgeForm/core/providers/enums.dart';

class ChatMessage {
  final String id;
  final String? body;
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
      sentAt: DateTime.parse(json['sentAt'] as String),
      body: json['body'] as String?,
      mediaType: media == null ? null : MediaType.values[media],
      url: json['url'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }
}
