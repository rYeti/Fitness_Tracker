import 'dart:ui';

import 'package:ForgeForm/feature/chat/data/chat_key_store.dart';
import 'package:ForgeForm/feature/chat/data/webcrypto_chat_crypto.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// What a chat push turns into once this device has read it.
class ChatPushContent {
  /// The sender's display name. A name is not message content, so the server
  /// still sends it in the clear and a notification can always say who it is
  /// from.
  final String title;

  /// The decrypted message, or a neutral stand-in when this device has no key
  /// for it.
  final String body;

  final String? threadId;

  const ChatPushContent({
    required this.title,
    required this.body,
    required this.threadId,
  });
}

/// Turns a data-only chat push into something showable.
///
/// This is the half of the end-to-end encryption trade that is easy to miss.
/// The server used to write the notification, because it could read the
/// message; now it sends the ciphertext and *this* runs — often in the push
/// background isolate, with no service locator, no database and no widget tree.
/// Everything it needs comes out of the platform keystore.
///
/// [allowNetwork] is false in that isolate. A peer key that is not already
/// cached cannot be fetched there, and the notification falls back to the
/// sender's name alone — the same outcome as any other decryption failure, and
/// the same one the conversation list shows for a preview it cannot read.
Future<ChatPushContent> decodeChatPush(
  Map<String, dynamic> data, {
  required bool allowNetwork,
}) async {
  // Loaded once. It is both the title's fallback and the body's, and resolving a
  // locale delegate twice per notification to say the same two words is waste on
  // a path that runs while the phone is asleep.
  final newMessage = await _newMessageLabel();

  final title = _stringOr(data['senderName'], newMessage);
  final threadId = data['threadId'] as String?;

  final ciphertext = data['ciphertext'] as String?;
  final iv = data['iv'] as String?;
  final version = int.tryParse('${data['encryptionVersion']}') ?? 0;

  // No ciphertext at all is a deliberate server-side decision, not a failure:
  // the message was too long to fit in FCM's payload budget and cannot be
  // truncated the way a plaintext preview once was. See PushNotificationService.
  if (ciphertext == null || threadId == null) {
    return ChatPushContent(title: title, body: newMessage, threadId: threadId);
  }

  final keys = allowNetwork ? ChatKeyStore() : ChatKeyStore.cacheOnly();

  // Version 2 only: the epk and this device's own line out of the compact
  // `deviceId:wrappedKey:wrappedIv,...` field PushNotificationService packs
  // every target device's wrap into. `deviceId()` is a plain vault read, so it
  // works with no network in the background isolate exactly like the rest of
  // this function.
  final epk = data['epk'] as String?;
  final ownWrap = await _ownWrap(data['keys'] as String?, await keys.deviceId());

  final plaintext = await WebCryptoChatCrypto(keys: keys).decrypt(
    // The push arrives at the recipient, so the other party is whoever sent it
    // — which is exactly what threadId is, from this side of the conversation.
    otherPartyId: threadId,
    ciphertext: ciphertext,
    iv: iv,
    version: version,
    ephemeralPublicKeyJwk: epk,
    wrappedKey: ownWrap?.$1,
    wrappedKeyIv: ownWrap?.$2,
  );

  return ChatPushContent(
    title: title,
    body: plaintext ?? newMessage,
    threadId: threadId,
  );
}

/// Picks [deviceId]'s own entry out of the packed `keys` field, or null if the
/// push carries no field, or carries one with nothing for this device.
(String, String)? _ownWrap(String? packed, String deviceId) {
  if (packed == null || packed.isEmpty) return null;

  for (final entry in packed.split(',')) {
    final parts = entry.split(':');
    if (parts.length != 3) continue;
    if (parts[0] == deviceId) return (parts[1], parts[2]);
  }
  return null;
}

String _stringOr(Object? value, String fallback) {
  final text = value is String ? value.trim() : '';
  return text.isEmpty ? fallback : text;
}

/// "New message", in the user's language, without a [BuildContext].
///
/// The background isolate has no widget tree to look one up from, so the
/// delegate is loaded directly against the platform locale. A failure here
/// falls back to English rather than taking down the notification.
Future<String> _newMessageLabel() async {
  try {
    final locale = PlatformDispatcher.instance.locale;
    if (AppLocalizations.delegate.isSupported(locale)) {
      return (await AppLocalizations.delegate.load(locale)).chatNewMessage;
    }
  } catch (_) {
    // Falls through.
  }
  return 'New message';
}
