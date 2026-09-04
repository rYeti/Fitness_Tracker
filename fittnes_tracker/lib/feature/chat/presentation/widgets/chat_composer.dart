import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/core/providers/enums.dart';
import 'package:ForgeForm/feature/chat/data/chat_attachment_file.dart';
import 'package:ForgeForm/feature/chat/data/chat_attachment_sender.dart';
import 'package:ForgeForm/feature/chat/data/image_downscale.dart';
import 'package:ForgeForm/feature/chat/data/voice_recorder.dart';
import 'package:ForgeForm/feature/chat/domain/models/chat_draft.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

enum _AttachChoice { gallery, camera, document, audio, voiceNote, video }

/// The message input: attachment affordance, pill field, circular orange send.
///
/// Owns its own [TextEditingController] because the draft is screen state, not
/// shared client data — a half-typed message has no business in ChatProvider.
class ChatComposer extends StatefulWidget {
  final ValueChanged<ChatDraft> onSend;

  /// Whether the server has attachment storage configured. Kept disabled
  /// with its existing tooltip, rather than removed, when false — so the
  /// layout doesn't shift the moment it starts working.
  final bool attachmentsEnabled;

  /// Injection seam for tests — never touches the network or the file
  /// system unless a test supplies bytes through it.
  final ChatAttachmentSender? attachmentSender;

  /// Injection seam for tests — never touches the microphone unless a test
  /// supplies a fake.
  final VoiceRecorder? voiceRecorder;

