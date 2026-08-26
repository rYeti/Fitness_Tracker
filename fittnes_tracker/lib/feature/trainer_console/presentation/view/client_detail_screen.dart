import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/client_detail_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/client_avatar.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/console_widgets.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/macro_summary.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/stat_tile.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/console_error.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// Deep dive on one client: adherence, weight trend, attendance, strength
/// progression, and today's macros.
///
/// Takes an explicit [clientId] rather than reading ActiveClientProvider —
/// this screen is reached by tapping a specific roster row, and shouldn't
/// change under the trainer if they switch the active client elsewhere.
class ClientDetailScreen extends StatefulWidget {
  final String clientId;
  final String clientName;

  /// Injection seam for tests.
  final TrainerConsoleRepository? repository;

  const ClientDetailScreen({
    super.key,
    required this.clientId,
    required this.clientName,
    this.repository,
  });

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  late final ClientDetailProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = ClientDetailProvider(
      clientId: widget.clientId,
      repository: widget.repository,
    );
    _provider.load();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  String get _initials {
    final parts = widget.clientName
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ChangeNotifierProvider<ClientDetailProvider>.value(
      value: _provider,
      child: Consumer<ClientDetailProvider>(
        builder: (context, provider, _) {
          final isDesktop = Breakpoints.isDesktop(context);

          return Scaffold(
            backgroundColor: colors.surfaceContainerLowest,
            appBar: AppBar(
              title: Row(
                children: [
                  ClientAvatar(
                    initials: _initials,
                    clientId: widget.clientId,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      widget.clientName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(isDesktop ? 32 : 16),
                child: _Body(provider: provider, isDesktop: isDesktop),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final ClientDetailProvider provider;
  final bool isDesktop;

  const _Body({required this.provider, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (provider.isLoading && !provider.hasAnyData) {
      return ConsoleSkeleton(semanticsLabel: l10n.clientDetailLoading);
    }
    // Only when nothing at all came back. The three sections load independently, so one
    // failing endpoint costs its own card and leaves the rest of the client's picture up.
    if (provider.error != null && !provider.hasAnyData) {
      return ConsoleErrorState(
        message: provider.error!.localizedMessage(l10n),
        onRetry: provider.load,
      );
    }

    final summary = provider.workoutSummary;
    final cards = <Widget>[
      _StatsRow(provider: provider),
      if (summary?.currentPlan != null) _PlanCard(plan: summary!.currentPlan!),
      _WeightCard(history: provider.weightHistory, delta: provider.weightDelta),
      _AttendanceCard(weeks: summary?.attendance ?? const []),
      _StrengthCard(progression: summary?.strengthProgression ?? const []),
      if (provider.nutrition != null) _MacrosCard(nutrition: provider.nutrition!),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final card in cards) ...[
            card,
            if (card != cards.last) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final ClientDetailProvider provider;

  const _StatsRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final adherence = provider.overallAdherence;
    final delta = provider.weightDelta;
    final latest = provider.weightHistory.isEmpty
        ? null
        : provider.weightHistory.last.weight;

    final tiles = <Widget>[
      StatTile(
        icon: Icons.trending_up_rounded,
        accentColor: ForgeColors.statusOk,
        value: adherence == null ? '—' : '${adherence.round()}%',
        label: l10n.adherence28d,
      ),
      StatTile(
        icon: Icons.monitor_weight_outlined,
        accentColor: ForgeColors.carbsColor,
        value: latest == null ? '—' : '${_trim(latest)} kg',
        label: l10n.clientCurrentWeight,
      ),
      StatTile(
        icon: delta != null && delta < 0
            ? Icons.south_rounded
            : Icons.north_rounded,
        accentColor: ForgeColors.forgeOrange,
        value: delta == null ? '—' : '${delta > 0 ? '+' : ''}${_trim(delta)} kg',
        label: l10n.change,
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

  static String _trim(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);
}

class _PlanCard extends StatelessWidget {
  final WorkoutPlanSummary plan;

  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ConsoleCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ForgeColors.forgeOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.assignment_outlined,
              size: 20,
              color: ForgeColors.forgeOrange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  style: TextStyle(
                    fontFamily: 'Exo 2',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  AppLocalizations.of(context)!.planStartedOn(
                    DateFormat(
                      'd MMM yyyy',
                      Localizations.localeOf(context).toString(),
                    ).format(plan.startDate),
                  ),
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
    );
  }
}

/// Weight trend as a simple polyline. Deliberately not fl_chart: this is a
/// glanceable sparkline in a summary card, not an interactive chart.
class _WeightCard extends StatelessWidget {
  final List<ClientWeightEntry> history;
  final double? delta;

  const _WeightCard({required this.history, required this.delta});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    if (history.length < 2) {
      return ConsoleEmptyState(
        icon: Icons.show_chart_rounded,
        title: l10n.weightTrendEmptyTitle,
        message: l10n.weightTrendEmptyBody,
        inCard: true,
      );
    }

    return ConsoleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConsoleSectionTitle(
            title: l10n.weightTrend,
            trailing: Text(
              l10n.entryCount(history.length),
              style: TextStyle(
                fontFamily: 'Exo 2',
                fontSize: 11.5,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
          SizedBox(
            height: 120,
            child: Semantics(
              label: l10n.weightTrendSemantics(
                '${history.first.weight}',
                '${history.last.weight}',
              ),
              child: CustomPaint(
                painter: _SparklinePainter(
                  values: history.map((e) => e.weight).toList(),
                  color: ForgeColors.forgeOrange,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _AxisLabel(
                DateFormat('d MMM', locale).format(history.first.date),
              ),
              _AxisLabel(
                DateFormat('d MMM', locale).format(history.last.date),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AxisLabel extends StatelessWidget {
  final String text;

  const _AxisLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontFamily: 'Exo 2',
      fontSize: 10.5,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
    ),
  );
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    // A flat series would divide by zero; pin it to the middle instead.
    final range = (max - min).abs() < 0.001 ? 1.0 : max - min;

    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          size.width * (i / (values.length - 1)),
          size.height - ((values[i] - min) / range) * size.height,
        ),
    ];

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, line);

    // Fade under the line so the direction reads at a glance.
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
      ).createShader(Offset.zero & size);
    final area = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(area, fill);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color;
}

class _AttendanceCard extends StatelessWidget {
  final List<AttendanceWeek> weeks;

  const _AttendanceCard({required this.weeks});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();

    if (weeks.isEmpty) {
      return ConsoleEmptyState(
        icon: Icons.calendar_month_outlined,
        title: l10n.attendanceEmptyTitle,
        message: l10n.attendanceEmptyBody,
        inCard: true,
      );
    }

    // The endpoint returns newest-first; a calendar reads oldest-to-newest.
    final ordered = [...weeks]
      ..sort((a, b) => a.weekStart.compareTo(b.weekStart));

    return ConsoleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConsoleSectionTitle(title: l10n.attendanceByWeek),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final week in ordered)
                  Expanded(
                    child: Semantics(
                      label: l10n.attendanceWeekSemantics(
                        DateFormat('d MMM', locale).format(week.weekStart),
                        week.completedSessions,
                        week.plannedSessions,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) => Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    height: week.plannedSessions == 0
                                        ? 2
                                        : (constraints.maxHeight * week.ratio)
                                              .clamp(2.0, constraints.maxHeight),
                                    decoration: BoxDecoration(
                                      color: week.plannedSessions == 0
                                          ? colors.onSurface.withValues(
                                              alpha: 0.12,
                                            )
                                          : ForgeColors.forgeOrange.withValues(
                                              alpha: 0.35 + week.ratio * 0.65,
                                            ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat('d/M', locale).format(week.weekStart),
                              style: TextStyle(
                                fontFamily: 'Exo 2',
                                fontSize: 8.5,
                                color: colors.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StrengthCard extends StatelessWidget {
  final List<StrengthProgression> progression;

  const _StrengthCard({required this.progression});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    if (progression.isEmpty) {
      return ConsoleEmptyState(
        icon: Icons.fitness_center_outlined,
        title: l10n.strengthEmptyTitle,
        message: l10n.strengthEmptyBody,
        inCard: true,
      );
    }

    // Biggest movers first — that's what a trainer scans for.
    final ordered = [...progression]
      ..sort((a, b) => b.deltaFromPrevious.abs().compareTo(
            a.deltaFromPrevious.abs(),
          ));

    return ConsoleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConsoleSectionTitle(title: l10n.strengthProgression),
          for (final item in ordered.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.exerciseName.isEmpty
                          ? l10n.exercise
                          : item.exerciseName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Exo 2',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    '${_trim(item.bestWeight)} kg',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _DeltaChip(delta: item.deltaFromPrevious),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _trim(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);
}

class _DeltaChip extends StatelessWidget {
  final double delta;

  const _DeltaChip({required this.delta});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final flat = delta.abs() < 0.001;
    final color = flat
        ? colors.onSurface.withValues(alpha: 0.45)
        : delta > 0
        ? ForgeColors.statusOk
        : ForgeColors.statusBad;

    return SizedBox(
      width: 62,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(
            flat
                ? Icons.remove_rounded
                : delta > 0
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            flat ? '—' : delta.abs().toStringAsFixed(1),
            style: TextStyle(
              fontFamily: 'Exo 2',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MacrosCard extends StatelessWidget {
  final ClientNutritionSummary nutrition;

  const _MacrosCard({required this.nutrition});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return ConsoleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConsoleSectionTitle(
            title: l10n.todaysMacros,
            trailing: Text(
              l10n.caloriesOfGoal(
                nutrition.totalCalories,
                nutrition.calorieGoal,
              ),
              style: TextStyle(
                fontFamily: 'Exo 2',
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: colors.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ),
          MacroSummary(
            protein: nutrition.macros.protein,
            carbs: nutrition.macros.carbs,
            fat: nutrition.macros.fat,
            calorieGoal: nutrition.calorieGoal,
          ),
        ],
      ),
    );
  }
}
