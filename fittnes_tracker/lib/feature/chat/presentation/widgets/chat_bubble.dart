import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/core/providers/enums.dart';
import 'package:ForgeForm/feature/chat/data/attachment_opener.dart';
import 'package:ForgeForm/feature/chat/domain/attachment_open_outcome.dart';
import 'package:ForgeForm/feature/chat/domain/chat_timestamps.dart';
import 'package:ForgeForm/feature/chat/domain/models/chat_attachment_ref.dart';
import 'package:ForgeForm/feature/chat/domain/models/thread_message.dart';
import 'package:ForgeForm/feature/chat/presentation/providers/chat_attachment_provider.dart';
import 'package:ForgeForm/feature/chat/presentation/view/chat_image_viewer.dart';
import 'package:ForgeForm/feature/chat/presentation/widgets/chat_attachment_content.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// One message in a thread.
///
/// Takes a [ThreadMessage], so it neither knows nor cares whether the message
/// came from the server or is still sitting in this device's outbox — the three
/// states below are the only thing it reacts to.
class ChatBubble extends StatelessWidget {
  final ThreadMessage message;

  /// The thread this bubble belongs to — needed only to record a freshly
  /// downloaded attachment against the right thread in the device store.
  /// Null is fine wherever no [ChatAttachmentProvider] is in the tree either
  /// (existing text-only call sites and tests).
  final String? threadId;

  /// Invoked when the user taps a failed message to send it again.
  final ValueChanged<String>? onRetry;

  /// Overrides [openAttachmentExternally] for a stored document. Null in
  /// every production call site, which uses the real, platform-specific
  /// implementation; a test supplies a fake here rather than letting a
  /// stored-document tap reach a real platform channel
  /// (`open_filex`/`url_launcher`) or the real filesystem.
  final OpenAttachmentExternally? openAttachmentExternallyOverride;

  const ChatBubble({
    super.key,
    required this.message,
    this.threadId,
    this.onRetry,
    this.openAttachmentExternallyOverride,
  });

  static const _mineRadius = BorderRadius.only(
    topLeft: Radius.circular(14),
    topRight: Radius.circular(4),
    bottomLeft: Radius.circular(14),
    bottomRight: Radius.circular(14),
  );

