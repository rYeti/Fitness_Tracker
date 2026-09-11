import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mk_video;
import 'package:path_provider/path_provider.dart';

import 'package:ForgeForm/core/forge_motion.dart';
import 'package:ForgeForm/core/providers/enums.dart';
import 'package:ForgeForm/feature/chat/data/chat_attachment_file.dart';
import 'package:ForgeForm/feature/chat/data/video_blob_url.dart';
import 'package:ForgeForm/feature/chat/domain/attachment_filename.dart';
import 'package:ForgeForm/feature/chat/domain/chat_attachment_labels.dart';
import 'package:ForgeForm/feature/chat/domain/models/chat_attachment_ref.dart';
import 'package:ForgeForm/feature/chat/domain/models/thread_message.dart';
import 'package:ForgeForm/feature/chat/presentation/attachment_gesture_mode.dart';
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
  final kind = attachmentKindLabel(l10n, ref.kind);
  final phaseText = _phaseLabel(l10n, phase);
  if (phaseText.isEmpty) {
    // Stored. A photo or a document now has an action beyond "here it is" —
    // a cursor change or a double-click affordance is exactly as invisible to
    // a screen reader as colour, so the hint is spelled out the same way
    // every other phase's action already is. Not said for video: its
    // fullscreen entry has no semantics action wired to it (see
    // `ChatBubble`'s `Semantics.onTap`), so promising "double tap to open"
    // there would describe an action that doesn't fire.
    final expandable =
        phase == AttachmentPhase.stored &&
        (ref.kind == MediaType.picture || ref.kind == MediaType.document);
    final hint = expandable ? ', ${l10n.chatAttachmentExpandHint}' : '';

    if (ref.kind == MediaType.document) return '$kind, ${ref.name}$hint';
    if ((ref.kind == MediaType.audio ||
            ref.kind == MediaType.voiceNote ||
            ref.kind == MediaType.video) &&
        ref.durationSeconds != null) {
      return '$kind, ${ref.durationSeconds} ${ref.durationSeconds == 1 ? 'second' : 'seconds'}';
    }
    return '$kind$hint';
  }
  return '$kind, $phaseText';
}

/// Renders one attachment inside a [ChatBubble] — photo, document, audio
/// file, voice note and video, all five kinds this feature ships. See
/// docs/chat-attachments.md §C.5.
class ChatAttachmentContent extends StatelessWidget {
  final ThreadMessage message;
  final ChatAttachmentRef ref;
  final AttachmentPhase phase;
  final Uint8List? bytes;
  final Color textColor;
  final VoidCallback? onTap;

  /// The stored-phase action — expand a photo, open a document. Non-null
  /// only when [phase] is [AttachmentPhase.stored]. Never set for video:
  /// `_VideoTile` owns the player its fullscreen entry needs, so it decides
  /// that action internally instead of through a callback from above. See
  /// `ChatBubble`'s doc comment on `attachmentOpen`.
  final VoidCallback? onOpen;

