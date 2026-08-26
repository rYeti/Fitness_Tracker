import 'dart:async';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/feature/food_tracking/data/repositories/nutrition_repository.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/view/workouts/active_workout_view.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/stat_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/user_goals_provider.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import '../widgets/dashboard_weight_card.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:ForgeForm/core/widgets/forge_app_bar.dart';

// Global key so other tabs (e.g. Food) can trigger a refresh after mutating
// nutrition data — DashboardScreen is kept alive inside an IndexedStack, so
// switching to its tab does not by itself rebuild it or re-run its queries.
final globalDashboardKey = GlobalKey<_DashboardScreenState>();

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _weekCompleted = 0;
  int _weekTotal = 0;
  int _allTimeCompleted = 0;
  int _todayCalories = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  /// Public so callers outside this widget (via [globalDashboardKey]) can
  /// force a reload, e.g. after a food entry is added/edited/deleted on the
  /// Food tab.
  Future<void> refresh() => _loadDashboardData();

  Future<ScheduledWorkoutWithDetails?> getTodayScheduledWorkout() async {
    final db = context.read<AppDatabase>();
    final results = await db.scheduledWorkoutDao.getScheduledWithDetailsForDate(
      DateTime.now(),
    );
    return results.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final goalsProvider = Provider.of<UserGoalsProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: ForgeAppBar(
        title: l10n.dashboard,
        actions: const [],
      ),
      body: RefreshIndicator(
        color: colorScheme.primary,
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            // The extra bottom padding clears the SpeedDial, which floats
            // over the scroll view rather than displacing it.
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStackGreeting(goalsProvider),
                const SizedBox(height: 8),
                _todayWorkout(),
                const SizedBox(height: 8),
                _buildWeightProgress(goalsProvider),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: SpeedDial(
        animatedIcon: AnimatedIcons.menu_close,
        spacing: 12,
        spaceBetweenChildren: 8,
        overlayOpacity: 0.3,
        overlayColor: Colors.black,
        icon: Icons.add,
        activeIcon: Icons.close,
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.free_breakfast),
            backgroundColor: colorScheme.primary,
            label: l10n.addBreakfast,
            onTap: () async {
              await Navigator.pushNamed(
                context,
                '/add-food',
                arguments: {'category': 'Breakfast'},
              );
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.lunch_dining),
            backgroundColor: colorScheme.primary,
            label: l10n.addLunch,
            onTap: () async {
              await Navigator.pushNamed(
                context,
                '/add-food',
                arguments: {'category': 'Lunch'},
              );
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.dinner_dining),
            backgroundColor: colorScheme.primary,
            label: l10n.addDinner,
            onTap: () async {
              await Navigator.pushNamed(
                context,
                '/add-food',
                arguments: {'category': 'Dinner'},
              );
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.cookie),
            backgroundColor: colorScheme.primary,
            label: l10n.addSnack,
            onTap: () async {
              await Navigator.pushNamed(
                context,
                '/add-food',
                arguments: {'category': 'Snacks'},
              );
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.monitor_weight),
            backgroundColor: colorScheme.primary,
            label: l10n.addWeight,
            onTap: () => Navigator.pushNamed(context, '/weight-tracking'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadDashboardData() async {
    final db = context.read<AppDatabase>();
    final dao = db.scheduledWorkoutDao;

    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    // Counted in SQL and run together: this used to pull every scheduled
    // workout ever recorded and filter three times in Dart, on the first frame.
    final (weekTotal, weekCompleted, allTimeCompleted, todayNutrition) = await (
      dao.countInRange(start: weekStart, end: weekEnd),
      dao.countInRange(start: weekStart, end: weekEnd, completed: true),
      dao.countCompleted(),
      NutritionRepository(db).getNutritionHistoryForToday(),
    ).wait;

    if (mounted) {
      setState(() {
        _weekCompleted = weekCompleted;
        _weekTotal = weekTotal;
        _allTimeCompleted = allTimeCompleted;
        _todayCalories = todayNutrition.firstOrNull?.totalCalories ?? 0;
      });
    }
  }

  String _greeting(AppLocalizations l10n, String name) {
    final hour = DateTime.now().hour;
    final base =
        hour < 12
            ? l10n.goodMorning
            : (hour < 17 ? l10n.goodAfternoon : l10n.goodEvening);
    if (name.trim().isEmpty) return base;
    return base.endsWith('!')
        ? '${base.substring(0, base.length - 1)}, ${name.trim()}!'
        : '$base, ${name.trim()}';
  }

  Widget _buildStackGreeting(UserGoalsProvider goalsProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
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
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(l10n, goalsProvider.name),
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  StatTile(
                    icon: Icons.local_fire_department,
                    value: '$_todayCalories',
                    label: l10n.calories,
                    accentColor: colorScheme.primary,
                  ),
                  StatTile(
                    icon: Icons.fitness_center,
                    value: _weekTotal > 0 ? '$_weekCompleted/$_weekTotal' : '--',
                    label: l10n.workouts,
                    accentColor: colorScheme.onSurface,
                  ),
                  StatTile(
                    icon: Icons.emoji_events,
                    value: '$_allTimeCompleted',
                    label: l10n.allTime,
                    accentColor: colorScheme.onSurface,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildCaloriesProgress(goalsProvider),
            ],
          ),
        ),
        Positioned(
          left: 24,
          top: 0,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: colorScheme.surfaceContainerLow,
                width: 3,
              ),
            ),
            child: CircleAvatar(
              backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
              radius: 24,
              child: Icon(Icons.person, color: colorScheme.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaloriesProgress(UserGoalsProvider goalsProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final progress = _todayCalories / goalsProvider.dailyCalorieGoal;

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
              '$_todayCalories / ${goalsProvider.dailyCalorieGoal.toInt()}',
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
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: colorScheme.onSurface.withValues(alpha: 0.07),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress > 1.0 ? ForgeColors.statusBad : colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeightProgress(UserGoalsProvider goalsProvider) {
    return DashboardWeightCard(
      goalsProvider: goalsProvider,
      onNavigateToWeightTracking:
          () => Navigator.pushNamed(context, '/weight-tracking'),
    );
  }

  Widget _todayWorkout() {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<ScheduledWorkoutWithDetails?>(
      future: getTodayScheduledWorkout(),
      builder: (context, snapshot) {
        final item = snapshot.data;
        final workoutName = item?.workout?.name ?? '';
        final isCompleted = item?.scheduled.isCompleted ?? false;
        final isRestDay = workoutName == 'Rest Day' || workoutName.isEmpty;
        final hasWorkout = item != null && !isRestDay;

        return Material(
          color: Colors.transparent,
          child: InkWell(
          borderRadius: BorderRadius.circular(12.0),
          onTap:
              hasWorkout
                  ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => ActiveWorkoutScreen(
                            scheduledWorkout: item,
                            scheduledDate: item.scheduled.scheduledDate,
                            isReadOnly: isCompleted,
                          ),
                    ),
                  )
                  : null,
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(
                color: colorScheme.onSurface.withValues(alpha: 0.10),
                width: 0.5,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Icon(
                        Icons.fitness_center,
                        color: colorScheme.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.todaysWorkout,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (isCompleted) ...[
                      const Spacer(),
                      Icon(Icons.check_circle, color: colorScheme.tertiary, size: 18),
                    ],
                    if (hasWorkout && !isCompleted) ...[
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                        size: 14,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                if (snapshot.connectionState == ConnectionState.waiting)
                  Center(
                    child: CircularProgressIndicator(
                      color: colorScheme.primary,
                    ),
                  )
                else if (snapshot.hasError)
                  // The message, not the exception. This used to interpolate
                  // snapshot.error straight into the UI, which CLAUDE.md rules
                  // out — a stack trace or a Dio error string is not something
                  // to show a user, and it leaks internals. The detail still
                  // goes to the log where it is useful.
                  Text(
                    l10n.couldNotLoad,
                    style: TextStyle(
                      color: ForgeColors.statusBadFor(
                        Theme.of(context).brightness,
                      ),
                    ),
                  )
                else
                  Text(
                    workoutName.isNotEmpty ? workoutName : l10n.restDay,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color:
                          hasWorkout
                              ? colorScheme.primary
                              : colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }
}
