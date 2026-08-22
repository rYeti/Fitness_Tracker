import 'package:flutter/material.dart';

import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// Shown when a message never made it as far as the network.
///
/// Distinct from both of the states either side of it. A message that reached
/// the server and is waiting on an ack is a *pending bubble*; a thread that
/// failed to load is a full-screen error. This is the third case — the send
/// broke before there was a bubble to dim, most often because the local outbox
/// write itself failed — and it used to be rendered as nothing at all, which
/// left the user watching their message vanish with no explanation anywhere.
///
/// A strip rather than a full-screen error on purpose: the thread behind it is
/// perfectly good and blanking it out over one undelivered message would destroy
/// more than it explains.
class ChatSendErrorStrip extends StatelessWidget {
  /// Null hides the strip entirely.
  final String? error;
  final VoidCallback onDismiss;

  const ChatSendErrorStrip({
    super.key,
    required this.error,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (error == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    const tone = ForgeColors.statusBad;

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        color: tone.withValues(alpha: 0.12),
        padding: const EdgeInsets.only(left: 16, top: 6, bottom: 6, right: 4),
        child: Row(
          children: [
            // Colour is never the only signal — the icon and the sentence both
            // carry the meaning for anyone who can't separate red from amber.
            const Icon(Icons.error_outline_rounded, size: 14, color: tone),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.chatSendFailed,
                style: const TextStyle(
                  fontFamily: 'Exo 2',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tone,
                ),
              ),
            ),
            Tooltip(
              message: l10n.chatDismiss,
              child: IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded),
                iconSize: 16,
                color: tone,
                // 44×44 even though the icon is 16: the minimum tap target is
                // about the finger, not the glyph.
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
