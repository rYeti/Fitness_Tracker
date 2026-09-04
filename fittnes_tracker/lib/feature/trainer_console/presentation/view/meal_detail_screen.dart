import 'package:flutter/material.dart';

import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/core/nutrition/extended_nutrients.dart';
import 'package:ForgeForm/core/nutrition/nutrient_defs.dart';
import 'package:ForgeForm/core/widgets/app_widgets.dart';
import 'package:ForgeForm/core/widgets/forge_app_bar.dart';
import 'package:ForgeForm/core/widgets/nutrient_bar_row.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// Everything a trainer sees about one logged meal: totals, a per-item
/// breakdown carrying the nutrients they've pinned as chips, and a full
/// micronutrient rail for the whole meal where tapping a row pins it.
///
/// Pushed — not a bottom sheet — because it doesn't fit one: a per-item
/// breakdown plus a complete 21-row nutrient rail needs its own scroll
/// region, not a sheet stacked over the Nutrition tab. See
/// `docs/trainer-console-micronutrients.md`. Replaces the old
/// `MealDetailSheet`.
class MealDetailScreen extends StatelessWidget {
  final LoggedMeal meal;

  /// Already localized by the caller, which owns the category-slug mapping.
  final String mealLabel;

  final IconData icon;
  final String clientName;
  final bool micronutrientsLocked;
  final List<String> pinnedNutrients;

  /// Null when locked — there's nothing pinnable to show, so the row's tap
  /// target is simply not wired up.
  final void Function(String nutrientKey)? onTogglePin;

  const MealDetailScreen({
    super.key,
    required this.meal,
    required this.mealLabel,
    required this.icon,
    required this.clientName,
    required this.micronutrientsLocked,
    required this.pinnedNutrients,
    this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final body = meal.foods.isEmpty
        ? _EmptyMeal(mealLabel: mealLabel)
        : _Populated(
            meal: meal,
            mealLabel: mealLabel,
            icon: icon,
            clientName: clientName,
            micronutrientsLocked: micronutrientsLocked,
            pinnedNutrients: pinnedNutrients,
            onTogglePin: onTogglePin,
            isDesktop: isDesktop,
          );

    return Scaffold(
      appBar: ForgeAppBar(title: mealLabel),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? 32 : 16),
          child: body,
        ),
      ),
    );
  }
}

class _EmptyMeal extends StatelessWidget {
  final String mealLabel;

  const _EmptyMeal({required this.mealLabel});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EmptyStateView(
      icon: Icons.no_meals_outlined,
      title: mealLabel,
      message: l10n.noFoodLogged,
    );
  }
}

class _Populated extends StatelessWidget {
  final LoggedMeal meal;
  final String mealLabel;
  final IconData icon;
  final String clientName;
  final bool micronutrientsLocked;
  final List<String> pinnedNutrients;
  final void Function(String nutrientKey)? onTogglePin;
  final bool isDesktop;

  const _Populated({
    required this.meal,
    required this.mealLabel,
    required this.icon,
    required this.clientName,
    required this.micronutrientsLocked,
    required this.pinnedNutrients,
    required this.onTogglePin,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final header = _MealHeader(meal: meal, mealLabel: mealLabel, icon: icon);
    final mealTotalCard = _MealTotalCard(meal: meal);
    final breakdownCard = _BreakdownCard(meal: meal, pinnedNutrients: pinnedNutrients);
    final micronutrientsCard = _MicronutrientsCard(
      meal: meal,
      locked: micronutrientsLocked,
      pinnedNutrients: pinnedNutrients,
      onTogglePin: onTogglePin,
    );

    if (isDesktop) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      mealTotalCard,
                      const SizedBox(height: 16),
                      breakdownCard,
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                SizedBox(width: 340, child: micronutrientsCard),
              ],
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 14),
          mealTotalCard,
          const SizedBox(height: 14),
          breakdownCard,
          const SizedBox(height: 14),
          micronutrientsCard,
        ],
      ),
    );
  }
}

class _MealHeader extends StatelessWidget {
  final LoggedMeal meal;
  final String mealLabel;
  final IconData icon;

  const _MealHeader({required this.meal, required this.mealLabel, required this.icon});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
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
                  fontSize: 12,
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

class _MealTotalCard extends StatelessWidget {
  final LoggedMeal meal;

