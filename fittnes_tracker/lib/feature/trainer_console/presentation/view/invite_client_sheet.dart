import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/console_error.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_licence.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/trainer_licence_provider.dart';
import 'package:ForgeForm/core/widgets/app_widgets.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/seat_meter.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// How a trainer adds a client: mint a code, share it, and the client enters it
/// in their own app.
///
/// A code holds a seat from the moment it's created, so outstanding invites are
/// listed here with a way to withdraw them — a trainer at their limit needs to
/// be able to reclaim a seat from a code nobody ever used.
class InviteClientSheet extends StatefulWidget {
  const InviteClientSheet({super.key});

  static Future<void> show(BuildContext context) {
    final provider = context.read<TrainerLicenceProvider>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: const InviteClientSheet(),
      ),
    ).then((_) => provider.clearNewInvite());
  }

  @override
  State<InviteClientSheet> createState() => _InviteClientSheetState();
}

class _InviteClientSheetState extends State<InviteClientSheet> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrainerLicenceProvider>();
    final licence = provider.licence;
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // The server's own refusal wins when it sent one — it can name the exact
    // plan size — and the typed failure covers the rest.
    final inviteError =
        provider.inviteFailure?.message(l10n) ??
        provider.inviteError?.localizedMessage(l10n);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.inviteAClient,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.inviteSheetBody,
              style: TextStyle(
                fontFamily: 'Exo 2',
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),

            if (licence != null) ...[
              SeatMeter(licence: licence),
              const SizedBox(height: 24),
            ],

            if (provider.newInviteCode != null)
              _InviteCodeCard(code: provider.newInviteCode!)
            else
              _MintButton(provider: provider, licence: licence),

            if (inviteError != null) ...[
              const SizedBox(height: 12),
              Semantics(
                container: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 18,
                      color: ForgeColors.statusBad,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        inviteError,
                        style: const TextStyle(
                          fontFamily: 'Exo 2',
                          fontSize: 13,
                          color: ForgeColors.statusBad,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (provider.pendingInvites.isNotEmpty) ...[
              const SizedBox(height: 32),
              SectionTitle(title: l10n.outstandingInvites),
              Text(
                l10n.outstandingInvitesBody,
                style: TextStyle(
                  fontFamily: 'Exo 2',
                  fontSize: 12,
                  color: colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 12),
              for (final invite in provider.pendingInvites)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PendingInviteRow(invite: invite),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MintButton extends StatelessWidget {
  final TrainerLicenceProvider provider;
  final TrainerLicence? licence;

  const _MintButton({required this.provider, required this.licence});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canInvite = provider.canInvite;

    // Disabled with a reason rather than hidden: a trainer looking for the
    // invite button needs to find out *why* they can't, not wonder where it
    // went.
    final reason = switch (licence) {
      null => l10n.licenceLoading,
      final l when l.isReadOnly => l10n.inviteBlockedLapsed,
      final l when l.isFull => l10n.inviteBlockedFull(l.seatLimit),
      _ => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tooltip(
          message: reason ?? l10n.createNewInviteCode,
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: canInvite && !provider.isMinting
                  ? provider.createInvite
                  : null,
              icon: provider.isMinting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(l10n.createInviteCode),
            ),
          ),
        ),
        if (reason != null) ...[
          const SizedBox(height: 8),
          Text(
            reason,
            style: TextStyle(
              fontFamily: 'Exo 2',
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  final String code;

  const _InviteCodeCard({required this.code});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      padding: const EdgeInsets.all(24),
      radius: 16,
      child: Column(
        children: [
          Semantics(
            container: true,
            excludeSemantics: true,
            label: l10n.inviteCodeSemantics(code.split('').join(' ')),
            child: SelectableText(
              code,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w800,
                fontSize: 28,
                letterSpacing: 4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.inviteCodeCopied)),
                );
              },
              icon: const Icon(Icons.copy, size: 18),
              label: Text(l10n.copyCode),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.inviteExpiresInSevenDays,
            style: TextStyle(
              fontFamily: 'Exo 2',
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingInviteRow extends StatelessWidget {
  final PendingInvite invite;

  const _PendingInviteRow({required this.invite});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final expiry = _expiryLabel(invite.expiresAt, l10n);

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.inviteCode,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  expiry,
                  style: TextStyle(
                    fontFamily: 'Exo 2',
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.copyInviteCode(invite.inviteCode),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: invite.inviteCode));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.inviteCodeCopied)),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
          ),
          IconButton(
            tooltip: l10n.withdrawInviteCode(invite.inviteCode),
            onPressed: () => _confirmWithdraw(context),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }

  /// Rounds *up*, because `inDays` truncates: an invite with six days and a few
  /// hours left would otherwise read "5 days" the instant it was created, which
  /// looks like the code is already stale.
  static String _expiryLabel(DateTime expiresAt, AppLocalizations l10n) {
    final hoursLeft = expiresAt.difference(DateTime.now()).inHours;
    if (hoursLeft <= 0) return l10n.inviteExpired;
    if (hoursLeft < 24) return l10n.inviteExpiresToday;
    // Plural handled by the message catalogue, not string surgery: German
    // needs no "1 day / 2 days" split here but other locales might.
    return l10n.inviteExpiresInDays((hoursLeft / 24).ceil());
  }

  /// Withdrawing is destructive — the code stops working for whoever it was
  /// sent to — so it takes a confirmation, per CLAUDE.md.
  Future<void> _confirmWithdraw(BuildContext context) async {
    final provider = context.read<TrainerLicenceProvider>();
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.withdrawInviteTitle),
        content: Text(l10n.withdrawInviteBody(invite.inviteCode)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.keep),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: ForgeColors.statusBad),
            child: Text(l10n.withdraw),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.revokeInvite(invite.id);
    }
  }
}
