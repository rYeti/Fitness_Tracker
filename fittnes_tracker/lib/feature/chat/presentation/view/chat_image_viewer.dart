import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey, SingleActivator;

import 'package:ForgeForm/core/forge_motion.dart';
import 'package:ForgeForm/feature/chat/domain/chat_attachment_labels.dart';
import 'package:ForgeForm/feature/chat/domain/models/chat_attachment_ref.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// Pushes a fullscreen viewer for [bytes] — a stored chat photo, expanded.
///
/// [bytes] is the same [Uint8List] the bubble already rendered, passed in
/// rather than re-read from `ChatAttachmentProvider`. Two reasons, not one:
///
/// - `ChatAttachmentProvider` is registered inside the chat *page*
///   (`coach_chat_entry.dart`, `trainer_console_home.dart`), and a route
///   pushed with `Navigator.of(context).push` is a *sibling* of that page in
///   the navigator's overlay, not a descendant of it — `context.watch` from
///   inside the pushed route would throw `ProviderNotFoundException`, not
///   silently return stale data. Provider lookup follows the widget tree,
///   not the navigation stack.
/// - Even if it were reachable, the bytes are already in hand at the tap
///   site (`attachmentState.bytes`), so there is nothing to fetch — and a
///   viewer that owns its own copy for its own lifetime can't be blanked by
///   a `notifyListeners()` from some other bubble's download finishing
///   elsewhere in the thread while this one is open.
///
/// Pass the *same* instance the bubble holds, not a copy: `Image.memory`
/// keys its decode cache on byte identity, so reusing the instance means
/// the viewer reuses the exact decode the bubble already paid for. A
/// `Uint8List.fromList(bytes)` anywhere in the hand-off silently pays for a
/// second full-resolution decode.
Future<void> showChatImageViewer(
  BuildContext context, {
  required Uint8List bytes,
  required ChatAttachmentRef ref,
  String? caption,
}) {
  // Read before the route is constructed: `PageRouteBuilder` fixes its
  // transition duration at construction time, so computing this from
  // inside the route's own builder would be too late to matter.
  final duration = ForgeMotion.of(context, ForgeMotion.emphasis);

  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: true,
      barrierColor: Colors.black,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder:
          (context, animation, secondaryAnimation) =>
              ChatImageViewer(bytes: bytes, ref: ref, caption: caption),
      transitionsBuilder:
          (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// The fullscreen body itself — a public widget (not a private class) so
/// widget tests can find it via `find.byType`.
class ChatImageViewer extends StatefulWidget {
  final Uint8List bytes;
  final ChatAttachmentRef ref;
  final String? caption;

  const ChatImageViewer({
    super.key,
    required this.bytes,
    required this.ref,
    this.caption,
  });

  @override
  State<ChatImageViewer> createState() => _ChatImageViewerState();
}

class _ChatImageViewerState extends State<ChatImageViewer> {
  final _transform = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _toggleZoom() {
    final details = _doubleTapDetails;
    if (details == null) return;

    final isZoomedIn = _transform.value != Matrix4.identity();
    if (isZoomedIn) {
      _transform.value = Matrix4.identity();
      return;
    }

    const zoom = 2.5;
    final position = details.localPosition;
    // Scale about the tapped point: translate it to the origin, scale, then
    // translate back — the standard "zoom under the cursor" matrix, so the
    // thing the user double-tapped is what ends up centred, not a corner.
    final matrix =
        Matrix4.identity()
          ..translate(position.dx, position.dy)
          ..scale(zoom)
          ..translate(-position.dx, -position.dy);
    _transform.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final caption = widget.caption;
    final hasCaption = caption != null && caption.isNotEmpty;
    final imageLabel =
        hasCaption
            ? '${attachmentKindLabel(l10n, widget.ref.kind)}, $caption'
            : attachmentKindLabel(l10n, widget.ref.kind);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape):
            () => Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        // Focus is what makes the Escape binding above actually receive the
        // key event — CallbackShortcuts only sees keys that reach a focused
        // descendant, and nothing in this route requests focus on its own.
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                // Outside the InteractiveViewer, not wrapping its child:
                // InteractiveViewer owns its own pan/scale recognizers, and
                // a GestureDetector nested inside its child steals the drag
                // gesture and breaks panning. A sibling detector around it
                // doesn't compete with pan — only double-tap is contested,
                // and InteractiveViewer doesn't claim that gesture itself.
                onDoubleTapDown: _onDoubleTapDown,
                onDoubleTap: _toggleZoom,
                child: InteractiveViewer(
                  transformationController: _transform,
                  minScale: 1,
                  maxScale: 5,
                  clipBehavior: Clip.none,
                  child: Center(
                    child: Semantics(
                      image: true,
                      label: imageLabel,
                      child: Image.memory(
                        widget.bytes,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        tooltip: l10n.chatAttachmentCloseViewer,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ),
                ),
              ),
              if (hasCaption)
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: Colors.black.withValues(alpha: 0.55),
                      child: Text(
                        caption,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Exo 2',
                          fontSize: 13.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
