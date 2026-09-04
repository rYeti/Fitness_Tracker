import 'dart:ui';

import 'package:ForgeForm/feature/chat/data/chat_key_store.dart';
import 'package:ForgeForm/feature/chat/data/webcrypto_chat_crypto.dart';
import 'package:ForgeForm/feature/chat/domain/chat_attachment_labels.dart';
import 'package:ForgeForm/feature/chat/domain/chat_body_codec.dart';
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
  // Loaded once — it is the fallback for the title, for the body, and the
  // source of every attachment-kind word below, and resolving a locale
  // delegate more than once per notification is waste on a path that runs
  // while the phone is asleep.
  final l10n = await _loadL10n();
  final newMessage = l10n?.chatNewMessage ?? 'New message';

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

  final plaintext = await WebCryptoChatCrypto(keys: keys).decrypt(
    // The push arrives at the recipient, so the other party is whoever sent it
    // — which is exactly what threadId is, from this side of the conversation.
    otherPartyId: threadId,
    ciphertext: ciphertext,
    iv: iv,
    version: version,
  );

  return ChatPushContent(
    title: title,
    body:
        plaintext == null ? newMessage : _bodyFor(plaintext, l10n, newMessage),
    threadId: threadId,
  );
}

/// Turns decrypted plaintext into what the notification actually says.
///
/// [ChatBodyCodec.decode] never throws and never touches the network or the
/// filesystem — it only inspects the string already in hand — so running it
/// here costs nothing extra and is exactly what keeps this decoder from
/// needing to fetch or decrypt the attachment bytes themselves: kind and
/// caption are both already inside the manifest that arrived with the push.
String _bodyFor(String plaintext, AppLocalizations? l10n, String fallback) {
  final decoded = ChatBodyCodec.decode(plaintext);
  if (!decoded.hasAttachment) return decoded.caption ?? fallback;

  final kind =
      l10n == null
          ? fallback
          : attachmentKindLabel(l10n, decoded.attachments.first.kind);
  final caption = decoded.caption;
  return (caption != null && caption.isNotEmpty) ? '$kind · $caption' : kind;
}

String _stringOr(Object? value, String fallback) {
  final text = value is String ? value.trim() : '';
  return text.isEmpty ? fallback : text;
}

/// The user's language, without a [BuildContext].
///
/// The background isolate has no widget tree to look one up from, so the
/// delegate is loaded directly against the platform locale. Null on any
/// failure (unsupported locale, load error) — callers fall back to English
/// literals rather than taking down the notification.
Future<AppLocalizations?> _loadL10n() async {
  try {
    final locale = PlatformDispatcher.instance.locale;
    if (AppLocalizations.delegate.isSupported(locale)) {
      return await AppLocalizations.delegate.load(locale);
    }
  } catch (_) {
    // Falls through.
  }
  return null;
}
