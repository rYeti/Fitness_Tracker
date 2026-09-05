import 'package:ForgeForm/feature/chat/data/chat_attachment_sender.dart';

/// What the composer hands to `onSend`: the typed caption plus, optionally,
/// one already-sealed attachment ready to upload.
///
/// A named type rather than widening `onSend` to a raw tuple, so a second
/// attachment later touches this type only, not every call site.
class ChatDraft {
  final String caption;
  final SealedAttachmentResult? attachment;

  const ChatDraft({required this.caption, this.attachment});
}