  const ChatComposer({
    super.key,
    required this.onSend,
    this.attachmentsEnabled = true,
    this.attachmentSender,
    this.voiceRecorder,
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late final ChatAttachmentSender _sender =
      widget.attachmentSender ?? ChatAttachmentSender();
  late final VoiceRecorder _recorder =
      widget.voiceRecorder ?? PlatformVoiceRecorder();

  bool _preparing = false;
  bool _recording = false;
  int _recordedSeconds = 0;
  Timer? _recordingTicker;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focus.dispose();
    _recordingTicker?.cancel();
    if (_recording) unawaited(_recorder.cancel());
    unawaited(_recorder.dispose());
    super.dispose();
  }

  void _onTextChanged() {
    // The mic/send swap depends on whether the field is empty — repaint on
    // every keystroke that crosses that boundary.
    setState(() {});
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    // Cleared before the send is awaited: the message is already durable in the
    // outbox by then, so holding the text hostage to the network would only make
    // a slow connection feel like a broken button.
    _controller.clear();
    widget.onSend(ChatDraft(caption: text));
    _focus.requestFocus();
  }

  void _showTooLarge() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.chatAttachmentTooLarge),
      ),
    );
  }

  Future<void> _sendAttachment(
    Uint8List bytes, {
    required MediaType kind,
    required String mime,
    required String name,
    int? width,
    int? height,
    String? avgColor,
    int? durationSeconds,
  }) async {
    setState(() => _preparing = true);
    try {
      final sealed = await _sender.seal(
        plaintext: bytes,
        kind: kind,
        mime: mime,
        name: name,
        width: width,
        height: height,
        avgColor: avgColor,
        durationSeconds: durationSeconds,
      );
      final caption = _controller.text.trim();
      _controller.clear();
      widget.onSend(ChatDraft(caption: caption, attachment: sealed));
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _pickPhoto({required ImageSource source}) async {
    final file = await ImagePicker().pickImage(source: source);
    if (file == null) return;
    final original = await file.readAsBytes();

    final downscaled = await ImageDownscale.forChat(original);
    if (downscaled == null) {
      _showTooLarge();
      return;
    }
    await _sendAttachment(
      downscaled.bytes,
      kind: MediaType.picture,
      mime: 'image/jpeg',
      name: file.name,
      width: downscaled.width,
      height: downscaled.height,
      avgColor: downscaled.avgColor,
    );
  }

  /// The cap this feature enforces for a video attachment — twice the image
  /// cap, and enforced client-side only, same as every other kind (see
  /// docs/chat-attachments.md §0.2). There is no re-encode step for video:
  /// a file over this size is refused, not compressed.
  static const _maxVideoBytes = 16 * 1024 * 1024;

  Future<void> _pickVideo() async {
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > _maxVideoBytes) {
      _showTooLarge();
      return;
    }
    await _sendAttachment(
      bytes,
      kind: MediaType.video,
      mime: 'video/mp4',
      name: file.name,
    );
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;
    if (file.size > ImageDownscale.maxDocumentBytes) {
      _showTooLarge();
      return;
    }
    await _sendAttachment(
      file.bytes!,
      kind: MediaType.document,
      mime: 'application/octet-stream',
      name: file.name,
    );
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true,
    );
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;
    if (file.size > ImageDownscale.maxDocumentBytes) {
      _showTooLarge();
      return;
    }
    await _sendAttachment(
      file.bytes!,
      kind: MediaType.audio,
      mime: 'audio/mpeg',
      name: file.name,
    );
  }

  Future<void> _startRecording() async {
    final ok = await _recorder.start();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.chatMicUnavailable),
        ),
      );
      return;
    }
    setState(() {
      _recording = true;
      _recordedSeconds = 0;
    });
    _recordingTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordedSeconds = _recorder.elapsedSeconds);
    });
  }

  Future<void> _stopRecordingAndSend() async {
    _recordingTicker?.cancel();
    _recordingTicker = null;
    final result = await _recorder.stop();
    if (!mounted) return;
    setState(() => _recording = false);
    if (result == null) return; // too short, or nothing recorded

    final bytes = await readAttachmentBytes(result.path);
    if (bytes == null) return;
    await _sendAttachment(
      bytes,
      kind: MediaType.voiceNote,
      mime: 'audio/mp4',
      name: 'voice-note.m4a',
      durationSeconds: result.durationSeconds,
    );
    unawaited(deleteAttachmentFile(result.path));
  }

  Future<void> _cancelRecording() async {
    _recordingTicker?.cancel();
    _recordingTicker = null;
    await _recorder.cancel();
    if (mounted) setState(() => _recording = false);
  }

  /// No camera, and no recorder, on desktop or web — the affordances are
  /// hidden there rather than shown and failing. Linux additionally has no
  /// bundled recording binary (docs/chat-attachments.md §C.1), so its mic
  /// stays hidden even though it is otherwise a desktop platform capable of
  /// everything else here.
  bool get _cameraAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _micAvailable =>
      !kIsWeb && defaultTargetPlatform != TargetPlatform.linux;

  List<({_AttachChoice choice, IconData icon, String label})> _choices(
    AppLocalizations l10n,
  ) {
    return [
      (
        choice: _AttachChoice.gallery,
        icon: Icons.photo_outlined,
        label: l10n.chatAttachPhoto,
      ),
      if (_cameraAvailable)
        (
          choice: _AttachChoice.camera,
          icon: Icons.photo_camera_outlined,
          label: l10n.chatAttachCamera,
        ),
      (
        choice: _AttachChoice.video,
        icon: Icons.videocam_outlined,
        label: l10n.chatAttachVideo,
      ),
      (
        choice: _AttachChoice.document,
        icon: Icons.description_outlined,
        label: l10n.chatAttachDocument,
      ),
      (
        choice: _AttachChoice.audio,
        icon: Icons.audiotrack_outlined,
        label: l10n.chatAttachAudio,
      ),
      // The keyboard/switch-control equivalent to the mic affordance below,
      // which a press-and-hold gesture would otherwise leave unreachable.
      if (_micAvailable)
        (
          choice: _AttachChoice.voiceNote,
          icon: Icons.mic_none_rounded,
          label: l10n.chatAttachVoiceNote,
        ),
    ];
  }

  Future<void> _openAttachMenu() async {
    final l10n = AppLocalizations.of(context)!;
    final choices = _choices(l10n);
    // Desktop/web get a menu (a bottom sheet reads as mobile chrome there);
    // mobile gets the sheet, matching the rest of this repo's breakpoint
    // convention (lib/core/design_tokens.dart's Breakpoints).
    final isDesktop = MediaQuery.sizeOf(context).width >= Breakpoints.mobile;

    final _AttachChoice? choice =
        isDesktop
            ? await showMenu<_AttachChoice>(
              context: context,
              position: const RelativeRect.fromLTRB(16, 200, 0, 0),
              items: [
                for (final c in choices)
                  PopupMenuItem(
                    value: c.choice,
                    child: Row(
                      children: [
                        Icon(c.icon, size: 20),
                        const SizedBox(width: 12),
                        Text(c.label),
                      ],
                    ),
                  ),
              ],
            )
            : await showModalBottomSheet<_AttachChoice>(
              context: context,
              builder:
                  (sheetContext) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final c in choices)
                          ListTile(
                            leading: Icon(c.icon),
                            title: Text(c.label),
                            onTap:
                                () => Navigator.of(sheetContext).pop(c.choice),
                          ),
                      ],
                    ),
                  ),
            );

    if (!mounted || choice == null) return;
    switch (choice) {
      case _AttachChoice.gallery:
        await _pickPhoto(source: ImageSource.gallery);
      case _AttachChoice.camera:
        await _pickPhoto(source: ImageSource.camera);
      case _AttachChoice.video:
        await _pickVideo();
      case _AttachChoice.document:
        await _pickDocument();
      case _AttachChoice.audio:
        await _pickAudioFile();
      case _AttachChoice.voiceNote:
        await _startRecording();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final attachEnabled =
        widget.attachmentsEnabled && !_preparing && !_recording;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // IconButton's own `tooltip:` rather than a wrapping Tooltip
            // widget - a Tooltip wrapped around a *disabled* child doesn't
            // merge its label into the child's semantics node on web, so a
            // screen reader saw a nameless button here.
            IconButton(
              tooltip: attachEnabled ? null : l10n.chatAttachmentsUnavailable,
              onPressed: attachEnabled ? _openAttachMenu : null,
              icon:
                  _preparing
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.add_rounded),
              iconSize: 22,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
            const SizedBox(width: 4),
            Expanded(
              child:
                  _recording
                      ? _RecordingIndicator(
                        seconds: _recordedSeconds,
                        onCancel: _cancelRecording,
                      )
                      : TextField(
                        controller: _controller,
                        focusNode: _focus,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        style: const TextStyle(
                          fontFamily: 'Exo 2',
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: l10n.chatComposerHint,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          filled: true,
                          fillColor: colors.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
            ),
            const SizedBox(width: 8),
            _TrailingButton(
              recording: _recording,
              showMic:
                  !_recording &&
                  _controller.text.trim().isEmpty &&
                  _micAvailable &&
                  widget.attachmentsEnabled,
              onSend: _send,
              onStartRecording: _startRecording,
              onStopRecording: _stopRecordingAndSend,
            ),
          ],
        ),
      ),
    );
  }
}

