import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:ForgeForm/core/providers/enums.dart';
import 'package:ForgeForm/feature/chat/domain/models/chat_attachment_ref.dart';
import 'package:ForgeForm/feature/chat/domain/models/thread_message.dart';
import 'package:ForgeForm/feature/chat/presentation/providers/chat_attachment_provider.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// A hex "#rrggbb" [ChatAttachmentRef.avgColor] as a [Color], falling back to
/// a neutral grey for anything malformed.
Color _parseAvgColor(String? hex) {
  if (hex == null || hex.length != 7 || !hex.startsWith('#')) {
    return const Color(0xFF808080);
  }
  final value = int.tryParse(hex.substring(1), radix: 16);
  if (value == null) return const Color(0xFF808080);
  return Color(0xFF000000 | value);
}

/// The spoken label for one attachment kind — shared between the bubble's
/// semantics value and any visible caption fallback.
String kindLabel(AppLocalizations l10n, MediaType kind) {
  switch (kind) {
    case MediaType.picture:
      return l10n.chatPhotoLabel;
    case MediaType.document:
      return l10n.chatDocumentLabel;
    case MediaType.video:
    case MediaType.audio:
    case MediaType.voiceNote:
      return l10n.chatUnsupportedAttachment;
  }
}

/// The phrase describing [phase] for a screen reader — the second half of
/// the bubble's semantics value, after the kind label. Empty for `stored`,
/// since a rendered attachment needs no extra words beyond what it is.
String _phaseLabel(AppLocalizations l10n, AttachmentPhase phase) {
  switch (phase) {
    case AttachmentPhase.uploading:
      return l10n.chatAttachmentUploading;
    case AttachmentPhase.uploadFailed:
      return l10n.chatAttachmentUploadFailed;
    case AttachmentPhase.downloading:
      return l10n.chatAttachmentDownloading;
    case AttachmentPhase.downloadFailed:
      return l10n.chatAttachmentDownloadFailed;
    case AttachmentPhase.expired:
      return l10n.chatAttachmentExpired;
    case AttachmentPhase.notDownloaded:
      return l10n.chatAttachmentTapToDownload;
    case AttachmentPhase.stored:
      return '';
  }
}

/// The words a screen reader hears for this attachment, in whatever state it
/// is in right now — every visual state below must be spelled out here, per
/// docs/chat-attachments.md §C.5: a progress ring or a broken-image glyph is
/// exactly as invisible to a screen reader as colour, unless the words say so.
String attachmentSemanticsValue(
  AppLocalizations l10n,
  ChatAttachmentRef ref,
  AttachmentPhase phase,
) {
  final kind = kindLabel(l10n, ref.kind);
  final phaseText = _phaseLabel(l10n, phase);
  if (phaseText.isEmpty) {
    return ref.kind == MediaType.document ? '$kind, ${ref.name}' : kind;
  }
  return '$kind, $phaseText';
}

/// Renders one attachment inside a [ChatBubble] — photo and document only in
/// this phase; video, audio and voice notes render an honest placeholder
/// rather than a half-built player. See docs/chat-attachments.md §C.5.
class ChatAttachmentContent extends StatelessWidget {
  final ThreadMessage message;
  final ChatAttachmentRef ref;
  final AttachmentPhase phase;
  final Uint8List? bytes;
  final Color textColor;
  final VoidCallback? onTap;

  const ChatAttachmentContent({
    super.key,
    required this.message,
    required this.ref,
    required this.phase,
    required this.bytes,
    required this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    switch (ref.kind) {
      case MediaType.picture:
        return _PhotoTile(ref: ref, phase: phase, bytes: bytes, onTap: onTap);
      case MediaType.document:
        return _DocumentTile(
          ref: ref,
          phase: phase,
          textColor: textColor,
          onTap: onTap,
        );
      case MediaType.video:
      case MediaType.audio:
      case MediaType.voiceNote:
        return _UnsupportedTile(ref: ref, textColor: textColor);
    }
  }
}

class _PhotoTile extends StatelessWidget {
  final ChatAttachmentRef ref;
  final AttachmentPhase phase;
  final Uint8List? bytes;
  final VoidCallback? onTap;

  const _PhotoTile({
    required this.ref,
    required this.phase,
    required this.bytes,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final aspect =
        (ref.width != null && ref.height != null && ref.height! > 0)
            ? ref.width! / ref.height!
            : 4 / 3;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        // Reserved before the bytes arrive, from the manifest — the thread
        // must not jump as each image loads in.
        aspectRatio: aspect,
        child: GestureDetector(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: _parseAvgColor(ref.avgColor)),
              if (phase == AttachmentPhase.stored && bytes != null)
                Image.memory(bytes!, fit: BoxFit.cover)
              else if (phase == AttachmentPhase.expired)
                const _CenteredIcon(icon: Icons.no_photography_outlined)
              else if (phase == AttachmentPhase.downloading ||
                  phase == AttachmentPhase.uploading)
                const _CenteredIcon(icon: null, showSpinner: true)
              else if (phase == AttachmentPhase.downloadFailed ||
                  phase == AttachmentPhase.uploadFailed)
                const _CenteredIcon(icon: Icons.error_outline_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenteredIcon extends StatelessWidget {
  final IconData? icon;
  final bool showSpinner;

  const _CenteredIcon({this.icon, this.showSpinner = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child:
          showSpinner
              ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
              : Icon(icon, color: Colors.white, size: 28),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final ChatAttachmentRef ref;
  final AttachmentPhase phase;
  final Color textColor;
  final VoidCallback? onTap;

  const _DocumentTile({
    required this.ref,
    required this.phase,
    required this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final subtitle = switch (phase) {
      AttachmentPhase.downloading => l10n.chatAttachmentDownloading,
      AttachmentPhase.downloadFailed => l10n.chatAttachmentDownloadFailed,
      AttachmentPhase.uploading => l10n.chatAttachmentUploading,
      AttachmentPhase.uploadFailed => l10n.chatAttachmentUploadFailed,
      AttachmentPhase.expired => l10n.chatAttachmentExpired,
      AttachmentPhase.stored => l10n.chatAttachmentOpen,
      AttachmentPhase.notDownloaded => _formatBytes(ref.size),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.description_outlined, color: textColor, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ref.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Exo 2',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Exo 2',
                      fontSize: 11.5,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Video, audio and voice notes — an honest placeholder rather than a
/// half-built player. See docs/chat-attachments.md §0.3/§C.1: those kinds are
/// later phases (5 and 6), not stubbed playback here.
class _UnsupportedTile extends StatelessWidget {
  final ChatAttachmentRef ref;
  final Color textColor;

  const _UnsupportedTile({required this.ref, required this.textColor});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.attachment_rounded, color: textColor, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              l10n.chatUnsupportedAttachment,
              style: TextStyle(
                fontFamily: 'Exo 2',
                fontSize: 12.5,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
