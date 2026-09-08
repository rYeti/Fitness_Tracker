import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/core/providers/access_provider.dart';
import 'package:ForgeForm/core/widgets/deload_chip.dart';
import 'package:ForgeForm/feature/premium/paywall_launcher.dart';
import 'package:ForgeForm/feature/workout_planning/domain/deload_schedule.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// The plan's weeks, with the deload ones marked.
///
/// The primary control for the whole feature, and the same widget on both
/// sides — the trainee's plan screen and (later) the Trainer Console's builder.
///
/// Two things are the user's to choose, and neither is inferred:
///
/// - **One week or a cadence.** Tapping a week marks just that week; "repeat
///   every N weeks" is an equally visible action that expands a cadence. A tap
///   never opts you into a cadence, and a cadence never overwrites a week set
///   by hand (`DeloadSchedule.withCadence` merges).
/// - **How much volume**, per week, from the marked week's own sheet.
///
/// See `docs/deload-weeks.md` §4a and §10.
class DeloadWeekStrip extends StatelessWidget {
  const DeloadWeekStrip({
    super.key,
    required this.schedule,
    required this.durationWeeks,
    required this.onChanged,
    this.currentWeek,
    this.assignedByTrainer = false,
  });

  final DeloadSchedule schedule;

  /// How many weeks the plan runs for. A free-choice plan has none and gets a
  /// different control entirely — see [DeloadWeekStrip.freeChoice].
  final int durationWeeks;

  final ValueChanged<DeloadSchedule> onChanged;

  /// The week the user is in now, highlighted. Null when the plan hasn't
  /// started or has finished.
  final int? currentWeek;

  /// A trainer's plan: shown read-only with a reason rather than hidden.
  /// Hiding a control makes a user think the feature doesn't exist; disabling
  /// it with a reason tells them where to ask.
  final bool assignedByTrainer;

  /// Entitlement as read from an event handler.
  ///
  /// `read`, not `watch`: `watch` may only be called during `build`, and
  /// provider throws if a tap handler reaches for it. [build] does its own
  /// `watch` below so the strip still repaints when entitlement changes.
  bool _isLocked(BuildContext context) =>
      !context.read<AccessProvider>().hasPremiumAccess;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locked = !context.watch<AccessProvider>().hasPremiumAccess;
    final readOnly = locked || assignedByTrainer;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.deloadWeeksTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!readOnly)
                  TextButton.icon(
                    onPressed: () => _openCadenceSheet(context),
                    icon: const Icon(Icons.repeat_rounded, size: 18),
                    label: Text(l10n.deloadRepeatAction),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              assignedByTrainer
                  ? l10n.deloadTrainerManaged
                  : l10n.deloadStripHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var week = 1; week <= durationWeeks; week++)
                  _WeekChip(
                    week: week,
                    deload: schedule.forWeek(week),
                    isCurrent: week == currentWeek,
                    locked: locked,
                    readOnly: readOnly,
                    onTap: () => _onWeekTapped(context, week),
                    onLongPress: () => _openVolumeSheet(context, week),
                  ),
              ],
            ),
            if (schedule.isNotEmpty && !readOnly) ...[
              const SizedBox(height: 12),
              Text(
                l10n.deloadVolumeHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _onWeekTapped(BuildContext context, int week) {
    if (assignedByTrainer) return;
    if (_isLocked(context)) {
      openPaywall(context);
      return;
    }
    onChanged(schedule.toggle(week));
  }

  Future<void> _openVolumeSheet(BuildContext context, int week) async {
    if (assignedByTrainer || !schedule.isDeload(week)) return;
    if (_isLocked(context)) {
      openPaywall(context);
      return;
    }

    final current = schedule.forWeek(week)!;
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => _VolumeSheet(week: week, current: current),
    );
    if (picked != null) onChanged(schedule.withVolume(week, picked));
  }

  Future<void> _openCadenceSheet(BuildContext context) async {
    if (_isLocked(context)) {
      openPaywall(context);
      return;
    }

    final everyN = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => const _CadenceSheet(),
    );
    if (everyN == null) return;

    final next = schedule.withCadence(everyN, durationWeeks);
    if (next.weeks.length == schedule.weeks.length) {
      // Either the plan is too short to hold one, or every generated week was
      // already marked. Say so rather than presenting a no-op as success.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.deloadNoRoom(durationWeeks, everyN),
            ),
          ),
        );
      }
      return;
    }
    onChanged(next);
  }
}

