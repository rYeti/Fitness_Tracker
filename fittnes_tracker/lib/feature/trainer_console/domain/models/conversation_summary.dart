/// One row in the Chat conversation list — a roster entry plus the last
/// message's preview. See design handoff README section 3 ("Messages") for
/// the row spec (avatar, name, timestamp, truncated preview, unread dot).
///
/// Deliberately separate from [TrainerClientSummary]: the roster doesn't
/// need message-preview data, and coupling them would force every roster
/// fetch to also compute unread counts.
class ConversationSummary {
  final String clientId;
  final String clientName;
  final String initials;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const ConversationSummary({
    required this.clientId,
    required this.clientName,
    required this.initials,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.unreadCount = 0,
  });
}
