import 'package:flutter/material.dart';

import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_licence.dart';

/// A one-line notice with an icon, a tone, and an action. Colour is paired with
/// an icon and explicit copy so it carries without being seen as colour.
class ConsoleBanner extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ConsoleBanner({
    super.key,
    required this.icon,
    required this.tone,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: message,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tone.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: tone),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontFamily: 'Exo 2',
                  fontSize: 13,
                  color: colors.onSurface,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: tone,
                  minimumSize: const Size(44, 44),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The banner a trainer's own licence state warrants, or null when the plan is
/// healthy and has room.
///
/// Ordered by severity: a lapsed licence matters more than a full one, because
/// a lapsed licence has also taken every client's Pro with it.
class LicenceBanner extends StatelessWidget {
  final TrainerLicence licence;
  final VoidCallback? onManage;

  const LicenceBanner({super.key, required this.licence, this.onManage});

  static bool isWarranted(TrainerLicence licence) =>
      licence.isReadOnly || licence.isInGrace || licence.isFull;

  @override
  Widget build(BuildContext context) {
    if (licence.isReadOnly) {
      return ConsoleBanner(
        icon: Icons.lock_outline,
        tone: ForgeColors.statusBad,
        message:
            'Your licence has lapsed. Your clients are still here, but you '
            "can't change their plans and they've lost Pro.",
        actionLabel: 'Renew',
        onAction: onManage,
      );
    }

    if (licence.isInGrace) {
      return ConsoleBanner(
        icon: Icons.warning_amber_outlined,
        tone: ForgeColors.statusWarn,
        message:
            'Payment failed. Everything keeps working until '
            '${_formatDate(licence.graceEndsAt!)} — after that your clients '
            'lose Pro.',
        actionLabel: 'Fix payment',
        onAction: onManage,
      );
    }

    if (licence.isOverLimit) {
      return ConsoleBanner(
        icon: Icons.people_outline,
        tone: ForgeColors.statusBad,
        message:
            'You have ${licence.seatsUsed} clients on a '
            '${licence.seatLimit}-seat plan. Nobody is removed, but you '
            "can't add more.",
        actionLabel: 'Upgrade',
        onAction: onManage,
      );
    }

    if (licence.isFull) {
      return ConsoleBanner(
        icon: Icons.people_outline,
        tone: ForgeColors.statusWarn,
        message:
            'All ${licence.seatLimit} seats on your ${licence.tier.label} plan '
            'are in use.',
        actionLabel: 'Upgrade',
        onAction: onManage,
      );
    }

    return const SizedBox.shrink();
  }
}

/// What a *trainee* is told when the Pro they get through their trainer is
/// about to stop. They didn't do anything wrong, so this warns ahead of time
/// and offers them a way to keep it rather than letting a feature silently lock.
class TraineeProLapsingBanner extends StatelessWidget {
  final DateTime endsAt;
  final VoidCallback? onSeePlans;

  const TraineeProLapsingBanner({
    super.key,
    required this.endsAt,
    this.onSeePlans,
  });

  @override
  Widget build(BuildContext context) {
    return ConsoleBanner(
      icon: Icons.info_outline,
      tone: ForgeColors.statusWarn,
      message:
          'Pro through your trainer ends ${_formatDate(endsAt)}. Your data '
          'stays put — Pro features just lock.',
      actionLabel: 'Keep Pro',
      onAction: onSeePlans,
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]}';
}
