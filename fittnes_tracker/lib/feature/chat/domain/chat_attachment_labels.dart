import 'package:ForgeForm/core/providers/enums.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// The spoken/written label for one attachment kind — shared between
/// [ChatBubble]'s semantics value and the push notification decoder, which
/// runs in a background isolate with no widget tree and must not import
/// presentation code to get the same word.
String attachmentKindLabel(AppLocalizations l10n, MediaType kind) {
  switch (kind) {
    case MediaType.picture:
      return l10n.chatPhotoLabel;
    case MediaType.document:
      return l10n.chatDocumentLabel;
    case MediaType.audio:
      return l10n.chatAudioLabel;
    case MediaType.voiceNote:
      return l10n.chatVoiceNoteLabel;
    case MediaType.video:
      return l10n.chatVideoLabel;
  }
}
