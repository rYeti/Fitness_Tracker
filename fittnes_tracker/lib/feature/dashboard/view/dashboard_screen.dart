import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/core/forge_motion.dart';
import 'package:ForgeForm/feature/food_tracking/data/repositories/nutrition_repository.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/view/workouts/active_workout_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/user_goals_provider.dart';
import '../widgets/dashboard_weight_card.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:ForgeForm/core/widgets/forge_app_bar.dart';
import 'package:ForgeForm/feature/dashboard/widgets/greeting_card.dart';
import 'package:ForgeForm/core/widgets/content_pane.dart';
import 'package:ForgeForm/feature/food_tracking/presentation/view/food_tracking_screen.dart';
import 'package:ForgeForm/feature/progress_dashboard_view.dart';
import 'package:go_router/go_router.dart';

// Global key so other tabs (e.g. Food) can trigger a refresh after mutating
// nutrition data — DashboardScreen is kept alive inside an IndexedStack, so
// switching to its tab does not by itself rebuild it or re-run its queries.
final globalDashboardKey = GlobalKey<_DashboardScreenState>();

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _weekCompleted = 0;
  int _weekTotal = 0;
  int _allTimeCompleted = 0;
  int _todayCalories = 0;

  // The FAB used package:flutter_speed_dial, which renders its children and
  // scrim through a separately-inserted OverlayEntry rather than as part of
  // this screen's own widget tree. Pushing a route from a child's onTap races
  // that overlay's own close animation, and losing the race leaves its
  // full-screen barrier stuck on top of whatever got navigated to, absorbing
  // every tap — a known, unfixed bug in the package (upstream issue #327),
  // not something fixable from here with the right delay. This local
  // Column-based expando avoids the problem structurally: its "children" are
  // ordinary widgets in this route's own subtree, so pushing a new route
  // covers and hit-test-shadows them exactly like it would any other widget
  // on this screen, with no separate overlay lifecycle to leak.
  bool _quickAddOpen = false;
  late final AnimationController _quickAddController = AnimationController(
    duration: ForgeMotion.standard,
    vsync: this,
  );
  late final Animation<double> _quickAddScale = CurvedAnimation(
    parent: _quickAddController,
    curve: ForgeMotion.curve,
  );

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // AnimationController is built in initState, before MediaQuery exists, so
    // the reduce-motion setting can only be applied once dependencies resolve.
    _quickAddController.duration = ForgeMotion.of(context);
  }

  @override
  void dispose() {
    _quickAddController.dispose();
    super.dispose();
  }

  void _toggleQuickAdd() {
    setState(() {
      _quickAddOpen = !_quickAddOpen;
      if (_quickAddOpen) {
        _quickAddController.forward();
      } else {
        _quickAddController.reverse();
      }
    });
  }

  // The Food tab only reloads its own data when something mutates food from
  // inside it (see food_tracking_screen.dart's _refreshDashboard, which is
  // the mirror of this). Adding food from this FAB instead pushes '/add-food'
  // directly, so nothing ever told the Food (or Progress) tab to re-read —
  // they kept showing pre-add data until the user manually refreshed them.
  Future<void> _addFood(String category) async {
    _toggleQuickAdd();
    await context.push('/add-food', extra: {'category': category});
    if (!mounted) return;
    globalFoodTrackingKey.currentState?.loadNutritionData();
    globalProgressKey.currentState?.reloadNutritionData();
    _loadDashboardData();
  }

  Future<void> _addWeight() async {
    _toggleQuickAdd();
    await context.push('/weight-tracking');
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
          child: ContentPane(
            child: Padding(
              // The extra bottom padding clears the quick-add FAB, which
              // floats over the scroll view rather than displacing it.
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GreetingCard(
                    name: goalsProvider.name,
                    todayCalories: _todayCalories,
                    calorieGoal: goalsProvider.dailyCalorieGoal,
                    weekCompleted: _weekCompleted,
                    weekTotal: _weekTotal,
                    allTimeCompleted: _allTimeCompleted,
                  ),
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
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_quickAddOpen) ...[
            _quickAddOption(
              icon: Icons.monitor_weight,
              label: l10n.addWeight,
              onTap: _addWeight,
            ),
            const SizedBox(height: 12),
            _quickAddOption(
              icon: Icons.cookie,
              label: l10n.addSnack,
              onTap: () => _addFood('Snacks'),
            ),
            const SizedBox(height: 12),
            _quickAddOption(
              icon: Icons.dinner_dining,
              label: l10n.addDinner,
              onTap: () => _addFood('Dinner'),
            ),
            const SizedBox(height: 12),
            _quickAddOption(
              icon: Icons.lunch_dining,
              label: l10n.addLunch,
              onTap: () => _addFood('Lunch'),
            ),
            const SizedBox(height: 12),
            _quickAddOption(
              icon: Icons.free_breakfast,
              label: l10n.addBreakfast,
              onTap: () => _addFood('Breakfast'),
            ),
            const SizedBox(height: 12),
          ],
          // The one control on this screen a screen reader could not name. It
          // is also the only way to log anything from here, so "button" was
          // the whole announcement for the screen's primary action.
          FloatingActionButton(
            onPressed: _toggleQuickAdd,
            tooltip: _quickAddOpen ? l10n.close : l10n.quickAdd,
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            child: AnimatedRotation(
              turns: _quickAddOpen ? 0.125 : 0,
              duration: ForgeMotion.of(context),
              curve: ForgeMotion.curve,
              child: Icon(_quickAddOpen ? Icons.close : Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAddOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ScaleTransition(
      scale: _quickAddScale,
      alignment: Alignment.bottomRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(8),
            color: colorScheme.primary.withValues(alpha: 0.9),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Material(
            elevation: 4,
            shape: const CircleBorder(),
            color: colorScheme.primary,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Semantics(
                button: true,
                label: label,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(child: Icon(icon, color: Colors.white)),
                ),
              ),
            ),
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

  Widget _buildWeightProgress(UserGoalsProvider goalsProvider) {
    return DashboardWeightCard(
      goalsProvider: goalsProvider,
      onNavigateToWeightTracking: () => context.push('/weight-tracking'),
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
