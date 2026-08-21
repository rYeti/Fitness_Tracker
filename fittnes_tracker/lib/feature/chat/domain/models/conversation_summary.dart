/// One row in the Chat conversation list — who the thread is with, plus the last
/// message's preview. See design handoff README section 3 ("Messages") for the
/// row spec (avatar, name, timestamp, truncated preview, unread dot).
///
/// Maps to `ChatConversationDto` from `api/chat/conversations`. Deliberately
/// separate from `TrainerClientSummary`: the roster doesn't need message-preview
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
    final lastAt = json['lastMessageAt'] as String?;
    return ConversationSummary(
      clientId: json['otherPartyId'] as String,
      clientName: json['otherPartyName'] as String? ?? '',
      lastMessagePreview: json['lastMessagePreview'] as String?,
      lastMessageAt: lastAt == null ? null : DateTime.parse(lastAt),
      unreadCount: json['unreadCount'] as int? ?? 0,
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
