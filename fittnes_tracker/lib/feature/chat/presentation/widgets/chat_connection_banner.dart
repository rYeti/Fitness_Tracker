import 'package:flutter/material.dart';

import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/feature/chat/data/chat_signalr_client.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// A thin strip explaining why nothing is arriving.
///
/// Without it, a flaky connection is indistinguishable from a quiet client —
/// the trainer keeps typing into a thread that is going nowhere.
class ChatConnectionBanner extends StatelessWidget {
  final ChatConnectionStatus status;

  const ChatConnectionBanner({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == ChatConnectionStatus.connected) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final reconnecting = status == ChatConnectionStatus.reconnecting;
    final tone = reconnecting ? ForgeColors.statusWarn : ForgeColors.statusBad;
    final label = reconnecting ? l10n.chatReconnecting : l10n.chatOffline;

    return Semantics(
      liveRegion: true,
      label: reconnecting
          ? 'Reconnecting. Messages you send will be delivered once the '
              'connection is back.'
          : 'Offline. Messages you send will be delivered once the connection '
              'is back.',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        color: tone.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              reconnecting
                  ? Icons.sync_rounded
                  : Icons.cloud_off_rounded,
              size: 14,
              color: tone,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Exo 2',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
