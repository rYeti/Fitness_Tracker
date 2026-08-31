import 'package:ForgeForm/feature/chat/domain/chat_timestamps.dart';

/// One row in the Chat conversation list — who the thread is with, plus the last
/// message's preview. See design handoff README section 3 ("Messages") for the
/// row spec (avatar, name, timestamp, truncated preview, unread dot).
///
/// Maps to `ChatConversationDto` from `api/chat/conversations`. Note that
/// [lastMessagePreview] arrives as *ciphertext* — `ChatRepository` decrypts it
/// via [withPreview] before any of this reaches the screen. Deliberately
/// separate from `TrainerRosterEntry`: the roster doesn't need message-preview
/// data, and coupling them would force every roster fetch to also compute
/// unread counts.
class ConversationSummary {
  /// The other party's id — a client on the Trainer Console, the trainer in the
  /// trainee app. Named `clientId` because that is what the console's callers
  /// pass it as; the server calls the same value `otherPartyId`.
  final String clientId;
  final String clientName;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const ConversationSummary({
    required this.clientId,
    required this.clientName,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    return ConversationSummary(
      clientId: json['otherPartyId'] as String,
      clientName: json['otherPartyName'] as String? ?? '',
      lastMessagePreview: json['lastMessagePreview'] as String?,
      // Null is a real state here — a relationship with no messages yet — so a
      // timestamp that cannot be read stays null and the row simply shows no
      // time, rather than claiming one.
      lastMessageAt: ChatTimestamps.parseInstant(json['lastMessageAt']),
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }

  /// The same row with its preview replaced by decrypted text.
  ///
  /// Separate from [copyWith] because null means something here that it cannot
  /// mean there: [copyWith] reads a null as "leave this alone", and a preview
  /// this device cannot decrypt has to be able to *become* null so the row falls
  /// back to a neutral label instead of showing the previous message's text.
  ConversationSummary withPreview(String? preview) {
    return ConversationSummary(
      clientId: clientId,
      clientName: clientName,
      lastMessagePreview: preview,
      lastMessageAt: lastMessageAt,
      unreadCount: unreadCount,
    );
  }

  ConversationSummary copyWith({
    String? lastMessagePreview,
    DateTime? lastMessageAt,
    int? unreadCount,
  }) {
    return ConversationSummary(
      clientId: clientId,
      clientName: clientName,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  /// Up to two letters ("Robert Meyer" -> "RM"), matching the avatars in the
  /// design handoff. Derived rather than stored so it cannot drift from the name.
  String get initials {
    final parts =
        clientName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  bool get hasUnread => unreadCount > 0;
}
