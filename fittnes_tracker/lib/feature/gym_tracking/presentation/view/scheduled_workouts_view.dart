import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/di/service_locator.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/providers/workout_provider.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/view/workouts/create_view.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/view/workouts/workouts_list_view.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/view/exercises/exercise_management_screen.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout_plan.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/scheduled_workout_provider.dart'; // Import the new ActiveWorkoutScreen
import '../view/workouts/active_workout_view.dart';

class ScheduledWorkoutsView extends StatefulWidget {
  const ScheduledWorkoutsView({super.key});
  @override
  State<ScheduledWorkoutsView> createState() => _ScheduledWorkoutsViewState();
}

class _ScheduledWorkoutsViewState extends State<ScheduledWorkoutsView> {
  DateTime selectedDate = DateTime.now();
  int _rebuildKey = 0;

  // Calendar state
  late DateTime _calendarMonth;
  Map<DateTime, ({int? color, bool isCompleted, bool isSkipped})> _calendarData = {};
  bool _isCalendarExpanded = false;

  @override
  void initState() {
    super.initState();
    _calendarMonth = DateTime(selectedDate.year, selectedDate.month);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<ScheduleWorkoutProvider>();
      provider.loadForDate(selectedDate);
      await _loadCalendarData();
      await _checkForInProgressWorkout();
    });
  }

  Future<void> _loadCalendarData() async {
    final db = context.read<AppDatabase>();
    final data = await db.scheduledWorkoutDao
        .getWorkoutColorSummariesForMonth(_calendarMonth);
    if (mounted) setState(() => _calendarData = data);
  }

  Future<void> _selectDate(DateTime date, ScheduleWorkoutProvider provider) async {
    final newMonth = DateTime(date.year, date.month);
    setState(() => selectedDate = date);
    await provider.loadForDate(date);
    if (newMonth != _calendarMonth) {
      _calendarMonth = newMonth;
      await _loadCalendarData();
    }
  }

  /// If the OS killed the app while the user was mid-workout, offer to resume.
  Future<void> _checkForInProgressWorkout() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getInt('active_workout_scheduled_id');
    final savedDateStr = prefs.getString('active_workout_scheduled_date');

    if (savedId == null || savedDateStr == null || !mounted) return;

    final db = context.read<AppDatabase>();

    final scheduledData =
        await (db.select(db.scheduledWorkoutTable)
              ..where((t) => t.id.equals(savedId)))
            .getSingleOrNull();

    // Clear stale marker if the workout no longer exists or was already done.
    if (scheduledData == null || scheduledData.isCompleted) {
      await prefs.remove('active_workout_scheduled_id');
      await prefs.remove('active_workout_scheduled_date');
      return;
    }

    final workoutData =
        await (db.select(db.workoutTable)
              ..where((t) => t.id.equals(scheduledData.workoutId)))
            .getSingleOrNull();

    if (!mounted) return;

    final workoutName = workoutData?.name ?? 'Workout';
    final date = DateTime.parse(savedDateStr);

    final l10n = AppLocalizations.of(context)!;
    final shouldResume = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.resumeWorkoutTitle),
            content: Text(l10n.resumeWorkoutBody(workoutName)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.discardWorkout),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.resumeWorkout),
              ),
            ],
          ),
    );

    if (shouldResume != true) {
      await prefs.remove('active_workout_scheduled_id');
      await prefs.remove('active_workout_scheduled_date');
      return;
    }

    if (!mounted) return;

    final item = ScheduledWorkoutWithDetails(
      scheduled: scheduledData,
      workout: workoutData,
    );

    setState(() => selectedDate = date);

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (_) => ActiveWorkoutScreen(
              scheduledWorkout: item,
              scheduledDate: date,
              isReadOnly: false,
            ),
      ),
    );

    if (result == true && mounted) {
      context.read<ScheduleWorkoutProvider>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<ScheduleWorkoutProvider>(
      key: ValueKey(_rebuildKey),
      builder: (context, provider, _) {
        return Scaffold(
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
                tooltip: l10n.seedWorkoutTemplates,
                icon: const Icon(Icons.file_download),
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.seedingTemplates)),
                  );
                },
              ),
              IconButton(
                tooltip: 'Manage Exercises',
                icon: const Icon(Icons.sports_gymnastics),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ExerciseManagementScreen(),
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.manageWorkouts,
                icon: const Icon(Icons.list),
                onPressed: () async {
                  final provider = context.read<ScheduleWorkoutProvider>();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WorkoutsListView()),
                  );
                  if (mounted) provider.refresh();
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // ── Collapsible calendar ──────────────────────────────────
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header row — always visible, tap to expand/collapse
                  InkWell(
                    onTap: () => setState(
                      () => _isCalendarExpanded = !_isCalendarExpanded,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            '${selectedDate.year}-'
                            '${selectedDate.month.toString().padLeft(2, '0')}-'
                            '${selectedDate.day.toString().padLeft(2, '0')}',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.arrow_back, size: 18),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _selectDate(
                              selectedDate.subtract(const Duration(days: 1)),
                              provider,
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                _selectDate(DateTime.now(), provider),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                            ),
                            child: Text(l10n.today),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _selectDate(
                              selectedDate.add(const Duration(days: 1)),
                              provider,
                            ),
                          ),
                          Icon(
                            _isCalendarExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 20,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Expandable calendar grid
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: _isCalendarExpanded
                        ? _WorkoutCalendar(
                            month: _calendarMonth,
                            selectedDate: selectedDate,
                            calendarData: _calendarData,
                            onDayTapped: (date) {
                              _selectDate(date, provider);
                              setState(() => _isCalendarExpanded = false);
                            },
                            onMonthChanged: (month) async {
                              setState(() => _calendarMonth = month);
                              await _loadCalendarData();
                            },
                            onRefreshTapped: () async {
                              provider.refresh();
                              await _loadCalendarData();
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
                  Divider(
                    height: 1,
                    color: Theme.of(context).dividerColor,
                  ),
                ],
              ),
              // Workout list
              Expanded(
                child:
                    provider.isRefreshing
                        ? const Center(child: CircularProgressIndicator())
                        : provider.scheduled.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.fitness_center,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.noScheduledWorkouts,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                        : ListView.builder(
                          itemCount: provider.scheduled.length,
                          itemBuilder: (context, index) {
                            final item = provider.scheduled[index];
                            return _buildWorkoutCard(item, context);
                          },
                        ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: l10n.createOrEditWorkouts,
            child: const Icon(Icons.add),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final provider = context.read<ScheduleWorkoutProvider>();
              showModalBottomSheet(
                context: context,
                builder:
                    (bottomSheetContext) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.schedule),
                            title: Text(l10n.newWorkout),
                            onTap: () async {
                              Navigator.of(bottomSheetContext).pop();
                              await navigator.push(
                                MaterialPageRoute(
                                  builder: (_) => CreateWorkoutView(),
                                ),
                              );
                              provider.refresh();
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.remove_red_eye),
                            title: Text(l10n.viewWorkouts),
                            onTap: () async {
                              Navigator.of(bottomSheetContext).pop();
                              final result = await navigator.push(
                                MaterialPageRoute(
                                  builder: (_) => WorkoutsListView(),
                                ),
                              );
                              if (result == true) {
                                context.read<WorkoutProvider>().loadTemplates();
                                provider.refresh();
                                setState(() => _rebuildKey++);
                              }
                            },
                          ),
                          FutureBuilder<WorkoutPlan?>(
                            future: _getActiveFreeChoicePlan(),
                            builder: (ctx, snap) {
                              final plan = snap.data;
                              if (plan == null) return const SizedBox.shrink();
                              return ListTile(
                                leading: const Icon(Icons.add_task),
                                title: Text(
                                  l10n.addWorkoutForDate(DateFormat.MMMd().format(selectedDate)),
                                ),
                                onTap: () async {
                                  Navigator.of(bottomSheetContext).pop();
                                  await _pickAndScheduleWorkout(plan, provider);
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildWorkoutCard(
    ScheduledWorkoutWithDetails item,
    BuildContext context,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isRestDay = item.workout?.name == 'Rest Day';
    final isCompleted = item.scheduled.isCompleted;
    final isSkipped = item.scheduled.isSkipped;

    Color cardColor;
    if (isSkipped) {
      cardColor = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
    } else if (isCompleted) {
      cardColor = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    } else {
      cardColor = theme.colorScheme.surface;
    }

    return FutureBuilder<Workout?>(
      future: _fetchTemplateWorkout(item.workout!.id!),
      builder: (context, snapshot) {
        final workout = snapshot.data;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: cardColor,
          child: InkWell(
            onTap: () {
              if (isSkipped || isRestDay) return;
              if (isCompleted) {
                _viewCompletedWorkout(item);
              } else {
                _startWorkout(item);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isSkipped
                            ? Icons.block
                            : isRestDay
                            ? Icons.hotel
                            : Icons.fitness_center,
                        color: isSkipped
                            ? Colors.grey
                            : isRestDay
                            ? Colors.blue
                            : isCompleted
                            ? Colors.green
                            : Colors.orange,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              workout?.name ?? l10n.unknownWorkout,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: isSkipped ? Colors.grey : null,
                                decoration: isCompleted || isSkipped
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            if (isSkipped)
                              Text(
                                l10n.skipped,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              )
                            else if (!isRestDay && workout != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                l10n.minutesShort(
                                  workout.estimatedDurationMinutes!,
                                ),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isCompleted)
                        const Icon(Icons.check_circle, color: Colors.green, size: 32)
                      else if (!isRestDay)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            if (value == 'skip') {
                              _skipWorkout(item);
                            } else if (value == 'postpone') {
                              _postponeWorkout(item);
                            } else if (value == 'unskip') {
                              _unskipWorkout(item);
                            }
                          },
                          itemBuilder: (context) => [
                            if (isSkipped)
                              PopupMenuItem(
                                value: 'unskip',
                                child: Row(
                                  children: [
                                    const Icon(Icons.undo, size: 18),
                                    const SizedBox(width: 8),
                                    Text(l10n.undoSkip),
                                  ],
                                ),
                              )
                            else ...[
                              PopupMenuItem(
                                value: 'skip',
                                child: Row(
                                  children: [
                                    const Icon(Icons.block, size: 18),
                                    const SizedBox(width: 8),
                                    Text(l10n.skipWorkout),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'postpone',
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 18),
                                    const SizedBox(width: 8),
                                    Text(l10n.postponeWorkout),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                  if (item.scheduled.notes != null &&
                      item.scheduled.notes!.isNotEmpty)
                    const SizedBox(height: 12),
                  if (item.scheduled.notes != null &&
                      item.scheduled.notes!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.note, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.scheduled.notes!,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!isRestDay && !isSkipped) ...[
                    const SizedBox(height: 12),
                    isCompleted
                        ? Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _viewCompletedWorkout(item),
                                  icon: const Icon(Icons.visibility),
                                  label: Text(l10n.viewLabel),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _editCompletedWorkout(item),
                                  icon: const Icon(Icons.edit),
                                  label: Text(l10n.edit),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ElevatedButton.icon(
                            onPressed: () => _startWorkout(item),
                            icon: const Icon(Icons.play_arrow),
                            label: Text(l10n.startWorkout),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                              backgroundColor: theme.colorScheme.primary,
                            ),
                          ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _skipWorkout(ScheduledWorkoutWithDetails item) async {
    final provider = context.read<ScheduleWorkoutProvider>();
    await provider.skipWorkout(item.scheduled.id);
  }

  Future<void> _unskipWorkout(ScheduledWorkoutWithDetails item) async {
    final provider = context.read<ScheduleWorkoutProvider>();
    await provider.unskipWorkout(item.scheduled.id);
  }

  Future<void> _postponeWorkout(ScheduledWorkoutWithDetails item) async {
    final l10n = AppLocalizations.of(context)!;
    final newDate = await showDatePicker(
      context: context,
      initialDate: selectedDate.add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: l10n.postponeWorkout,
    );
    if (newDate == null || !mounted) return;

    final provider = context.read<ScheduleWorkoutProvider>();
    await provider.postponeWorkout(item.scheduled.id, newDate);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.workoutPostponedTo(
          '${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}',
        )),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // Helper to fetch latest template from DB
  Future<Workout?> _fetchTemplateWorkout(int templateId) async {
    final db = context.read<AppDatabase>();
    return await db.workoutDao.getWorkoutById(templateId);
  }

  /// Returns the active plan if it is a free-choice plan, otherwise null.
  Future<WorkoutPlan?> _getActiveFreeChoicePlan() async {
    final db = sl<AppDatabase>();
    final activePlans = await db.workoutPlanDao.getActivePlans();
    if (activePlans.isEmpty) return null;
    final planData = activePlans.first;
    if (!planData.isFreeChoice) return null;
    return db.workoutPlanDao.getCompletePlanById(planData.id);
  }

  /// Show a picker with the plan's workout templates and schedule the selected
  /// one for [selectedDate].
  Future<void> _pickAndScheduleWorkout(
    WorkoutPlan plan,
    ScheduleWorkoutProvider provider,
  ) async {
    final templates = plan.workouts.where((w) => w.name != 'Rest Day').toList();
    if (templates.isEmpty || !mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final selected = await showDialog<Workout>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(
          l10n.pickWorkoutForDate(DateFormat.MMMd().format(selectedDate)),
        ),
        children: templates
            .map(
              (w) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, w),
                child: Text(w.name),
              ),
            )
            .toList(),
      ),
    );
    if (selected == null || !mounted) return;

    final db = sl<AppDatabase>();
    await db.scheduledWorkoutDao.scheduleWorkout(
      ScheduledWorkoutTableCompanion.insert(
        workoutId: selected.id!,
        templateWorkoutId: drift.Value(selected.id),
        scheduledDate: DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
        ),
        workoutPlanId: drift.Value(plan.id),
      ),
    );

    provider.refresh();
    await _loadCalendarData();
  }

  /// Navigate to the ActiveWorkoutScreen for starting a workout
  Future<void> _startWorkout(ScheduledWorkoutWithDetails item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ActiveWorkoutScreen(
              scheduledWorkout: item,
              scheduledDate: selectedDate,
              isReadOnly: false,
            ),
      ),
    ); // Refresh the list if the workout was completed
    if (result == true) {
      final provider = context.read<ScheduleWorkoutProvider>();
      provider.refresh();
    }
  }

  /// Edit a completed workout (allows changing logged sets/reps)
  Future<void> _editCompletedWorkout(ScheduledWorkoutWithDetails item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActiveWorkoutScreen(
          scheduledWorkout: item,
          scheduledDate: selectedDate,
          isReadOnly: false,
        ),
      ),
    );
    if (result == true) {
      context.read<ScheduleWorkoutProvider>().refresh();
    }
  }

  /// FIX #4: View completed workout in read-only mode
  Future<void> _viewCompletedWorkout(ScheduledWorkoutWithDetails item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ActiveWorkoutScreen(
              scheduledWorkout: item,
              scheduledDate: selectedDate,
              isReadOnly: true,
            ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Monthly calendar widget with workout colour dots
// ─────────────────────────────────────────────────────────────────────────────

class _WorkoutCalendar extends StatelessWidget {
  final DateTime month;
  final DateTime selectedDate;
  final Map<DateTime, ({int? color, bool isCompleted, bool isSkipped})> calendarData;
  final ValueChanged<DateTime> onDayTapped;
  final ValueChanged<DateTime> onMonthChanged;
  final VoidCallback onRefreshTapped;

  const _WorkoutCalendar({
    required this.month,
    required this.selectedDate,
    required this.calendarData,
    required this.onDayTapped,
    required this.onMonthChanged,
    required this.onRefreshTapped,
  });

  static const _weekdays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);

    // First Monday on or before the 1st of the month
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final startOffset = (firstOfMonth.weekday - 1) % 7; // Mon=0 … Sun=6
    final gridStart = firstOfMonth.subtract(Duration(days: startOffset));

    // Build 6-week grid (42 cells)
    final cells = List.generate(42, (i) => gridStart.add(Duration(days: i)));
    final lastDay = DateTime(month.year, month.month + 1, 0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Month header ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                visualDensity: VisualDensity.compact,
                onPressed: () => onMonthChanged(
                  DateTime(month.year, month.month - 1),
                ),
              ),
              Expanded(
                child: Text(
                  _monthLabel(month),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                visualDensity: VisualDensity.compact,
                onPressed: () => onMonthChanged(
                  DateTime(month.year, month.month + 1),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                visualDensity: VisualDensity.compact,
                onPressed: onRefreshTapped,
              ),
            ],
          ),
        ),

        // ── Weekday labels ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: _weekdays.map((d) => Expanded(
              child: Center(
                child: Text(d,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )).toList(),
          ),
        ),

        const SizedBox(height: 4),

        // ── Day grid ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemCount: cells.length,
            itemBuilder: (ctx, i) {
              final day = cells[i];
              final dayNorm = DateTime(day.year, day.month, day.day);
              final inMonth = day.month == month.month;
              final isSelected = dayNorm == DateTime(
                selectedDate.year, selectedDate.month, selectedDate.day);
              final isToday = dayNorm == todayNorm;
              final info = calendarData[dayNorm];
              // Only show a dot for completed workouts.
              final dotColor = (info != null && info.isCompleted && info.color != null)
                  ? Color(info.color!)
                  : null;

              return GestureDetector(
                onTap: inMonth ? () => onDayTapped(dayNorm) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : isToday
                            ? theme.colorScheme.primary.withValues(alpha: 0.15)
                            : Colors.transparent,
                    border: isToday && !isSelected
                        ? Border.all(
                            color: theme.colorScheme.primary,
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: isSelected || isToday
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? theme.colorScheme.onPrimary
                              : inMonth
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.3),
                        ),
                      ),
                      if (dotColor != null && !isSelected)
                        Positioned(
                          bottom: 3,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: dotColor,
                            ),
                          ),
                        ),
                      if (dotColor != null && isSelected)
                        Positioned(
                          bottom: 3,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
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

        // Hide last row if all cells are in next month
        if (cells[35].month == lastDay.month)
          const SizedBox.shrink()
        else
          const SizedBox(height: 4),

        Divider(height: 1, color: theme.dividerColor),
      ],
    );
  }

  String _monthLabel(DateTime m) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[m.month - 1]} ${m.year}';
  }
}
