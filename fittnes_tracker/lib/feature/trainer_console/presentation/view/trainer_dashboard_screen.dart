import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/trainer_console_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/client_avatar.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/console_widgets.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/stat_tile.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/status_badge.dart';

/// Trainer's home base: KPI row + client roster (grid/table toggle).
class TrainerDashboardScreen extends StatefulWidget {
  /// Injection seam for tests.
  final TrainerConsoleRepository? repository;

  /// Opening a roster row is the shell's job — the Dashboard doesn't own
  /// navigation.
  final ValueChanged<TrainerRosterEntry>? onClientSelected;

  const TrainerDashboardScreen({
    super.key,
    this.repository,
    this.onClientSelected,
  });

  @override
  State<TrainerDashboardScreen> createState() => _TrainerDashboardScreenState();
}

class _TrainerDashboardScreenState extends State<TrainerDashboardScreen> {
  late final TrainerConsoleProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = TrainerConsoleProvider(repository: widget.repository);
    _provider.load();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TrainerConsoleProvider>.value(
      value: _provider,
      child: Consumer<TrainerConsoleProvider>(
        builder: (context, provider, _) {
          final isDesktop = MediaQuery.of(context).size.width > 1024;
          final padding = isDesktop ? 32.0 : 16.0;

          return Scaffold(
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerLowest,
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: _Body(
                  provider: provider,
                  isDesktop: isDesktop,
                  onClientSelected: widget.onClientSelected,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final TrainerConsoleProvider provider;
  final bool isDesktop;
  final ValueChanged<TrainerRosterEntry>? onClientSelected;

  const _Body({
    required this.provider,
    required this.isDesktop,
    required this.onClientSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (provider.isLoading) {
      return const ConsoleSkeleton(semanticsLabel: 'Loading dashboard');
    }
    if (provider.error != null) {
      return ConsoleErrorState(message: provider.error!, onRetry: provider.load);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w800,
            fontSize: isDesktop ? 26 : 20,
            letterSpacing: -0.3,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 20),
        if (provider.kpis != null) _KpiRow(kpis: provider.kpis!),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Clients',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: colors.onSurface,
                ),
              ),
            ),
            if (provider.roster.isNotEmpty)
              _LayoutToggle(
                layout: provider.layout,
                onChanged: provider.setLayout,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: provider.roster.isEmpty
              ? const ConsoleEmptyState(
                  icon: Icons.group_outlined,
                  title: 'No clients yet',
                  message: 'Invite your first client to get started.',
                )
              // The table is dense and needs horizontal room; below the
              // desktop breakpoint it always falls back to cards.
              : (provider.layout == RosterLayout.table && isDesktop)
                  ? _RosterTable(
                      roster: provider.roster,
                      onClientSelected: onClientSelected,
                    )
                  : _RosterGrid(
                      roster: provider.roster,
                      isDesktop: isDesktop,
                      onClientSelected: onClientSelected,
                    ),
        ),
      ],
    );
  }
}

class _KpiRow extends StatelessWidget {
  final TrainerDashboardKpis kpis;

  const _KpiRow({required this.kpis});