/// The circular trailing button: send (default), a tap-to-record mic when
/// the field is empty and recording is available, or tap-to-stop while a
/// voice note is in progress. Tap-to-toggle rather than press-and-hold — the
/// same affordance is reachable by touch, mouse, keyboard and switch control
/// without needing the separate "Voice note" sheet entry as its only route.
class _TrailingButton extends StatelessWidget {
  final bool recording;
  final bool showMic;
  final VoidCallback onSend;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;

  const _TrailingButton({
    required this.recording,
    required this.showMic,
    required this.onSend,
    required this.onStartRecording,
    required this.onStopRecording,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final VoidCallback action;
    final IconData icon;
    final String label;
    final Color color;

    if (recording) {
      action = onStopRecording;
      icon = Icons.send_rounded;
      label = l10n.chatSendVoiceNote;
      color = ForgeColors.forgeOrange;
    } else if (showMic) {
      action = onStartRecording;
      icon = Icons.mic_none_rounded;
      label = l10n.chatAttachVoiceNote;
      color = ForgeColors.forgeOrange;
    } else {
      action = onSend;
      icon = Icons.send_rounded;
      label = l10n.chatSendMessage;
      color = ForgeColors.forgeOrange;
    }

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: action,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, size: 19, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordingIndicator extends StatelessWidget {
  final int seconds;
  final VoidCallback onCancel;

  const _RecordingIndicator({required this.seconds, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final label =
        '${(seconds ~/ 60).toString().padLeft(1, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

    return Semantics(
      label: '${l10n.chatRecording}, $label',
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.fiber_manual_record,
              color: ForgeColors.statusBad,
              size: 12,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Exo 2',
                fontSize: 13.5,
                color: colors.onSurface,
              ),
            ),
            const Spacer(),
            Semantics(
              button: true,
              label: l10n.chatRecordingCancel,
              excludeSemantics: true,
              child: InkWell(
                onTap: onCancel,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
