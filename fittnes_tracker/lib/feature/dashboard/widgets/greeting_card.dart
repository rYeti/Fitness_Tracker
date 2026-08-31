import 'package:flutter/material.dart';

import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/core/widgets/client_avatar.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/stat_tile.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// The trainee dashboard's hero card: avatar and greeting, three stat tiles,
/// and the day's calorie bar.
///
/// Lifted out of `_DashboardScreenState`, where it was three private build
/// methods. Nothing in it reads state or touches the database — it takes six
/// numbers and a name — so the only thing keeping it there was proximity, and
/// the cost was that it could not be tested without pumping the whole
/// dashboard. Which cannot be pumped: `DashboardWeightCard` reads
/// localizations in `initState`, and the screen leaves a timer running.
///
/// The avatar used to be a `Positioned` overlay hanging off the top edge of
/// the card, inside a `Stack`. It overlapped the greeting beside it — the card
/// began 12px down, the avatar was 54px tall from y=0, and the greeting text
/// started at y=40, so the first word rendered *behind* the circle. Nothing in
/// the layout system objected, and nothing could: letting children occupy the
/// same space is what a Stack is for. A Row cannot express that bug at all.
class GreetingCard extends StatelessWidget {
  final String name;
  final int todayCalories;
  final double calorieGoal;
  final int weekCompleted;
  final int weekTotal;
  final int allTimeCompleted;

  const GreetingCard({
    super.key,
    required this.name,
    required this.todayCalories,
    required this.calorieGoal,
    required this.weekCompleted,
    required this.weekTotal,
    required this.allTimeCompleted,
  });

  /// "Good evening, Robert!" — or just "Good evening!" before the profile has
  /// loaded, which is a real state on the first frame and not an edge case.
  static String greeting(AppLocalizations l10n, String name, {DateTime? now}) {
    final hour = (now ?? DateTime.now()).hour;
    final base = hour < 12
        ? l10n.goodMorning
        : (hour < 17 ? l10n.goodAfternoon : l10n.goodEvening);
    if (name.trim().isEmpty) return base;
    return base.endsWith('!')
        ? '${base.substring(0, base.length - 1)}, ${name.trim()}!'
        : '$base, ${name.trim()}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.10),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClientAvatar(
                initials: ClientAvatar.initialsFor(name),
                // The palette is keyed on identity so one person keeps one
                // colour across Roster, Chat and Detail. On your own dashboard
                // that person is always you, so the name is a stable key.
                clientId: name,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  greeting(l10n, name),
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              StatTile(
                icon: Icons.local_fire_department,
                value: '$todayCalories',
                label: l10n.calories,
                accentColor: colorScheme.primary,
              ),
              StatTile(
                icon: Icons.fitness_center,
                value: weekTotal > 0 ? '$weekCompleted/$weekTotal' : '--',
                label: l10n.workouts,
                accentColor: colorScheme.onSurface,
              ),
              StatTile(
                icon: Icons.emoji_events,
                value: '$allTimeCompleted',
                label: l10n.allTime,
                accentColor: colorScheme.onSurface,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _CaloriesProgress(
            todayCalories: todayCalories,
            calorieGoal: calorieGoal,
          ),
        ],
      ),
    );
  }
}

class _CaloriesProgress extends StatelessWidget {
  final int todayCalories;
  final double calorieGoal;

  const _CaloriesProgress({
    required this.todayCalories,
    required this.calorieGoal,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    // A zero goal is not reachable through the UI, but it is reachable through
    // a half-written settings row, and NaN renders as a blank bar rather than
    // as an error.
    final progress = calorieGoal > 0 ? todayCalories / calorieGoal : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.dailyCalories,
              style: TextStyle(
                fontFamily: 'Exo 2',
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: colorScheme.onSurface,
              ),
            ),
            Text(
              '$todayCalories / ${calorieGoal.toInt()}',
              style: TextStyle(
                fontFamily: 'Exo 2',
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Semantics(
            // A bar with no label is a coloured rectangle to a screen reader.
            label: '${l10n.dailyCalories}, $todayCalories / ${calorieGoal.toInt()}',
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: colorScheme.onSurface.withValues(alpha: 0.07),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress > 1.0 ? ForgeColors.statusBad : colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
