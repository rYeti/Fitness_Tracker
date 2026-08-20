import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_licence.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/trainer_licence_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/console_widgets.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/seat_meter.dart';

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
              'Invite a client',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share the code with your client. They enter it under '
              '"Join a trainer" in their app.',
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

            if (provider.inviteError != null) ...[
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
                        provider.inviteError!,
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
              const ConsoleSectionTitle(title: 'Outstanding invites'),
              Text(
                'Each of these holds a seat until it is used or withdrawn.',
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
    final canInvite = provider.canInvite;

    // Disabled with a reason rather than hidden: a trainer looking for the
    // invite button needs to find out *why* they can't, not wonder where it
    // went.
    final reason = switch (licence) {
      null => 'Loading your plan…',
      final l when l.isReadOnly => 'Renew your licence to invite clients.',
      final l when l.isFull =>
        'All ${l.seatLimit} seats are in use. Withdraw an invite or upgrade.',
      _ => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tooltip(
          message: reason ?? 'Create a new invite code',
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
              label: const Text('Create invite code'),
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
    return ConsoleCard(
      padding: const EdgeInsets.all(24),
      radius: 16,
      child: Column(
        children: [
          Semantics(
            container: true,
            excludeSemantics: true,
            label: 'Invite code ${code.split('').join(' ')}',
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
                  const SnackBar(content: Text('Invite code copied')),
                );
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy code'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Expires in 7 days.',
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
    final expiry = _expiryLabel(invite.expiresAt);

    return ConsoleCard(
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
            tooltip: 'Copy ${invite.inviteCode}',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: invite.inviteCode));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invite code copied')),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
          ),
          IconButton(
            tooltip: 'Withdraw ${invite.inviteCode}',
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
  static String _expiryLabel(DateTime expiresAt) {
    final hoursLeft = expiresAt.difference(DateTime.now()).inHours;
    if (hoursLeft <= 0) return 'Expired';
    if (hoursLeft < 24) return 'Expires today';
    final days = (hoursLeft / 24).ceil();
    return 'Expires in $days ${days == 1 ? 'day' : 'days'}';
  }

  /// Withdrawing is destructive — the code stops working for whoever it was
  /// sent to — so it takes a confirmation, per CLAUDE.md.
  Future<void> _confirmWithdraw(BuildContext context) async {
    final provider = context.read<TrainerLicenceProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Withdraw this invite?'),
        content: Text(
          '${invite.inviteCode} will stop working and its seat is freed. '
          'Anyone you already sent it to will need a new code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: ForgeColors.statusBad),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.revokeInvite(invite.id);
    }
  }
}
