import 'package:flutter/material.dart';

import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/core/nutrition/extended_nutrients.dart';
import 'package:ForgeForm/core/nutrition/nutrient_defs.dart';
import 'package:ForgeForm/core/widgets/app_widgets.dart';
import 'package:ForgeForm/core/widgets/nutrient_bar_row.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// "Tracked nutrients" — the card both the Trainer Console's Nutrition tab
/// (with a picker, editable) and the trainee's own diary (read-only, showing
/// the coach's picks) render. One widget so a unit, a target, or a tone can
/// never drift between the two surfaces — see
/// `docs/trainer-console-micronutrients.md`.
///
/// Assumes loading is already handled by the caller (same payload as the
/// screen around it); this widget only ever renders locked, nothing-pinned,
/// or populated.
class TrackedNutrientsCard extends StatelessWidget {
  /// True when the caller (trainer or client) lacks a paid, current licence.
  /// When true, [nutrients] and [pinnedKeys] are ignored and an upgrade
  /// prompt renders instead — matching the per-food card's existing gate.
  final bool locked;

  /// Nutrient keys pinned, in order. Empty renders the "nothing pinned" state.
  final List<String> pinnedKeys;

  /// Day (or meal) totals to read pinned values from.
  final ExtendedNutrients nutrients;

  /// Whether a per-meal bar may flag "Low" — only ever true for a whole day.
  final bool dayScope;

  /// Subtitle under the title — callers own the copy since it differs by
  /// audience ("What {name} is prioritising…" vs "What your coach is
  /// tracking…").
  final String subtitle;

  /// Null hides the "Choose" button and the picker entirely — the trainee's
  /// read-only card. Non-null is called with the toggled key.
  final void Function(String key)? onTogglePin;

  const TrackedNutrientsCard({
    super.key,
    required this.locked,
    required this.pinnedKeys,
    required this.nutrients,
    required this.dayScope,
    required this.subtitle,
    this.onTogglePin,
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
                  l10n.trackedNutrients,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: ForgeColors.statusWarnFor(Theme.of(context).brightness),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    l10n.premiumBadge,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l10n.premiumFeatureBody),
          ],
        ),
      );
    }

    final canEdit = onTogglePin != null;

    if (pinnedKeys.isEmpty) {
      return EmptyStateView(
        icon: Icons.insights_outlined,
        title: l10n.trackedNutrients,
        message: canEdit
            ? l10n.trackedNutrientsEmptyTrainer
            : l10n.trackedNutrientsEmptyTrainee,
        inCard: true,
        action: canEdit ? _ChooseButton(onTap: () => _openPicker(context)) : null,
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.trackedNutrients,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: colors.onSurface,
                ),
              ),
              const Spacer(),
              if (canEdit) _ChooseButton(onTap: () => _openPicker(context)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Exo 2',
              fontSize: 12,
              color: colors.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 14),
          for (final key in pinnedKeys)
            if (nutrientDefForKey(key) != null)
              NutrientBarRow(
                def: nutrientDefForKey(key)!,
                nutrients: nutrients,
                dayScope: dayScope,
                pinned: canEdit ? true : null,
                onToggle: canEdit ? () => onTogglePin!(key) : null,
              ),
        ],
      ),
    );
  }

  void _openPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (_) => _NutrientPickerSheet(
        pinnedKeys: pinnedKeys,
        onTogglePin: onTogglePin!,
      ),
    );
  }
}

class _ChooseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ChooseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: l10n.chooseNutrients,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: colors.onSurface.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune, size: 16, color: colors.onSurface.withValues(alpha: 0.65)),
                const SizedBox(width: 5),
                Text(
                  l10n.chooseNutrients,
                  style: TextStyle(
                    fontFamily: 'Exo 2',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Tap to pin the nutrients that matter" — every nutrient as a chip,
/// pinned ones filled orange with a pin glyph, unpinned outlined with an
/// add glyph. Lists all 21 regardless of whether today's food logged any of
/// them: a trainer pins what they want to *start* watching, not only what's
/// already present.
class _NutrientPickerSheet extends StatefulWidget {
  final List<String> pinnedKeys;
  final void Function(String key) onTogglePin;

  const _NutrientPickerSheet({
    required this.pinnedKeys,
    required this.onTogglePin,
  });

  @override
  State<_NutrientPickerSheet> createState() => _NutrientPickerSheetState();
}

class _NutrientPickerSheetState extends State<_NutrientPickerSheet> {
  late Set<String> _pinned = {...widget.pinnedKeys};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.tapToPinNutrients,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final def in nutrientDefs)
                  _NutrientChip(
                    label: def.label(l10n),
                    pinned: _pinned.contains(def.key),
                    onTap: () {
                      setState(() {
                        if (!_pinned.remove(def.key)) _pinned.add(def.key);
                      });
                      widget.onTogglePin(def.key);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NutrientChip extends StatelessWidget {
  final String label;
  final bool pinned;
  final VoidCallback onTap;

  const _NutrientChip({
    required this.label,
    required this.pinned,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: pinned,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: pinned ? ForgeColors.forgeOrange : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: pinned
                  ? null
                  : Border.all(color: colors.onSurface.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  pinned ? Icons.push_pin : Icons.add,
                  size: 15,
                  color: pinned ? Colors.white : colors.onSurface.withValues(alpha: 0.65),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Exo 2',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: pinned ? Colors.white : colors.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
