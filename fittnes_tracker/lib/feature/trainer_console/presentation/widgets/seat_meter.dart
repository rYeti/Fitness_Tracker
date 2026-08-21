import 'package:flutter/material.dart';

import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_licence.dart';

/// How full a trainer's plan is: "7 of 30 clients", with a pill progress bar.
///
/// Tone is never the only signal — the label always states the numbers, since
/// a bar that turns amber tells a colourblind user nothing on its own.
class SeatMeter extends StatelessWidget {
  final TrainerLicence licence;

  /// Compact drops the caption and shrinks the bar, for the app bar chip.
  final bool compact;

  const SeatMeter({super.key, required this.licence, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final fraction = licence.seatLimit == 0
        ? 1.0
        : (licence.seatsUsed / licence.seatLimit).clamp(0.0, 1.0);

    final tone = switch (licence) {
      _ when licence.isOverLimit => ForgeColors.statusBad,
      _ when licence.isFull => ForgeColors.statusWarn,
      _ => ForgeColors.forgeOrange,
    };

    final label = l10n.seatMeterUsage(licence.seatsUsed, licence.seatLimit);
    final caption = switch (licence) {
      _ when licence.isOverLimit => l10n.seatMeterOverLimit,
      _ when licence.isFull => l10n.seatMeterFull,
      _ => l10n.seatMeterRemaining(licence.seatsRemaining),
    };

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: l10n.seatMeterSemantics(label, caption),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 13 : 15,
                    color: colors.onSurface,
                  ),
                ),
              ),
              if (!compact && (licence.isFull || licence.isOverLimit))
                Icon(Icons.error_outline, size: 16, color: tone),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: compact ? 4 : 8,
              backgroundColor: colors.onSurface.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(tone),
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 8),
            Text(
              caption,
              style: TextStyle(
                fontFamily: 'Exo 2',
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The app-bar chip: "7 / 30", tapped to open the licence screen.
class SeatChip extends StatelessWidget {
  final TrainerLicence licence;
  final VoidCallback? onTap;

  const SeatChip({super.key, required this.licence, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tone = licence.isOverLimit
        ? ForgeColors.statusBad
        : licence.isFull
        ? ForgeColors.statusWarn
        : ForgeColors.forgeOrange;

    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      label: l10n.seatChipSemantics(
        licence.seatsUsed,
        licence.seatLimit,
        licence.tier.localizedLabel(l10n),
      ),
      child: Tooltip(
        message: l10n.seatChipTooltip(
          licence.tier.localizedLabel(l10n),
          licence.seatsUsed,
          licence.seatLimit,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          // 44px minimum tap target on mobile, per CLAUDE.md.
          child: Container(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: tone.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline, size: 16, color: tone),
                  const SizedBox(width: 6),
                  Text(
                    '${licence.seatsUsed} / ${licence.seatLimit}',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
