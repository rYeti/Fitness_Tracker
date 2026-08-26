import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/console_error.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/active_client_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/trainer_console_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/trainer_licence_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/invite_client_sheet.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/licence_screen.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/licence_banner.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/seat_meter.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/client_avatar.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/console_widgets.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/stat_tile.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/status_badge.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// Trainer's home base: KPI row + client roster (grid/table toggle).
class TrainerDashboardScreen extends StatefulWidget {
  /// Injection seam for tests.
  final TrainerConsoleRepository? repository;

  /// Injection seam for tests. The Dashboard owns a licence provider because
  /// the seat chip, the invite action and the plan banners all read from it.
  final TrainerLicenceProvider? licenceProvider;

  /// Opening a roster row is the shell's job — the Dashboard doesn't own
  /// navigation.
  final ValueChanged<TrainerRosterEntry>? onClientSelected;

  const TrainerDashboardScreen({
    super.key,
    this.repository,
    this.licenceProvider,
    this.onClientSelected,
  });

  @override
  State<TrainerDashboardScreen> createState() => _TrainerDashboardScreenState();
}

class _TrainerDashboardScreenState extends State<TrainerDashboardScreen> {
  late final TrainerConsoleProvider _provider;
  late final TrainerLicenceProvider _licence;
  late final bool _ownsLicenceProvider;

  @override
  void initState() {
    super.initState();
    _provider = TrainerConsoleProvider(repository: widget.repository);
    _provider.load();

    _ownsLicenceProvider = widget.licenceProvider == null;
    _licence = widget.licenceProvider ?? TrainerLicenceProvider();
    _licence.load();
  }

  @override
  void dispose() {
    _provider.dispose();
    if (_ownsLicenceProvider) _licence.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TrainerConsoleProvider>.value(value: _provider),
        ChangeNotifierProvider<TrainerLicenceProvider>.value(value: _licence),
      ],
      child: Consumer3<TrainerConsoleProvider, TrainerLicenceProvider,
          ActiveClientProvider>(
        builder: (context, provider, licence, activeClient, _) {
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
                  licence: licence,
                  activeClient: activeClient,
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
  final TrainerLicenceProvider licence;

  /// The shared client-switcher state, which owns the roster.
  final ActiveClientProvider activeClient;

  final bool isDesktop;
  final ValueChanged<TrainerRosterEntry>? onClientSelected;

  const _Body({
    required this.provider,
    required this.licence,
    required this.activeClient,
    required this.isDesktop,
    required this.onClientSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // No page-level loading gate. There used to be one, covering both the roster and the
    // KPIs, so the fast request waited on the slow one and the page chrome — including the
    // invite button — was hidden from a trainer who had nothing else to do while waiting.
    // Each section below owns its own loading, empty and error states.
    final plan = licence.licence;
    final roster = activeClient.clients;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.consoleNavDashboard,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w800,
                  fontSize: isDesktop ? 26 : 20,
                  letterSpacing: -0.3,
                  color: colors.onSurface,
                ),
              ),
            ),
            if (plan != null)
              SeatChip(
                licence: plan,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LicenceScreen(provider: licence),
                  ),
                ),
              ),
          ],
        ),
        if (plan != null && LicenceBanner.isWarranted(plan)) ...[
          const SizedBox(height: 16),
          LicenceBanner(
            licence: plan,
            onManage: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LicenceScreen(provider: licence),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        // No empty state for the KPI row: zeroes are a real answer, not an absence of one.
        if (provider.kpis != null)
          _KpiRow(kpis: provider.kpis!)
        else if (provider.error != null)
          _KpiErrorStrip(
            message: provider.error!.localizedMessage(l10n),
            onRetry: provider.load,
          )
        else
          SizedBox(
            // ConsoleSkeleton draws a card, so the box has to clear rowHeight plus the
            // card's 16px padding either side plus its 11px bottom gap.
            height: 96,
            child: ConsoleSkeleton(
              rows: 1,
              rowHeight: 48,
              semanticsLabel: l10n.kpisLoading,
            ),
          ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.clientsHeading,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: colors.onSurface,
                ),
              ),
            ),
            _InviteButton(licence: licence),
            if (roster.isNotEmpty) ...[
              const SizedBox(width: 8),
              _LayoutToggle(
                layout: provider.layout,
                onChanged: provider.setLayout,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _RosterSection(
            activeClient: activeClient,
            licence: licence,
            layout: provider.layout,
            isDesktop: isDesktop,
            onClientSelected: onClientSelected,
          ),
        ),
      ],
    );
  }
}

/// A failed KPI load, said in one line instead of the full-height [ConsoleErrorState].
///
/// The KPI row is a strip, not a pane: giving it the tall centred error state would push
/// the roster off a phone screen for the sake of three numbers that failed to load. The
/// roster underneath is the thing the trainer came for and stays visible either way.
class _KpiErrorStrip extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _KpiErrorStrip({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return ConsoleCard(
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: colors.onSurface.withValues(alpha: 0.55),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'Exo 2',
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10n.retry),
            ),
          ),
        ],
      ),
    );
  }
}