class _WeekChip extends StatelessWidget {
  const _WeekChip({
    required this.week,
    required this.deload,
    required this.isCurrent,
    required this.locked,
    required this.readOnly,
    required this.onTap,
    required this.onLongPress,
  });

  final int week;
  final DeloadWeek? deload;
  final bool isCurrent;
  final bool locked;
  final bool readOnly;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDeload = deload != null;
    final accent = DeloadChip.foregroundFor(theme.brightness);

    return Semantics(
      button: !readOnly,
      selected: isDeload,
      label: isDeload
          ? l10n.deloadWeekSemanticWithVolume(week, deload!.volumePercent)
          : l10n.deloadWeekSemantic(week),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        onLongPress: isDeload ? onLongPress : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          // 44x44 minimum tap target (CLAUDE.md accessibility).
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDeload
                ? DeloadChip.backgroundFor(theme.brightness)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: isCurrent
                ? Border.all(color: ForgeColors.forgeOrange, width: 2)
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$week',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDeload ? accent : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (locked) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.lock,
                      size: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
              // The volume is rendered as text, not just a tint, so the marked
              // state never depends on colour alone.
              if (isDeload)
                Text(
                  l10n.deloadPercentShort(deload!.volumePercent),
                  style: theme.textTheme.labelSmall?.copyWith(color: accent),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Per-week volume. Presets are the literature's recovery-need bands, midpoint
/// of each — see `docs/deload-weeks.md` §3a.
class _VolumeSheet extends StatefulWidget {
  const _VolumeSheet({required this.week, required this.current});

  final int week;
  final DeloadWeek current;

  @override
  State<_VolumeSheet> createState() => _VolumeSheetState();
}

class _VolumeSheetState extends State<_VolumeSheet> {
  late int _value = widget.current.volumePercent;

  /// The literature's three recovery-need bands, at the midpoint of each.
  /// See `docs/deload-weeks.md` §3a.
  static const _presets = <int>[65, 50, 30];

  String _presetLabel(AppLocalizations l10n, int percent) => switch (percent) {
    65 => l10n.deloadPresetLow,
    50 => l10n.deloadPresetModerate,
    _ => l10n.deloadPresetHigh,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.deloadVolumeSheetTitle(widget.week),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              // The one ambiguity that would invert the feature, said plainly
              // wherever a user sets the number.
              l10n.deloadVolumeSheetHint(_value),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (final preset in _presets)
              RadioListTile<int>(
                value: preset,
                groupValue: _value,
                onChanged: (v) => setState(() => _value = v!),
                title: Text(l10n.deloadVolumePreset(preset)),
                subtitle: Text(_presetLabel(l10n, preset)),
                contentPadding: EdgeInsets.zero,
              ),
            const SizedBox(height: 8),
            Slider(
              value: _value.toDouble(),
              min: DeloadWeek.minVolumePercent.toDouble(),
              max: DeloadWeek.maxVolumePercent.toDouble(),
              divisions:
                  (DeloadWeek.maxVolumePercent - DeloadWeek.minVolumePercent) ~/
                  5,
              label: l10n.deloadPercentShort(_value),
              onChanged: (v) => setState(() => _value = v.round()),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_value),
                child: Text(l10n.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Repeat every N weeks". Offered, never pre-selected — picking a cadence is
/// as deliberate an act as marking a single week.
class _CadenceSheet extends StatelessWidget {
  const _CadenceSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.deloadCadenceTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.deloadCadenceHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            // 5 first: the survey mean is one deload every 5.6 ± 2.3 weeks.
            for (final n in const [4, 5, 6])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.deloadCadenceEvery(n)),
                onTap: () => Navigator.of(context).pop(n),
              ),
          ],
        ),
      ),
    );
  }
}
