import 'package:flutter/material.dart';
import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/macro_summary.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// Every food in one logged meal, with its own weight, calories and macros.
///
/// The Nutrition meal row only has space for a one-line, ellipsised list of
/// names; this is where a trainer sees what a meal was actually made of and
/// which item carried the calories.
///
/// A bottom sheet on every breakpoint, matching the console's other overlays
/// (client switcher, invite sheet), but width-capped on desktop so it doesn't
/// stretch into an unreadable strip.
class MealDetailSheet extends StatelessWidget {
  final LoggedMeal meal;

  /// Already localized by the caller, which owns the category-slug mapping.
  final String mealLabel;

  final IconData icon;

  const MealDetailSheet({
    super.key,
    required this.meal,
    required this.mealLabel,
    required this.icon,
  });

  static Future<void> show(
    BuildContext context, {
    required LoggedMeal meal,
    required String mealLabel,
    required IconData icon,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      // Honour the OS reduced-motion setting: the sheet still opens, it just
      // stops sliding up.
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (_) =>
          MealDetailSheet(meal: meal, mealLabel: mealLabel, icon: icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(meal: meal, mealLabel: mealLabel, icon: icon),
            const SizedBox(height: 16),
            MacroSummary(
              protein: meal.macros.protein,
              carbs: meal.macros.carbs,
              fat: meal.macros.fat,
              calorieGoal: 0,
            ),
            const SizedBox(height: 24),
            Text(
              l10n.foods,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            // A long meal scrolls inside the sheet rather than pushing the
            // header off-screen; shrinkWrap keeps a two-item meal short.
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: meal.foods.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: colors.onSurface.withValues(alpha: 0.08),
                ),
                itemBuilder: (_, index) => _FoodRow(food: meal.foods[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final LoggedMeal meal;
  final String mealLabel;
  final IconData icon;

  const _Header({
    required this.meal,
    required this.mealLabel,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ForgeColors.forgeOrange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 21, color: ForgeColors.forgeOrange),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mealLabel,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.foodCount(meal.foods.length),
                style: TextStyle(
                  fontFamily: 'Exo 2',
                  fontSize: 12.5,
                  color: colors.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${meal.calories} ${l10n.kcal}',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: colors.onSurface,
          ),
        ),
      ],
    );
  }
}

class _FoodRow extends StatelessWidget {
  final LoggedFood food;

  const _FoodRow({required this.food});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // One label for the whole row: the name, weight, kcal and three macro
    // chips would otherwise be read out as six unconnected fragments.
    final semanticsLabel = food.grams > 0
        ? l10n.foodRowSemantics(
            food.name,
            food.grams,
            food.calories,
            food.macros.protein,
            food.macros.carbs,
            food.macros.fat,
          )
        : l10n.foodRowSemanticsNoWeight(
            food.name,
            food.calories,
            food.macros.protein,
            food.macros.carbs,
            food.macros.fat,
          );

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: semanticsLabel,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    style: TextStyle(
                      fontFamily: 'Exo 2',
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // A food item with no recorded serving size shows no
                      // weight rather than a misleading "0 g".
                      if (food.grams > 0)
                        Text(
                          l10n.gramsShort(food.grams),
                          style: TextStyle(
                            fontFamily: 'Exo 2',
                            fontSize: 11.5,
                            color: colors.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      _MacroChip(
                        color: ForgeColors.proteinColor,
                        label: l10n.proteinShort,
                        grams: food.macros.protein,
                      ),
                      _MacroChip(
                        color: ForgeColors.carbsColor,
                        label: l10n.carbsShort,
                        grams: food.macros.carbs,
                      ),
                      _MacroChip(
                        color: ForgeColors.fatColor,
                        label: l10n.fatShort,
                        grams: food.macros.fat,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${food.calories} ${l10n.kcal}',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Macro grams for a single food. The letter carries the meaning and the
/// colour only reinforces it — colour alone fails for colourblind trainers.
class _MacroChip extends StatelessWidget {
  final Color color;
  final String label;
  final int grams;

  const _MacroChip({
    required this.color,
    required this.label,
    required this.grams,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ${grams}g',
          style: TextStyle(
            fontFamily: 'Exo 2',
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: colors.onSurface.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}
