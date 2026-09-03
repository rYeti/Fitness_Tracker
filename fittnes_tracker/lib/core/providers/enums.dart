enum Sex { male, female, other }

enum GoalType { weightLoss, muscleGain, maintenance }

enum ActivityLevel {
  sedentary,
  lightlyActive,
  moderatelyActive,
  veryActive,
  extremelyActive,
}

/// What kind of attachment a message carries.
///
/// **Append-only, never reorder or remove a value.** [ChatMessage.fromJson]
/// and [ChatBodyCodec] both deserialise this by ordinal, so a value inserted
/// anywhere but the end reassigns every index after it and silently relabels
/// every attachment a client has ever stored. Mirrors `Media` on the API side
/// (`FitTracker.Api/Eums/Media.cs`) — the two must stay in the same order.
enum MediaType {
  picture,
  video,
  audio,
  document,
  voiceNote,
}