import 'package:flutter/material.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/exercise.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// Widget that displays a grid of muscle groups for selection
class MuscleGroupSelector extends StatelessWidget {
  final Function(MuscleGroup) onMuscleGroupSelected;

  const MuscleGroupSelector({Key? key, required this.onMuscleGroupSelected})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      padding: const EdgeInsets.all(16),
      children:
          MuscleGroup.values.map((muscleGroup) {
            return _MuscleGroupCard(
              muscleGroup: muscleGroup,
              onTap: () => onMuscleGroupSelected(muscleGroup),
            );
          }).toList(),
    );
  }
}

class _MuscleGroupCard extends StatelessWidget {
  final MuscleGroup muscleGroup;
  final VoidCallback onTap;

  const _MuscleGroupCard({
    Key? key,
    required this.muscleGroup,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            muscleGroupIcon(
              muscleGroup,
              size: 96,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              _getMuscleGroupName(l10n, muscleGroup),
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget muscleGroupIcon(
    MuscleGroup muscleGroup, {
    double size = 48,
    Color? color,
  }) {
    final colorFilter =
        color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null;

    const assetMap = {
      MuscleGroup.chest: 'assets/icons/Chest.png',
      MuscleGroup.back: 'assets/icons/back.png',
      MuscleGroup.shoulders: 'assets/icons/Shoulder.png',
      MuscleGroup.biceps: 'assets/icons/Biceps.png',
      MuscleGroup.triceps: 'assets/icons/Triceps.png',
      MuscleGroup.legs: 'assets/icons/Hamstrings.png',
    };

    final asset = assetMap[muscleGroup];
    if (asset != null) {
      return SvgPicture.asset(
        asset,
        width: size,
        height: size,
        colorFilter: colorFilter,
      );
    }

    // Fallback for muscle groups without a custom icon
    final fallbackIcon = muscleGroup == MuscleGroup.fullBody
        ? Icons.accessibility_new
        : Icons.self_improvement;
    return Icon(fallbackIcon, size: size, color: color);
  }

  String _getMuscleGroupName(AppLocalizations l10n, MuscleGroup muscleGroup) {
    switch (muscleGroup) {
      case MuscleGroup.chest:
        return l10n.muscleGroupChest;
      case MuscleGroup.back:
        return l10n.muscleGroupBack;
      case MuscleGroup.shoulders:
        return l10n.muscleGroupShoulders;
      case MuscleGroup.biceps:
        return l10n.muscleGroupBiceps;
      case MuscleGroup.triceps:
        return l10n.muscleGroupTriceps;
      case MuscleGroup.legs:
        return l10n.muscleGroupLegs;
      case MuscleGroup.abs:
        return l10n.muscleGroupAbs;
      case MuscleGroup.fullBody:
        return l10n.muscleGroupFullBody;
    }
  }
}
