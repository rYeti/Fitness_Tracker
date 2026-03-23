import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/feature/food_tracking/data/repositories/nutrition_repository.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/view/workouts/active_workout_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/user_goals_provider.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import '../widgets/dashboard_weight_card.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _weekCompleted = 0;
  int _weekTotal = 0;
  int _allTimeCompleted = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

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
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Forge',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: Color(0xFFFF6B3E),
                ),
              ),
              TextSpan(
                text: 'Form',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Provider.of<ThemeProvider>(context).themeMode == ThemeMode.light
                  ? Icons.dark_mode
                  : Icons.light_mode,
              color: Colors.white,
            ),
            onPressed:
                () =>
                    Provider.of<ThemeProvider>(
                      context,
                      listen: false,
                    ).toggleTheme(),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: colorScheme.primary,
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStackGreeting(goalsProvider),
                const SizedBox(height: 16),
                _todayWorkout(),
                const SizedBox(height: 16),
                _buildWeightProgress(goalsProvider),
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
            child: const Icon(Icons.restaurant),
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
            child: const Icon(Icons.restaurant),
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
            child: const Icon(Icons.restaurant),
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
            child: const Icon(Icons.restaurant),
            backgroundColor: colorScheme.primary,
            label: l10n.addSnack,
            onTap: () async {
              await Navigator.pushNamed(
                context,
                '/add-food',
                arguments: {'category': 'Snack'},
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
    final all = await db.scheduledWorkoutDao.getAll();

    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    final thisWeek = all
        .where((sw) =>
            !sw.scheduledDate.isBefore(weekStart) &&
            sw.scheduledDate.isBefore(weekEnd))
        .toList();

    if (mounted) {
      setState(() {
        _weekCompleted = thisWeek.where((sw) => sw.isCompleted).length;
        _weekTotal = thisWeek.length;
        _allTimeCompleted = all.where((sw) => sw.isCompleted).length;
      });
    }
  }

  String _greeting(AppLocalizations l10n, String name) {
    final hour = DateTime.now().hour;
    final base = hour < 12
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
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
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
              const SizedBox(height: 20),
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildQuickStat(
                    Icons.local_fire_department,
                    '--',
                    l10n.calories,
                    colorScheme.primary,
                  ),
                  _buildQuickStat(
                    Icons.fitness_center,
                    _weekTotal > 0 ? '$_weekCompleted/$_weekTotal' : '--',
                    l10n.workouts,
                    colorScheme.onSurface,
                  ),
                  _buildQuickStat(
                    Icons.emoji_events,
                    '$_allTimeCompleted',
                    l10n.allTime,
                    colorScheme.onSurface,
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
    final repository = NutritionRepository(context.read<AppDatabase>());

    return FutureBuilder(
      future: repository.getNutritionHistoryForToday(),
      builder: (context, snapshot) {
        final currentCalories = snapshot.data?.firstOrNull?.totalCalories ?? 0;
        final progress = currentCalories / goalsProvider.dailyCalorieGoal;

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
                  '$currentCalories / ${goalsProvider.dailyCalorieGoal.toInt()}',
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
                  progress > 1.0 ? Colors.red : colorScheme.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWeightProgress(UserGoalsProvider goalsProvider) {
    return DashboardWeightCard(
      goalsProvider: goalsProvider,
      onNavigateToWeightTracking:
          () => Navigator.pushNamed(context, '/weight-tracking'),
    );
  }

  Widget _buildQuickStat(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Exo 2',
            fontSize: 11,
            color: colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
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

        return GestureDetector(
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
                      Icon(Icons.check_circle, color: Colors.green, size: 18),
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
                const SizedBox(height: 14),
                if (snapshot.connectionState == ConnectionState.waiting)
                  Center(
                    child: CircularProgressIndicator(
                      color: colorScheme.primary,
                    ),
                  )
                else if (snapshot.hasError)
                  Text(
                    l10n.errorLoadingWorkout(snapshot.error ?? ''),
                    style: TextStyle(color: Colors.red[400]),
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
        );
      },
    );
  }
}
