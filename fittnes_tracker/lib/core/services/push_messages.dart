/// The data-only pushes this app is sent, by their `type` field.
///
/// Every push the server sends is data-only: chat because the server can't
/// read the message it would have to write into a notification
/// (`docs/chat-encryption.md`), and `sync_requested` because it is not
/// something to show anyone. So whether a notification appears is decided
/// here, on the device, by type — and a type this build doesn't know shows
/// nothing and does nothing.
enum PushMessageType {
  /// A chat message: the device decrypts it and draws the notification.
  chatMessage,

  /// Someone else — a trainer, say — changed this account's data on the
  /// server. Nothing to show; in the foreground it is a reason to pull now.
  syncRequested,

  unknown;

  static PushMessageType of(Map<String, dynamic> data) =>
      switch (data['type']) {
        'chat_message' => chatMessage,
        'sync_requested' => syncRequested,
        _ => unknown,
      };
}

/// Handles a push that arrived while the app is open.
///
/// The OS draws nothing for an app in the foreground, so a chat message is
/// handed to [showChat], which decides whether to draw one. A
/// `sync_requested` calls [requestSync] and draws nothing: the server says
/// this account's data changed elsewhere, and the useful answer to that is a
/// pull, now — `docs/sync-architecture.md`, part four.
Future<void> handleForegroundPush(
  Map<String, dynamic> data, {
  required Future<void> Function(Map<String, dynamic> data) showChat,
  required void Function() requestSync,
}) async {
  switch (PushMessageType.of(data)) {
    case PushMessageType.chatMessage:
      await showChat(data);
    case PushMessageType.syncRequested:
      requestSync();
    case PushMessageType.unknown:
      break;
  }
}

/// Handles a push that arrived while the app is in the background or closed,
/// in the isolate FCM starts for it.
///
/// Only a chat message does anything here. A `sync_requested` does nothing at
/// all — no notification, and no pull. A pull here would have to build what
/// the background sync task builds (its own locator, database connection and
/// API client) inside a handler the OS gives a short window it doesn't
/// promise to keep; one killed halfway leaves the sync lease held until it
/// expires, and the app's own sync waits behind it on the next launch. And
/// nothing is gained: the next time the app comes to the front it pulls
/// anyway, and so does the daily background task. The message only saves a
/// wait while someone is looking.
Future<void> handleBackgroundPush(
  Map<String, dynamic> data, {
  required Future<void> Function(Map<String, dynamic> data) showChat,
}) async {
  if (PushMessageType.of(data) != PushMessageType.chatMessage) return;
  await showChat(data);
}