/// The roster's four states, independent of whatever the KPI row is doing.
///
/// The skeleton shows only when there is genuinely nothing to draw — the same
/// `isLoading && isEmpty` shape MessagesScreen already uses — so a refresh redraws over
/// the clients already on screen rather than blanking them.
class _RosterSection extends StatelessWidget {
  final ActiveClientProvider activeClient;
  final TrainerLicenceProvider licence;
  final RosterLayout layout;
  final bool isDesktop;
  final ValueChanged<TrainerRosterEntry>? onClientSelected;

  const _RosterSection({
    required this.activeClient,
    required this.licence,
    required this.layout,
    required this.isDesktop,
    required this.onClientSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roster = activeClient.clients;

    if (activeClient.isLoading && roster.isEmpty) {
      return ConsoleSkeleton(semanticsLabel: l10n.rosterLoading);
    }

    if (activeClient.error != null && roster.isEmpty) {
      return ConsoleErrorState(
        message: activeClient.error!.localizedMessage(l10n),
        onRetry: activeClient.loadClients,
      );
    }

    if (roster.isEmpty) {
      return ConsoleEmptyState(
        icon: Icons.group_outlined,
        title: l10n.rosterEmptyTitle,
        message: l10n.rosterEmptyBody,
        action: _InviteButton(licence: licence, prominent: true),
      );
    }

    // The table is dense and needs horizontal room; below the desktop
    // breakpoint it always falls back to cards.
    return (layout == RosterLayout.table && isDesktop)
        ? _RosterTable(roster: roster, onClientSelected: onClientSelected)
        : _RosterGrid(
            roster: roster,
            isDesktop: isDesktop,
            onClientSelected: onClientSelected,
          );
  }
}

/// Opens the invite sheet, or explains why it can't be opened.
///
/// Disabled-with-a-reason rather than hidden: a trainer who has run out of
/// seats needs to find out *why* the invite action isn't working, not wonder
/// where it went.
class _InviteButton extends StatelessWidget {
  final TrainerLicenceProvider licence;
  final bool prominent;

  const _InviteButton({required this.licence, this.prominent = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final plan = licence.licence;
    final reason = switch (plan) {
      null => l10n.licenceLoading,
      final l when l.isReadOnly => l10n.inviteBlockedLapsed,
      final l when l.isFull => l10n.inviteBlockedFull(l.seatLimit),
      _ => null,
    };
    final onPressed = licence.canInvite
        ? () => InviteClientSheet.show(context)
        : null;

    return Tooltip(
      message: reason ?? l10n.inviteAClient,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: prominent
            ? FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: Text(l10n.inviteAClient),
              )
            : OutlinedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: Text(l10n.invite),
              ),
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  final TrainerDashboardKpis kpis;

  const _KpiRow({required this.kpis});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // No "Alerts" tile: TrainerConsoleService never assigns AlertCount, so it
    // is always 0 and would read as "nothing is wrong" — which isn't known.
    // See TrainerDashboardKpis.alertCount.
    final tiles = <Widget>[
      StatTile(
        icon: Icons.group_rounded,
        accentColor: ForgeColors.forgeOrange,
        value: '${kpis.activeClientCount}',
        label: l10n.kpiActiveClients,
      ),
      StatTile(
        icon: Icons.trending_up_rounded,
        accentColor: ForgeColors.statusOk,
        value: '${kpis.avgAdherencePercent.round()}%',
        label: l10n.kpiAvgAdherence,
      ),
      StatTile(
        icon: Icons.fitness_center_rounded,
        accentColor: ForgeColors.carbsColor,
        value: '${kpis.sessionsThisWeek}',
        label: l10n.kpiSessionsThisWeek,
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
    final l10n = AppLocalizations.of(context)!;
    return SegmentedButton<RosterLayout>(
      segments: [
        ButtonSegment(
          value: RosterLayout.grid,
          icon: const Icon(Icons.grid_view_rounded, size: 18),
          tooltip: l10n.rosterGridView,
        ),
        ButtonSegment(
          value: RosterLayout.table,
          icon: const Icon(Icons.table_rows_rounded, size: 18),
          tooltip: l10n.rosterTableView,
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
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
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
                      entry.programLabel ?? l10n.noActivePlan,
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
              adherenceBadge(adherence, l10n),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entry.lastSessionDate == null
                ? l10n.noSessionsYet
                : l10n.lastSessionOn(
                    DateFormat('d MMM', locale).format(entry.lastSessionDate!),
                  ),
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
StatusBadge adherenceBadge(double? percent, AppLocalizations l10n) {
  if (percent == null) {
    return StatusBadge(tone: StatusTone.warn, label: l10n.noData);
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
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
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
                Expanded(
                  flex: 3,
                  child: Text(l10n.rosterColumnClient, style: muted),
                ),
                Expanded(
                  flex: 3,
                  child: Text(l10n.rosterColumnProgram, style: muted),
                ),
                Expanded(
                  flex: 2,
                  child: Text(l10n.rosterColumnAdherence, style: muted),
                ),
                Expanded(
                  flex: 2,
                  child: Text(l10n.rosterColumnLastSession, style: muted),
                ),
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
                            child: adherenceBadge(
                              entry.adherencePercent,
                              l10n,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            entry.lastSessionDate == null
                                ? '—'
                                : DateFormat(
                                    'd MMM',
                                    locale,
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
