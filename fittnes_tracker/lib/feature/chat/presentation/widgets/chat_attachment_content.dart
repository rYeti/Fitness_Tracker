import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ForgeForm/core/providers/enums.dart';
import 'package:ForgeForm/feature/chat/data/chat_attachment_file.dart';
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
    case MediaType.audio:
      return l10n.chatAudioLabel;
    case MediaType.voiceNote:
      return l10n.chatVoiceNoteLabel;
    case MediaType.video:
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
    if (ref.kind == MediaType.document) return '$kind, ${ref.name}';
    if ((ref.kind == MediaType.audio || ref.kind == MediaType.voiceNote) &&
        ref.durationSeconds != null) {
      return '$kind, ${ref.durationSeconds} ${ref.durationSeconds == 1 ? 'second' : 'seconds'}';
    }
    return kind;
  }
  return '$kind, $phaseText';
}

/// Renders one attachment inside a [ChatBubble] — photo, document, audio
/// file and voice note; video renders an honest placeholder rather than a
/// half-built player (phase 6). See docs/chat-attachments.md §C.5.
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
      case MediaType.audio:
      case MediaType.voiceNote:
        return _AudioTile(
          ref: ref,
          phase: phase,
          bytes: bytes,
          textColor: textColor,
          onTap: onTap,
        );
      case MediaType.video:
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

/// Audio files and voice notes — a play/pause pill with a duration readout.
/// `audioplayers.BytesSource` is unsupported on desktop, so this writes the
/// decrypted bytes to a temp file on every platform but web and plays from
/// there; web plays the bytes directly. See docs/chat-attachments.md §C.1.
class _AudioTile extends StatefulWidget {
  final ChatAttachmentRef ref;
  final AttachmentPhase phase;
  final Uint8List? bytes;
  final Color textColor;
  final VoidCallback? onTap;

  const _AudioTile({
    required this.ref,
    required this.phase,
    required this.bytes,
    required this.textColor,
    this.onTap,
  });

  @override
  State<_AudioTile> createState() => _AudioTileState();
}

class _AudioTileState extends State<_AudioTile> {
  final _player = AudioPlayer();
  bool _playing = false;
  String? _tempPath;
  late final StreamSubscription<void> _completeSub;
  late final StreamSubscription<PlayerState> _stateSub;

  @override
  void initState() {
    super.initState();
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playing = state == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _completeSub.cancel();
    _stateSub.cancel();
    _player.dispose();
    if (_tempPath != null) {
      // Best-effort cleanup; a leftover temp file costs nothing the OS
      // doesn't already reclaim, so a failure here is not worth surfacing.
      deleteAttachmentFile(_tempPath!).catchError((_) {});
    }
    super.dispose();
  }

  Future<void> _toggle() async {
    final bytes = widget.bytes;
    if (bytes == null) return;

    if (_playing) {
      await _player.pause();
      return;
    }

    if (kIsWeb) {
      await _player.play(BytesSource(bytes));
      return;
    }

    var path = _tempPath;
    if (path == null) {
      final dir = await getTemporaryDirectory();
      path = '${dir.path}/chat_audio_${widget.ref.id}.bin';
      await writeAttachmentBytes(path, bytes);
      _tempPath = path;
    }
    await _player.play(DeviceFileSource(path));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canPlay =
        widget.phase == AttachmentPhase.stored && widget.bytes != null;
    final duration = widget.ref.durationSeconds;
    final durationText =
        duration == null
            ? null
            : '${(duration ~/ 60).toString().padLeft(1, '0')}:${(duration % 60).toString().padLeft(2, '0')}';

    final subtitle = switch (widget.phase) {
      AttachmentPhase.downloading => l10n.chatAttachmentDownloading,
      AttachmentPhase.downloadFailed => l10n.chatAttachmentDownloadFailed,
      AttachmentPhase.uploading => l10n.chatAttachmentUploading,
      AttachmentPhase.uploadFailed => l10n.chatAttachmentUploadFailed,
      AttachmentPhase.expired => l10n.chatAttachmentExpired,
      AttachmentPhase.stored => durationText ?? '',
      AttachmentPhase.notDownloaded =>
        durationText ?? l10n.chatAttachmentTapToDownload,
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: canPlay ? _toggle : widget.onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.textColor.withValues(alpha: 0.15),
              ),
              child:
                  canPlay
                      ? Icon(
                        _playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: widget.textColor,
                        size: 20,
                      )
                      : widget.phase == AttachmentPhase.downloading ||
                          widget.phase == AttachmentPhase.uploading
                      ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: widget.textColor,
                        ),
                      )
                      : Icon(
                        Icons.graphic_eq_rounded,
                        color: widget.textColor,
                        size: 18,
                      ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Exo 2',
                fontSize: 12,
                color: widget.textColor.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Video — an honest placeholder rather than a half-built player. See
/// docs/chat-attachments.md §0.3/§C.1: this kind is a later phase (6), not
/// stubbed playback here.
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
