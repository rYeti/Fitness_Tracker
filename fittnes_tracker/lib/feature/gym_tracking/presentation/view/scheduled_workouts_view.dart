import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/providers/workout_provider.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/view/workouts/create_view.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/view/workouts/workouts_list_view.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<ScheduleWorkoutProvider>();
      provider.loadForDate(selectedDate);
      await _checkForInProgressWorkout();
    });
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

    final shouldResume = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Resume workout?'),
            content: Text(
              '"$workoutName" was interrupted. Resume where you left off?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Discard'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Resume'),
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
              // Date selector
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                      ),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (d != null && d != selectedDate) {
                          setState(() => selectedDate = d);
                          await provider.loadForDate(d);
                        }
                      },
                    ),
                    const Spacer(),
                    // Quick navigation buttons
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () async {
                        setState(() {
                          selectedDate = selectedDate.subtract(
                            const Duration(days: 1),
                          );
                        });
                        await provider.loadForDate(selectedDate);
                      },
                    ),
                    TextButton(
                      onPressed: () async {
                        setState(() {
                          selectedDate = DateTime.now();
                        });
                        await provider.loadForDate(selectedDate);
                      },
                      child: Text(l10n.today),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () async {
                        setState(() {
                          selectedDate = selectedDate.add(
                            const Duration(days: 1),
                          );
                        });
                        provider.refresh();
                        await provider.loadForDate(selectedDate);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => provider.refresh(),
                    ),
                  ],
                ),
              ), // Workout list
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
                      if (isSkipped)
                        const Icon(Icons.block, color: Colors.grey, size: 28)
                      else if (isCompleted)
                        const Icon(Icons.check_circle, color: Colors.green, size: 32)
                      else if (!isRestDay)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            if (value == 'skip') {
                              _skipWorkout(item);
                            } else if (value == 'postpone') {
                              _postponeWorkout(item);
                            }
                          },
                          itemBuilder: (context) => [
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
