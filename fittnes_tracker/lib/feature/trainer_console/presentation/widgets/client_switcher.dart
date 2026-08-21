import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_client_summary.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/active_client_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/client_avatar.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// The client-switcher chip shared by Session Review, Nutrition, and Workout
/// Builder. Reads and writes the shared [ActiveClientProvider], so switching
/// here updates every screen scoped to the active client.
///
/// Chip on desktop, full-width row on mobile where a chip is an awkward tap
/// target.
class ClientSwitcher extends StatelessWidget {
  final bool fullWidth;

  /// Optional line under the name (e.g. "5 completed · 2 missed").
  final String? subtitle;

  const ClientSwitcher({super.key, required this.fullWidth, this.subtitle});

  Future<void> _pick(BuildContext context, ActiveClientProvider provider) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ClientPickerSheet(
        clients: provider.clients,
        activeClientId: provider.activeClient?.clientId,
      ),
    );
    if (chosen != null) provider.setActiveClient(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final provider = context.watch<ActiveClientProvider>();
    final client = provider.activeClient;

    if (client == null) return const SizedBox.shrink();

    return Semantics(
      button: true,
      label: AppLocalizations.of(context)!.switchClientSemantics(
        client.clientName,
      ),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(fullWidth ? 12 : 999),
        child: InkWell(
          borderRadius: BorderRadius.circular(fullWidth ? 12 : 999),
          onTap: () => _pick(context, provider),
          child: Container(
            // 44px min height per CLAUDE.md's tap-target rule.
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(fullWidth ? 12 : 999),
              border: Border.all(
                color: colors.onSurface.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
              children: [
                ClientAvatar(
                  initials: client.initials,
                  clientId: client.clientId,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client.clientName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Exo 2',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Exo 2',
                            fontSize: 10.5,
                            color: colors.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.expand_more_rounded,
                  size: 20,
                  color: colors.onSurface.withValues(alpha: 0.55),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientPickerSheet extends StatelessWidget {
  final List<TrainerClientSummary> clients;
  final String? activeClientId;

  const _ClientPickerSheet({
    required this.clients,
    required this.activeClientId,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              AppLocalizations.of(context)!.switchClientHeading,
              style: TextStyle(
                fontFamily: 'Exo 2',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: colors.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: clients.length,
              itemBuilder: (context, index) {
                final client = clients[index];
                final selected = client.clientId == activeClientId;
                return ListTile(
                  leading: ClientAvatar(
                    initials: client.initials,
                    clientId: client.clientId,
                    size: 40,
                  ),
                  title: Text(
                    client.clientName,
                    style: const TextStyle(
                      fontFamily: 'Exo 2',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: client.programLabel == null
                      ? null
                      : Text(
                          client.programLabel!,
                          style: const TextStyle(
                            fontFamily: 'Exo 2',
                            fontSize: 12,
                          ),
                        ),
                  trailing: selected
                      ? const Icon(
                          Icons.check_rounded,
                          color: ForgeColors.forgeOrange,
                        )
                      : null,
                  selected: selected,
                  onTap: () => Navigator.of(context).pop(client.clientId),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