  static const _theirsRadius = BorderRadius.only(
    topLeft: Radius.circular(4),
    topRight: Radius.circular(14),
    bottomLeft: Radius.circular(14),
    bottomRight: Radius.circular(14),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final mine = message.isMine;
    final pending = message.status == ChatMessageStatus.pending;
    final failed = message.status == ChatMessageStatus.failed;

    // Only a message the server has acknowledged has a real time to show. The
    // other two states carry the moment this device queued them, which is not
    // the same thing and must not be read as one.
    final settled = !pending && !failed;

    final unreadable = message.isUndecryptable;

    // What the reader is told when the key is gone. Phrased as an explanation
    // rather than an error, because nothing went wrong and there is nothing to
    // retry: this device simply never held the key for this message.
    final undecryptableText = l10n.chatUndecryptable;

    final textColor = mine ? Colors.white : colors.onSurface;
    final ref = message.attachment;

    // Optional: text-only call sites (and most existing tests) never mount a
    // ChatAttachmentProvider above this widget, and a bubble with no
    // attachment has no use for one either.
    ChatAttachmentProvider? attachments;
    if (ref != null) {
      try {
        attachments = context.watch<ChatAttachmentProvider>();
      } catch (_) {
        attachments = null;
      }
    }

    final attachmentState =
        ref == null
            ? null
            : (attachments?.stateFor(message) ??
                const AttachmentState(AttachmentPhase.notDownloaded));

    if (ref != null && attachments != null && threadId != null) {
      // No-ops once bytes are known or a fetch is already running — cheap to
      // call on every build. Per docs/chat-attachments.md §C.4: images only,
      // everything else waits for a tap.
      attachments.ensureAutoFetched(message, threadId: threadId!);
    }

    String semanticsValue;
    if (unreadable) {
      semanticsValue = undecryptableText;
    } else if (ref != null) {
      final attValue = attachmentSemanticsValue(
        l10n,
        ref,
        attachmentState!.phase,
      );
      final caption = message.body;
      semanticsValue =
          (caption != null && caption.isNotEmpty)
              ? '$attValue, $caption'
              : attValue;
    } else {
      semanticsValue = message.body ?? '';
    }
    if (settled) {
      semanticsValue =
          '$semanticsValue, ${ChatTimestamps.accessibleLabel(message.timestamp)}';
    }

    VoidCallback? attachmentTap;
    if (ref != null) {
      switch (attachmentState!.phase) {
        case AttachmentPhase.uploadFailed:
          attachmentTap =
              onRetry == null ? null : () => onRetry!(message.messageId);
        case AttachmentPhase.downloadFailed:
        case AttachmentPhase.notDownloaded:
          attachmentTap =
              (attachments == null || threadId == null)
                  ? null
                  : () => attachments!.fetch(message, threadId: threadId!);
        case AttachmentPhase.uploading:
        case AttachmentPhase.downloading:
        case AttachmentPhase.stored:
        case AttachmentPhase.expired:
          attachmentTap = null;
      }
    }

    // The action a *stored* attachment offers, once there is nothing left to
    // fetch: expanding a photo full screen, or handing a document to the OS.
    // Never set for video — `_VideoTile` owns the player its own fullscreen
    // entry needs, so it decides that action internally rather than through
    // a callback threaded down from here. Kind-specific rather than a single
    // "open" concept because "open" means something different for each: a
    // photo has nothing to open, only to view larger.
    VoidCallback? attachmentOpen;
    if (ref != null &&
        attachmentState!.phase == AttachmentPhase.stored &&
        attachmentState.bytes != null) {
      final bytes = attachmentState.bytes!;
      switch (ref.kind) {
        case MediaType.picture:
          attachmentOpen =
              () => showChatImageViewer(
                context,
                bytes: bytes,
                ref: ref,
                caption: message.body,
              );
        case MediaType.document:
          attachmentOpen =
              () => _openStoredDocument(
                context,
                l10n,
                ref,
                bytes,
                openAttachmentExternallyOverride ?? openAttachmentExternally,
              );
        case MediaType.video:
        case MediaType.audio:
        case MediaType.voiceNote:
          attachmentOpen = null;
      }
    }

    final Widget content;
    if (unreadable) {
      content = _UndecryptableContent(
        text: undecryptableText,
        textColor: textColor,
      );
    } else if (ref != null) {
      final caption = message.body;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatAttachmentContent(
            message: message,
            ref: ref,
            phase: attachmentState!.phase,
            bytes: attachmentState.bytes,
            textColor: textColor,
            onTap: attachmentTap,
            onOpen: attachmentOpen,
          ),
          if (caption != null && caption.isNotEmpty) ...[
            const SizedBox(height: 6),
            _TextContent(text: caption, textColor: textColor),
          ],
        ],
      );
    } else {
      content = _TextContent(text: message.body ?? '', textColor: textColor);
    }

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: mine ? ForgeColors.forgeOrange : colors.surfaceContainerHighest,
        borderRadius: mine ? _mineRadius : _theirsRadius,
      ),
      child: content,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Semantics(
            label: mine ? 'You said' : 'They said',
            // The time is part of what was said, not decoration: a screen reader
            // gets no day divider and no small grey text, so without it a thread
            // reads as one undated run of messages.
            // Every visual state — uploading, upload failed, downloading,
            // download failed, expired — is spelled into this value, not left
            // visual-only: a progress ring or a broken-image glyph is exactly
            // as invisible to a screen reader as colour would be.
            value: semanticsValue,
            // `excludeSemantics: true` below drops every descendant semantics
            // node, which means a `Semantics`/`onTap` added on a tile inside
            // `ChatAttachmentContent` would compile, render and do nothing —
            // this is the one node whose action can ever reach an assistive
            // technology. Wiring it also means a screen reader's "activate"
            // gesture (which sends a semantics action, not a raw touch at a
            // screen location) now reaches fetch/retry — which it could not
            // reach before this action existed either, on any platform or
            // phase, gesture split or not. `attachmentOpen` takes priority:
            // stored is the phase with something to open. Not wired for a
            // stored video — its fullscreen entry lives entirely inside
            // `_VideoTileState`, which this level has no handle on; see
            // docs/chat-attachments.md §17.
            onTap: attachmentOpen ?? attachmentTap,
            excludeSemantics: true,
            child: Opacity(
              // Dimmed rather than hidden: the message is real and the user
              // should keep seeing it, just not as settled yet.
              opacity: pending ? 0.6 : 1,
              child: bubble,
            ),
          ),
          // One line under the bubble, and only ever one thing on it: a settled
          // message shows when it was sent, an unsettled one shows why it has no
          // time yet. Pending deliberately shows no clock time — the moment the
          // user pressed send is not the moment the message exists, and printing
          // it would date a message the server may never have received.
          if (pending)
            const _SendingMarker()
          else if (failed)
            _FailedMarker(onTap: () => onRetry?.call(message.messageId))
          else
            // Excluded from the accessibility tree: the bubble's own semantic
            // value already carries this time, spelled out with its day.
            ExcludeSemantics(child: _MessageTime(at: message.timestamp)),
        ],
      ),
    );
  }
}

