import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/core/providers/enums.dart';
import 'package:ForgeForm/feature/chat/data/chat_attachment_sender.dart';
import 'package:ForgeForm/feature/chat/data/image_downscale.dart';
import 'package:ForgeForm/feature/chat/domain/models/chat_draft.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

enum _AttachChoice { gallery, camera, document }

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

  const ChatComposer({
    super.key,
    required this.onSend,
    this.attachmentsEnabled = true,
    this.attachmentSender,
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late final ChatAttachmentSender _sender =
      widget.attachmentSender ?? ChatAttachmentSender();

  bool _preparing = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
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

  /// No camera on desktop or web — the affordance is hidden there rather
  /// than shown and failing.
  bool get _cameraAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

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
        choice: _AttachChoice.document,
        icon: Icons.description_outlined,
        label: l10n.chatAttachDocument,
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
      case _AttachChoice.document:
        await _pickDocument();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final attachEnabled = widget.attachmentsEnabled && !_preparing;

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
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: const TextStyle(fontFamily: 'Exo 2', fontSize: 14),
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
            Tooltip(
              message: l10n.chatSendMessage,
              child: Semantics(
                button: true,
                label: l10n.chatSendMessage,
                excludeSemantics: true,
                child: Material(
                  color: ForgeColors.forgeOrange,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _send,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.send_rounded,
                        size: 19,
                        color: Colors.white,
                      ),
                    ),
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
