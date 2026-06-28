import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class WeightProgressCard extends StatelessWidget {
  final double currentWeight;
  final double startingWeight;
  final double goalWeight;
  final double progress; // Value between 0.0 and 1.0
  final String? completionEstimate;

  const WeightProgressCard({
    Key? key,
    required this.currentWeight,
    required this.startingWeight,
    required this.goalWeight,
    required this.progress,
    this.completionEstimate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isWeightLoss = startingWeight > goalWeight;
    final weightChange = currentWeight - startingWeight;
    final isPositiveProgress =
        isWeightLoss ? weightChange < 0 : weightChange > 0;

    final badgeColor = isPositiveProgress
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFFEBEE);
    final badgeTextColor = isPositiveProgress
        ? const Color(0xFF2E7D32)
        : const Color(0xFFB71C1C);
    final trendIcon = isPositiveProgress
        ? (isWeightLoss ? Icons.trending_down : Icons.trending_up)
        : (isWeightLoss ? Icons.trending_up : Icons.trending_down);
    final changeSign = weightChange > 0 ? '+' : '';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Extra right padding only here — two icon buttons (≈96 px) sit above this row
          Padding(
            padding: const EdgeInsets.only(right: 96),
            child: Text(
              l10n.weightProgress,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: currentWeight.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    TextSpan(
                      text: ' kg',
                      style: TextStyle(
                        fontSize: 18,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(trendIcon, size: 16, color: badgeTextColor),
                    const SizedBox(width: 4),
                    Text(
                      '$changeSign${weightChange.toStringAsFixed(1)} kg',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: badgeTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor:
                  theme.colorScheme.onSurface.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${l10n.weightStarting} ${startingWeight.toStringAsFixed(0)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                '${l10n.weightGoalLabel} ${goalWeight.toStringAsFixed(0)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