/// Hands a stored document to [open] (the real [openAttachmentExternally] in
/// production, a fake in a test — see `ChatBubble.openAttachmentExternallyOverride`)
/// and surfaces anything other than success — a phone with no PDF reader and
/// a genuinely failed write are different problems with different next steps
/// for the user, so [AttachmentOpenOutcome.noHandler] gets its own sentence
/// rather than folding into a generic error. Never a silent failure, per
/// CLAUDE.md.
Future<void> _openStoredDocument(
  BuildContext context,
  AppLocalizations l10n,
  ChatAttachmentRef ref,
  Uint8List bytes,
  OpenAttachmentExternally open,
) async {
  final outcome = await open(
    bytes: bytes,
    name: ref.name,
    mime: ref.mime,
    id: ref.id,
  );
  // The bubble that started this can be gone by the time the write/launch
  // finishes — an incoming message can rebuild the thread mid-open.
  if (!context.mounted) return;

  final message = switch (outcome) {
    AttachmentOpenOutcome.opened => null,
    AttachmentOpenOutcome.noHandler => l10n.chatAttachmentNoAppToOpen,
    AttachmentOpenOutcome.failed => l10n.chatAttachmentOpenFailed,
  };
  if (message == null) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

/// Plain message text — the common case, split out from [ChatBubble] now
/// that it has a third rendering path (attachments) alongside this and
/// [_UndecryptableContent].
class _TextContent extends StatelessWidget {
  final String text;
  final Color textColor;

  const _TextContent({required this.text, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Exo 2',
        fontSize: 13.5,
        height: 1.35,
        color: textColor,
      ),
    );
  }
}

/// What renders when this device never held the key for a message.
class _UndecryptableContent extends StatelessWidget {
  final String text;
  final Color textColor;

  const _UndecryptableContent({required this.text, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Paired with the italic text rather than carrying the meaning
        // alone: an icon-only signal is no signal at all to anyone who does
        // not already know what it means.
        Icon(
          Icons.lock_outline,
          size: 15,
          color: textColor.withValues(alpha: 0.75),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Exo 2',
              fontSize: 13.5,
              height: 1.35,
              fontStyle: FontStyle.italic,
              color: textColor.withValues(alpha: 0.75),
            ),
          ),
        ),
      ],
    );
  }
}

class _SendingMarker extends StatelessWidget {
  const _SendingMarker();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 3, right: 2),
      child: Tooltip(
        message: AppLocalizations.of(context)!.chatSending,
        child: Icon(
          Icons.schedule_rounded,
          size: 13,
          color: colors.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

/// When a settled message was sent, in the reader's timezone.
class _MessageTime extends StatelessWidget {
  final DateTime at;

  const _MessageTime({required this.at});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 3, left: 2, right: 2),
      child: Tooltip(
        // The time alone stops being enough as soon as a thread is scrolled back
        // past its day divider.
        message: ChatTimestamps.accessibleLabel(at),
        child: Text(
          ChatTimestamps.timeOfDay(at),
          style: TextStyle(
            fontFamily: 'Exo 2',
            fontSize: 10,
            fontWeight: FontWeight.w500,
            // 0.6 on the surface colour clears WCAG AA for this size against
            // both themes' card backgrounds; the bubble's own colour is not
            // behind it, so the orange/white pairing is not in play here.
            color: colors.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

/// The one message state with no automatic way out.
///
/// A pending message is the reconnect loop's problem; a failed one has already
/// exhausted it, so this is the only place the user has to act.
class _FailedMarker extends StatelessWidget {
  final VoidCallback onTap;

  const _FailedMarker({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context)!.chatFailedRetry;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 14,
                  color: ForgeColors.statusBad,
                ),
                const SizedBox(width: 4),
                // Icon plus words, never colour alone.
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Exo 2',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ForgeColors.statusBad,
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