  const _MealTotalCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.mealTotal,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.foodCount(meal.foods.length),
                style: TextStyle(
                  fontFamily: 'Exo 2',
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _MacroStatBox(value: '${meal.calories}', label: l10n.kcal.toUpperCase())),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroStatBox(
                  value: '${meal.macros.protein}',
                  label: l10n.proteinShort,
                  color: ForgeColors.proteinColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroStatBox(
                  value: '${meal.macros.carbs}',
                  label: l10n.carbsShort,
                  color: ForgeColors.carbsColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroStatBox(
                  value: '${meal.macros.fat}',
                  label: l10n.fatShort,
                  color: ForgeColors.fatColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroStatBox extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;

  const _MacroStatBox({required this.value, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: color ?? colors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Exo 2',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colors.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final LoggedMeal meal;
  final List<String> pinnedNutrients;

  const _BreakdownCard({required this.meal, required this.pinnedNutrients});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: l10n.foods),
          for (final food in meal.foods) ...[
            _FoodRow(food: food, pinnedNutrients: pinnedNutrients),
            if (food != meal.foods.last)
              Divider(height: 1, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
          ],
        ],
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  final LoggedFood food;
  final List<String> pinnedNutrients;

  const _FoodRow({required this.food, required this.pinnedNutrients});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final nutrients = food.micronutrients;

    final pins = <Widget>[];
    if (nutrients != null) {
      for (final key in pinnedNutrients) {
        final def = nutrientDefForKey(key);
        if (def == null) continue;
        final value = def.displayValue(nutrients);
        if (value == null) continue;
        pins.add(_PinChip(label: def.label(l10n), valueText: NutrientBarRow.formatValue(value, def.displayUnit(l10n))));
      }
    }

    final semanticsLabel = food.grams > 0
        ? l10n.foodRowSemantics(
            food.name, food.grams, food.calories,
            food.macros.protein, food.macros.carbs, food.macros.fat)
        : l10n.foodRowSemanticsNoWeight(
            food.name, food.calories,
            food.macros.protein, food.macros.carbs, food.macros.fat);

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
                    style: TextStyle(fontFamily: 'Exo 2', fontWeight: FontWeight.w600, fontSize: 14, color: colors.onSurface),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${food.grams > 0 ? '${l10n.gramsShort(food.grams)} · ' : ''}'
                    '${food.calories} ${l10n.kcal} · ${l10n.proteinShort} ${food.macros.protein}g · '
                    '${l10n.carbsShort} ${food.macros.carbs}g · ${l10n.fatShort} ${food.macros.fat}g',
                    style: TextStyle(fontFamily: 'Exo 2', fontSize: 12, color: colors.onSurface.withValues(alpha: 0.6)),
                  ),
                  if (pins.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 7, runSpacing: 7, children: pins),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinChip extends StatelessWidget {
  final String label;
  final String valueText;

  const _PinChip({required this.label, required this.valueText});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text.rich(
        TextSpan(
          style: TextStyle(fontFamily: 'Exo 2', fontSize: 11, color: colors.onSurface.withValues(alpha: 0.75)),
          children: [
            TextSpan(text: '$label '),
            TextSpan(text: valueText, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _MicronutrientsCard extends StatelessWidget {
  final LoggedMeal meal;
  final bool locked;
  final List<String> pinnedNutrients;
  final void Function(String nutrientKey)? onTogglePin;

  const _MicronutrientsCard({
    required this.meal,
    required this.locked,
    required this.pinnedNutrients,
    required this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    if (locked) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.micronutrients,
                  style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w700, fontSize: 15, color: colors.onSurface),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: ForgeColors.statusWarnFor(Theme.of(context).brightness),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(l10n.premiumBadge, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l10n.premiumFeatureBody),
          ],
        ),
      );
    }

    final nutrients = meal.micronutrients ?? ExtendedNutrients.empty;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.micronutrients,
            style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w700, fontSize: 15, color: colors.onSurface),
          ),
          const SizedBox(height: 3),
          Text(
            l10n.micronutrientsMealCaption,
            style: TextStyle(fontFamily: 'Exo 2', fontSize: 12, color: colors.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 12),
          for (final def in nutrientDefs)
            NutrientBarRow(
              def: def,
              nutrients: nutrients,
              dayScope: false,
              pinned: pinnedNutrients.contains(def.key),
              onToggle: onTogglePin == null ? null : () => onTogglePin!(def.key),
            ),
        ],
      ),
    );
  }
}