  @override
  Widget build(BuildContext context) {
    // No "Alerts" tile: TrainerConsoleService never assigns AlertCount, so it
    // is always 0 and would read as "nothing is wrong" — which isn't known.
    // See TrainerDashboardKpis.alertCount.
    final tiles = <Widget>[
      StatTile(
        icon: Icons.group_rounded,
        accentColor: ForgeColors.forgeOrange,
        value: '${kpis.activeClientCount}',
        label: 'Active clients',
      ),
      StatTile(
        icon: Icons.trending_up_rounded,
        accentColor: ForgeColors.statusOk,
        value: '${kpis.avgAdherencePercent.round()}%',
        label: 'Avg adherence',
      ),
      StatTile(
        icon: Icons.fitness_center_rounded,
        accentColor: ForgeColors.carbsColor,
        value: '${kpis.sessionsThisWeek}',
        label: 'Sessions this week',
      ),
    ];

    return Row(
      children: [
        for (final tile in tiles) ...[
          Expanded(child: ConsoleCard(child: tile)),
          if (tile != tiles.last) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _LayoutToggle extends StatelessWidget {
  final RosterLayout layout;
  final ValueChanged<RosterLayout> onChanged;

  const _LayoutToggle({required this.layout, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<RosterLayout>(
      segments: const [
        ButtonSegment(
          value: RosterLayout.grid,
          icon: Icon(Icons.grid_view_rounded, size: 18),
          tooltip: 'Grid view',
        ),
        ButtonSegment(
          value: RosterLayout.table,
          icon: Icon(Icons.table_rows_rounded, size: 18),
          tooltip: 'Table view',
        ),
      ],
      selected: {layout},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _RosterGrid extends StatelessWidget {
  final List<TrainerRosterEntry> roster;
  final bool isDesktop;
  final ValueChanged<TrainerRosterEntry>? onClientSelected;

  const _RosterGrid({
    required this.roster,
    required this.isDesktop,
    required this.onClientSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Target ~280px cards, so the column count follows available width
        // instead of a hardcoded breakpoint table.
        final columns = (constraints.maxWidth / 280).floor().clamp(1, 4);
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 132,
          ),
          itemCount: roster.length,
          itemBuilder: (context, index) => _RosterCard(
            entry: roster[index],
            onTap: onClientSelected == null
                ? null
                : () => onClientSelected!(roster[index]),
          ),
        );
      },
    );
  }
}

class _RosterCard extends StatelessWidget {
  final TrainerRosterEntry entry;
  final VoidCallback? onTap;

  const _RosterCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final adherence = entry.adherencePercent;

    return ConsoleCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClientAvatar(
                initials: entry.initials,
                clientId: entry.clientId,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Exo 2',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: colors.onSurface,
                      ),
                    ),
                    Text(
                      entry.programLabel ?? 'No active plan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Exo 2',
                        fontSize: 11.5,
                        color: colors.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(child: _AdherenceBar(percent: adherence)),
              const SizedBox(width: 10),
              adherenceBadge(adherence),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entry.lastSessionDate == null
                ? 'No sessions yet'
                : 'Last: ${DateFormat('d MMM').format(entry.lastSessionDate!)}',
            style: TextStyle(
              fontFamily: 'Exo 2',
              fontSize: 11,
              color: colors.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

/// Adherence banding, shared by the card and table so the two can't disagree.
/// Null means no sessions were scheduled — reported as "No data", not 0%.
StatusBadge adherenceBadge(double? percent) {
  if (percent == null) {
    return const StatusBadge(tone: StatusTone.warn, label: 'No data');
  }
  final rounded = percent.round();
  if (rounded >= 80) {
    return StatusBadge(tone: StatusTone.ok, label: '$rounded%');
  }
  if (rounded >= 50) {
    return StatusBadge(tone: StatusTone.warn, label: '$rounded%');
  }
  return StatusBadge(tone: StatusTone.bad, label: '$rounded%');
}

class _AdherenceBar extends StatelessWidget {
  final double? percent;

  const _AdherenceBar({required this.percent});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final value = (percent ?? 0) / 100;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 6,
        backgroundColor: colors.onSurface.withValues(alpha: 0.08),
        valueColor: AlwaysStoppedAnimation(
          percent == null
              ? Colors.transparent
              : ForgeColors.forgeOrange,
        ),
      ),
    );
  }
}

class _RosterTable extends StatelessWidget {
  final List<TrainerRosterEntry> roster;
  final ValueChanged<TrainerRosterEntry>? onClientSelected;

  const _RosterTable({required this.roster, required this.onClientSelected});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final muted = TextStyle(
      fontFamily: 'Exo 2',
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      color: colors.onSurface.withValues(alpha: 0.55),
    );

    return ConsoleCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('CLIENT', style: muted)),
                Expanded(flex: 3, child: Text('PROGRAM', style: muted)),
                Expanded(flex: 2, child: Text('ADHERENCE', style: muted)),
                Expanded(flex: 2, child: Text('LAST SESSION', style: muted)),
              ],
            ),
          ),
          Divider(height: 1, color: colors.onSurface.withValues(alpha: 0.08)),
          Expanded(
            child: ListView.separated(
              itemCount: roster.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: colors.onSurface.withValues(alpha: 0.08),
              ),
              itemBuilder: (context, index) {
                final entry = roster[index];
                return InkWell(
                  onTap: onClientSelected == null
                      ? null
                      : () => onClientSelected!(entry),
                  child: Container(
                    // 32px is the accepted minimum for dense desktop tables
                    // (CLAUDE.md tap targets).
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              ClientAvatar(
                                initials: entry.initials,
                                clientId: entry.clientId,
                                size: 28,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  entry.clientName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Exo 2',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: colors.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            entry.programLabel ?? '—',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Exo 2',
                              fontSize: 12.5,
                              color: colors.onSurface.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: adherenceBadge(entry.adherencePercent),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            entry.lastSessionDate == null
                                ? '—'
                                : DateFormat(
                                    'd MMM',
                                  ).format(entry.lastSessionDate!),
                            style: TextStyle(
                              fontFamily: 'Exo 2',
                              fontSize: 12.5,
                              color: colors.onSurface.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