  const ChatAttachmentContent({
    super.key,
    required this.message,
    required this.ref,
    required this.phase,
    required this.bytes,
    required this.textColor,
    this.onTap,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    switch (ref.kind) {
      case MediaType.picture:
        return _PhotoTile(
          ref: ref,
          phase: phase,
          bytes: bytes,
          onTap: onTap,
          onOpen: onOpen,
        );
      case MediaType.document:
        return _DocumentTile(
          ref: ref,
          phase: phase,
          textColor: textColor,
          onTap: onTap,
          onOpen: onOpen,
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
        return _VideoTile(ref: ref, phase: phase, bytes: bytes, onTap: onTap);
    }
  }
}

class _PhotoTile extends StatelessWidget {
  final ChatAttachmentRef ref;
  final AttachmentPhase phase;
  final Uint8List? bytes;
  final VoidCallback? onTap;

  /// Expands the photo full screen — see `ChatAttachmentContent.onOpen`.
  /// Non-null only once stored.
  final VoidCallback? onOpen;

  const _PhotoTile({
    required this.ref,
    required this.phase,
    required this.bytes,
    this.onTap,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final aspect =
        (ref.width != null && ref.height != null && ref.height! > 0)
            ? ref.width! / ref.height!
            : 4 / 3;

    // Pointer platforms (web, desktop) reserve a single click for whatever
    // this tile already does there — nothing, once stored, since a photo has
    // no other action — and use a double click to expand. Touch has no
    // competing single-tap action once stored, so a single tap expands.
    // Outside `stored` (`onOpen == null`), both reduce to plain `onTap`
    // (fetch/retry), so this never disturbs any earlier phase's behaviour.
    // See docs/chat-attachments.md §17 for why this is a platform split
    // rather than a live input-device one.
    final pointer = attachmentGestureMode() == AttachmentGestureMode.pointer;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        // Reserved before the bytes arrive, from the manifest — the thread
        // must not jump as each image loads in.
        aspectRatio: aspect,
        child: GestureDetector(
          onTap: pointer ? onTap : (onOpen ?? onTap),
          onDoubleTap: pointer ? onOpen : null,
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

/// Video — poster-and-play until tapped, then plays inline via `media_kit`
/// (libmpv-backed), which is what makes desktop video real rather than an
/// "open externally" button: `video_player` has no Windows or Linux
/// implementation. See docs/chat-attachments.md §C.1.
///
/// Bytes only become playable once [phase] is `stored` — video isn't
/// auto-fetched (§C.4's policy: images only), so a fresh bubble shows the
/// poster and waits for the tap the caller already wires through [onTap].
///
/// Fullscreen reuses this same player rather than opening a second one: see
/// docs/chat-attachments.md §17 for why a route-owned second `Player` would
/// double the memory and decode cost of a file that can already be 16 MB.
class _VideoTile extends StatefulWidget {
  final ChatAttachmentRef ref;
  final AttachmentPhase phase;
  final Uint8List? bytes;
  final VoidCallback? onTap;

  const _VideoTile({
    required this.ref,
    required this.phase,
    required this.bytes,
    this.onTap,
  });

  @override
  State<_VideoTile> createState() => _VideoTileState();
}

class _VideoTileState extends State<_VideoTile> {
  mk.Player? _player;
  mk_video.VideoController? _controller;
  String? _tempPath;
  String? _blobUrl;
  bool _pressed = false;

  /// Attached to the `Video` widget once playback starts, so a fullscreen
  /// request (from either gesture below) can reach `media_kit`'s own
  /// `enterFullscreen()` — which pushes its own route around this same
  /// player rather than creating a second one.
  final _videoKey = GlobalKey<mk_video.VideoState>();

  @override
  void dispose() {
    _player?.dispose();
    if (_tempPath != null) deleteAttachmentFile(_tempPath!).catchError((_) {});
    if (_blobUrl != null) revokeVideoBlobUrl(_blobUrl!);
    super.dispose();
  }

  Future<void> _startPlayback({bool fullscreen = false}) async {
    final bytes = widget.bytes;
    if (bytes == null) return;

    // A player already exists — this call only wants fullscreen on top of
    // playback that's already running (the pointer-platform double-click
    // case), so creation is skipped but the fullscreen request below still
    // has to run.
    if (_player == null) {
      final player = mk.Player();
      final controller = mk_video.VideoController(player);

      if (kIsWeb) {
        final url = createVideoBlobUrl(bytes, widget.ref.mime);
        if (url == null) return;
        _blobUrl = url;
        await player.open(mk.Media(url));
      } else {
        final dir = await getTemporaryDirectory();
        // ref.id is client-generated by whoever *sent* the message — see
        // safeAttachmentIdSegment's own doc comment.
        final path =
            '${dir.path}/chat_video_${safeAttachmentIdSegment(widget.ref.id)}.bin';
        await writeAttachmentBytes(path, bytes);
        _tempPath = path;
        await player.open(mk.Media(path));
      }

      if (!mounted) {
        await player.dispose();
        return;
      }
      setState(() {
        _player = player;
        _controller = controller;
      });
    }

    if (!fullscreen) return;

    // `GlobalKey.currentState` is null until the `Video` widget has actually
    // been built with this key — `setState` above only *schedules* that
    // build. Calling `enterFullscreen()` right after `setState` reaches a
    // null state and silently does nothing, which looks exactly like
    // "fullscreen isn't supported here." The post-frame callback waits for
    // that build to actually happen first.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _videoKey.currentState?.enterFullscreen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final aspect =
        (widget.ref.width != null &&
                widget.ref.height != null &&
                widget.ref.height! > 0)
            ? widget.ref.width! / widget.ref.height!
            : 16 / 9;

    final controller = _controller;
    if (controller != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          aspectRatio: aspect,
          child: mk_video.Video(
            key: _videoKey,
            controller: controller,
            // media_kit's own controls carry a fullscreen button once
            // playing — this tile's gesture layer only ever covers the
            // poster below, not a playing video.
            controls: mk_video.AdaptiveVideoControls,
          ),
        ),
      );
    }

    final canPlay =
        widget.phase == AttachmentPhase.stored && widget.bytes != null;
    final pointer = attachmentGestureMode() == AttachmentGestureMode.pointer;
    // Pointer: a single click plays inline, matching the pre-existing
    // behaviour; a double click plays *and* goes straight to fullscreen.
    // Touch: there is no separate "play inline" affordance to preserve, so
    // a single tap does what touch always does for a stored attachment —
    // opens it, which for video means playing fullscreen immediately. In
    // both cases this only redefines what `canPlay == true` does: when it's
    // false, `onTap` still falls through to `widget.onTap`
    // (`ChatAttachmentProvider.fetch`), so a not-yet-downloaded video still
    // downloads on the first tap either way.
    final singleTapAction =
        !canPlay
            ? widget.onTap
            : (pointer
                ? () => _startPlayback()
                : () => _startPlayback(fullscreen: true));
    final doubleTapAction =
        (canPlay && pointer) ? () => _startPlayback(fullscreen: true) : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: aspect,
        child: GestureDetector(
          onTap: singleTapAction,
          onDoubleTap: doubleTapAction,
          // `onTapDown`/`onTapUp`/`onTapCancel` fire immediately, before the
          // gesture arena resolves — unlike `onTap`, which a sibling
          // `onDoubleTap` defers for up to `kDoubleTapTimeout` (300ms) while
          // Flutter waits to see whether a second tap arrives. That delay is
          // structural, not "a bit slow": the only cell of this feature's
          // gesture matrix where both a single- and a double-tap action are
          // live at once is exactly this one (stored video, pointer mode —
          // every other tile/phase combination wires at most one of the
          // two). Immediate press feedback here is what keeps that 300ms
          // from reading as "nothing happened."
          onTapDown: canPlay ? (_) => setState(() => _pressed = true) : null,
          onTapUp: canPlay ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: canPlay ? () => setState(() => _pressed = false) : null,
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1,
            duration: ForgeMotion.of(context, ForgeMotion.quick),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: _parseAvgColor(widget.ref.avgColor)),
                if (widget.phase == AttachmentPhase.downloading ||
                    widget.phase == AttachmentPhase.uploading)
                  const _CenteredIcon(icon: null, showSpinner: true)
                else if (widget.phase == AttachmentPhase.expired)
                  const _CenteredIcon(icon: Icons.videocam_off_outlined)
                else if (widget.phase == AttachmentPhase.downloadFailed ||
                    widget.phase == AttachmentPhase.uploadFailed)
                  const _CenteredIcon(icon: Icons.error_outline_rounded)
                else
                  const _CenteredIcon(icon: Icons.play_circle_fill_rounded),
                if (widget.ref.durationSeconds != null)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${widget.ref.durationSeconds! ~/ 60}:${(widget.ref.durationSeconds! % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final ChatAttachmentRef ref;
  final AttachmentPhase phase;
  final Color textColor;
  final VoidCallback? onTap;

  /// Hands the stored document to the OS — see `ChatAttachmentContent.onOpen`.
  /// A document has no other single-tap action once stored, so unlike the
  /// photo and video tiles this never branches on gesture mode: [onOpen]
  /// simply takes over from [onTap] once it exists.
  final VoidCallback? onOpen;

  const _DocumentTile({
    required this.ref,
    required this.phase,
    required this.textColor,
    this.onTap,
    this.onOpen,
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
      onTap: onOpen ?? onTap,
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
      // ref.id is client-generated by whoever *sent* the message — see
      // safeAttachmentIdSegment's own doc comment.
      path = '${dir.path}/chat_audio_${safeAttachmentIdSegment(widget.ref.id)}.bin';
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
