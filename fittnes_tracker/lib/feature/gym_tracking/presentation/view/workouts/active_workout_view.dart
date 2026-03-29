import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/utils/app_logger.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/reset_timer_widget.dart';

// Keys used to persist an in-progress workout so the session can be resumed
// if the OS kills the app while it is minimised.
const _kActiveWorkoutIdKey = 'active_workout_scheduled_id';
const _kActiveWorkoutDateKey = 'active_workout_scheduled_date';

/// Final fixed version with proper controller isolation and workout overview
class ActiveWorkoutScreen extends StatefulWidget {
  final ScheduledWorkoutWithDetails scheduledWorkout;
  final DateTime scheduledDate;
  final bool isReadOnly;
  const ActiveWorkoutScreen({
    super.key,
    required this.scheduledWorkout,
    required this.scheduledDate,
    this.isReadOnly = false,
  });
  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen>
    with WidgetsBindingObserver {
  int _currentExerciseIndex = 0;
  int _currentSetIndex = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  final TextEditingController _workoutNoteController = TextEditingController();
  final Map<String, TextEditingController> _exerciseNoteControllers = {};
  final Map<String, TextEditingController> _setControllers = {};
  List<_ExerciseWithSets> _exercises = [];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadWorkoutData();
    if (!widget.isReadOnly) {
      _saveInProgressWorkout();
    }
  }

  Future<void> _saveInProgressWorkout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _kActiveWorkoutIdKey,
      widget.scheduledWorkout.scheduled.id,
    );
    await prefs.setString(
      _kActiveWorkoutDateKey,
      widget.scheduledDate.toIso8601String(),
    );
  }

  Future<void> _clearInProgressWorkout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kActiveWorkoutIdKey);
    await prefs.remove(_kActiveWorkoutDateKey);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _workoutNoteController.dispose();
    _exerciseNoteControllers.values.forEach((c) => c.dispose());
    _setControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !_isLoading && !widget.isReadOnly) {
      _saveCurrentExercise();
    }
  }

  String _getExerciseNoteKey(int workoutExerciseId) {
    final scheduledId = widget.scheduledWorkout.scheduled.id;

    return '${scheduledId}_$workoutExerciseId';
  }

  String _getSetControllerKey(
    int workoutExerciseId,
    int setNumber,
    String field,
  ) {
    final scheduledId = widget.scheduledWorkout.scheduled.id;

    return '${scheduledId}_${workoutExerciseId}_${setNumber}_$field';
  }

  /// Gets or creates a controller for a specific set field.
  /// Controllers are created on-demand rather than all upfront.
  TextEditingController _getOrCreateSetController(
    int workoutExerciseId,
    int setNumber,
    String field,
    String initialValue,
  ) {
    final key = _getSetControllerKey(workoutExerciseId, setNumber, field);

    return _setControllers.putIfAbsent(
      key,
      () => TextEditingController(text: initialValue),
    );
  }

  Future<void> _loadWorkoutData() async {
    setState(() => _isLoading = true);
    try {
      final db = context.read<AppDatabase>();
      final workout = widget.scheduledWorkout.workout;
      if (workout == null) {
        throw Exception('Workout not found');
      }
      final scheduledWorkoutData =
          await (db.select(db.scheduledWorkoutTable)..where(
            (t) => t.id.equals(widget.scheduledWorkout.scheduled.id),
          )).getSingle();
      if (scheduledWorkoutData.notes != null) {
        _workoutNoteController.text = scheduledWorkoutData.notes!;
      }
      final exercisesData = await db.workoutDao
          .getWorkoutExercisesWithTemplates(workout.id);
      if (exercisesData.isEmpty) {
        setState(() {
          _exercises = [];
          _isLoading = false;
        });
        return;
      }
      final exercises = <_ExerciseWithSets>[];
      for (final exerciseData in exercisesData) {
        final exercise = exerciseData.$1;
        final templates = exerciseData.$2;
        final workoutExercise = exerciseData.$3;
        final previousSets = await _loadPreviousWorkoutSets(
          db: db,
          workoutExerciseId: workoutExercise.id,
        );
        final previousSetsMap = {
          for (var set in previousSets) set.setNumber: set,
        };
        final scheduledExercise =
            await (db.select(db.scheduledWorkoutExerciseTable)
                  ..where((t) => t.workoutExerciseId.equals(workoutExercise.id))
                  ..where(
                    (t) => t.scheduledWorkoutId.equals(
                      widget.scheduledWorkout.scheduled.id,
                    ),
                  ))
                .getSingleOrNull();
        final exerciseNoteKey = _getExerciseNoteKey(workoutExercise.id);
        final noteController = TextEditingController(
          text: scheduledExercise?.notes ?? '',
        );
        _exerciseNoteControllers[exerciseNoteKey] = noteController;
        final existingSets =
            scheduledExercise != null
                ? await (db.select(db.workoutSetTable)
                      ..where(
                        (t) => t.scheduledWorkoutExerciseId.equals(
                          scheduledExercise.id,
                        ),
                      )
                      ..orderBy([(t) => OrderingTerm.asc(t.setNumber)]))
                    .get()
                : <WorkoutSetTableData>[];
        final existingSetsMap = {
          for (var set in existingSets) set.setNumber: set,
        };

        // REMOVED: Controller creation loop
        // Controllers will be created lazily when needed in the UI

        exercises.add(
          _ExerciseWithSets(
            exercise: exercise,
            workoutExercise: workoutExercise,
            templates: templates,
            previousSets: previousSetsMap,
            scheduledExerciseId: scheduledExercise?.id,
            existingSets: existingSetsMap, // Pass existing sets data
          ),
        );
      }
      setState(() {
        _exercises = exercises;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      AppLogger.e('Error loading workout data', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.errorLoadingWorkout as String,
            ),
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<List<WorkoutSetTableData>> _loadPreviousWorkoutSets({
    required AppDatabase db,
    required int workoutExerciseId,
  }) async {
    try {
      final previousScheduledWorkouts =
          await (db.select(db.scheduledWorkoutTable)
                ..where(
                  (t) => t.templateWorkoutId.equals(
                    widget.scheduledWorkout.scheduled.templateWorkoutId!,
                  ),
                )
                ..where(
                  (t) => t.id.isNotValue(widget.scheduledWorkout.scheduled.id),
                )
                ..where((t) => t.isCompleted.equals(true))
                ..where(
                  (t) =>
                      t.scheduledDate.isSmallerThanValue(widget.scheduledDate),
                )
                ..orderBy([(t) => OrderingTerm.desc(t.scheduledDate)]))
              .get();
      if (previousScheduledWorkouts.isEmpty) {
        return [];
      }

      final mostRecentWorkout = previousScheduledWorkouts.first;

      final previousScheduledExercise =
          await (db.select(db.scheduledWorkoutExerciseTable)
                ..where(
                  (t) => t.scheduledWorkoutId.equals(mostRecentWorkout.id),
                )
                ..where((t) => t.workoutExerciseId.equals(workoutExerciseId)))
              .getSingleOrNull();

      if (previousScheduledExercise == null) {
        return [];
      }

      final sets =
          await (db.select(db.workoutSetTable)
                ..where(
                  (t) => t.scheduledWorkoutExerciseId.equals(
                    previousScheduledExercise.id,
                  ),
                )
                ..orderBy([(t) => OrderingTerm.asc(t.setNumber)]))
              .get();

      return sets;
    } catch (e) {
      AppLogger.i('Error loading previous sets: $e');
      return [];
    }
  }

  TextEditingController _getController(
    int workoutExerciseId,
    int setNumber,
    String field,
  ) {
    final key = _getSetControllerKey(workoutExerciseId, setNumber, field);
    final controller = _setControllers[key];
    if (controller == null) {
      return TextEditingController();
    }

    return controller;
  }

  Future<void> _saveCurrentExercise() async {
    if (_currentExerciseIndex >= _exercises.length) return;
    if (widget.isReadOnly) return;
    final db = context.read<AppDatabase>();
    final exerciseData = _exercises[_currentExerciseIndex];

    try {
      final exerciseNoteKey = _getExerciseNoteKey(
        exerciseData.workoutExercise.id,
      );
      final noteController = _exerciseNoteControllers[exerciseNoteKey];

      int scheduledExerciseId;

      if (exerciseData.scheduledExerciseId != null) {
        scheduledExerciseId = exerciseData.scheduledExerciseId!;

        await (db.update(db.scheduledWorkoutExerciseTable)
          ..where((t) => t.id.equals(scheduledExerciseId))).write(
          ScheduledWorkoutExerciseTableCompanion(
            notes: Value(
              noteController?.text.isEmpty ?? true
                  ? null
                  : noteController!.text,
            ),
          ),
        );
      } else {
        scheduledExerciseId = await db
            .into(db.scheduledWorkoutExerciseTable)
            .insert(
              ScheduledWorkoutExerciseTableCompanion.insert(
                scheduledWorkoutId: widget.scheduledWorkout.scheduled.id,
                workoutExerciseId: exerciseData.workoutExercise.id,
                notes: Value(
                  noteController?.text.isEmpty ?? true
                      ? null
                      : noteController!.text,
                ),
              ),
            );

        exerciseData.scheduledExerciseId = scheduledExerciseId;
      }

      await (db.delete(db.workoutSetTable)..where(
        (t) => t.scheduledWorkoutExerciseId.equals(scheduledExerciseId),
      )).go();

      for (final template in exerciseData.templates) {
        final weightKey = _getSetControllerKey(
          exerciseData.workoutExercise.id,
          template.setNumber,
          'weight',
        );
        final repsKey = _getSetControllerKey(
          exerciseData.workoutExercise.id,
          template.setNumber,
          'reps',
        );

        final weightController = _setControllers[weightKey];
        final repsController = _setControllers[repsKey];

        if (weightController != null && repsController != null) {
          final weight = double.tryParse(weightController.text);
          final reps = int.tryParse(repsController.text);
          if (weight != null && reps != null) {
            await db
                .into(db.workoutSetTable)
                .insert(
                  WorkoutSetTableCompanion.insert(
                    scheduledWorkoutExerciseId: scheduledExerciseId,
                    setNumber: template.setNumber,
                    weight: Value(weight),
                    reps: Value(reps),
                    isCompleted: const Value(true),
                  ),
                );
          }
        }
      }
    } catch (e) {
      AppLogger.i('Error saving exercise: $e');
    }
  }

  Future<void> _completeWorkout() async {
    if (widget.isReadOnly) {
      Navigator.pop(context);
      return;
    }
    setState(() => _isSaving = true);

    try {
      await _saveCurrentExercise();

      final db = context.read<AppDatabase>();

      await (db.update(
        db.scheduledWorkoutTable,
      )..where((t) => t.id.equals(widget.scheduledWorkout.scheduled.id))).write(
        ScheduledWorkoutTableCompanion(
          notes: Value(
            _workoutNoteController.text.isEmpty
                ? null
                : _workoutNoteController.text,
          ),
          isCompleted: const Value(true),
        ),
      );

      // Workout is done — remove the in-progress marker so the app no longer
      // offers to resume this session on next launch.
      await _clearInProgressWorkout();

      if (mounted) {
        // Show workout summary
        final shouldReturn = await _showWorkoutSummary();
        if (shouldReturn ?? true) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      AppLogger.i('Error completing workout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.errorCompletingWorkout(e),
            ),
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  /// Show workout summary after completion
  Future<bool?> _showWorkoutSummary() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => WorkoutSummaryDialog(
            workoutName: widget.scheduledWorkout.workout?.name ?? 'Workout',
            exercises: _exercises,
            workoutNote: _workoutNoteController.text,
            getController: _getController,
            getExerciseNoteController: (workoutExerciseId) {
              final key = _getExerciseNoteKey(workoutExerciseId);
              return _exerciseNoteControllers[key];
            },
          ),
    );
  }

  void _nextSet() {
    if (widget.isReadOnly) return;
    final currentExercise = _exercises[_currentExerciseIndex];
    if (_currentSetIndex < currentExercise.templates.length - 1) {
      setState(() {
        _currentSetIndex++;
      });
      showRestTimer(context);
    } else {
      _nextExercise();
    }
  }

  void _nextExercise() {
    if (widget.isReadOnly) return;
    if (_currentExerciseIndex < _exercises.length - 1) {
      _saveCurrentExercise();
      setState(() {
        _currentExerciseIndex++;
        _currentSetIndex = 0;
      });
    }
  }

  void _previousExercise() {
    if (widget.isReadOnly) return;
    if (_currentExerciseIndex > 0) {
      _saveCurrentExercise();
      setState(() {
        _currentExerciseIndex--;
        _currentSetIndex = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.loading)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_exercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.scheduledWorkout.workout?.name ?? 'Workout'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 64,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.workoutHasNoExercises,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.addExercisesToTemplate,
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: Text(l10n.goBack),
              ),
            ],
          ),
        ),
      );
    }

    // FIX #2: Show overview for read-only (completed) workouts
    if (widget.isReadOnly) {
      return _buildWorkoutOverview(theme);
    }

    // Regular workout execution view
    final currentExercise = _exercises[_currentExerciseIndex];
    final totalExercises = _exercises.length;
    final totalSets = _exercises.fold<int>(
      0,
      (sum, ex) => sum + ex.templates.length,
    );
    final completedSets =
        _exercises
            .take(_currentExerciseIndex)
            .fold<int>(0, (sum, ex) => sum + ex.templates.length) +
        _currentSetIndex;
    final progress = totalSets > 0 ? (completedSets + 1) / totalSets : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.scheduledWorkout.workout?.name ?? 'Workout'),
        actions: [
          IconButton(
            icon: const Icon(Icons.timer),
            tooltip: l10n.restTimer,
            onPressed: () => showRestTimer(context),
          ),
          IconButton(
            icon: const Icon(Icons.note_add),
            tooltip: l10n.workoutNotes,
            onPressed: () => _showWorkoutNotesDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceVariant,
            valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.exerciseXofY(
                        _currentExerciseIndex + 1,
                        totalExercises,
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      l10n.stepXofY(
                        _currentSetIndex + 1,
                        currentExercise.templates.length,
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _showExerciseList(context),
                  icon: const Icon(Icons.list),
                  label: Text(l10n.jumpTo),
                ),
              ],
            ),
          ),

          Expanded(child: _buildSetFocusedView(currentExercise, theme)),

          _buildNavigationButtons(theme, l10n),
        ],
      ),
    );
  }

  /// FIX #2: Build workout overview for completed workouts
  Widget _buildWorkoutOverview(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.scheduledWorkout.workout?.name ?? 'Workout'),
            Text(
              l10n.completedWorkout,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.green),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.summarize),
            tooltip: l10n.workoutSummaryLabel,
            onPressed: _showWorkoutSummary,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Workout note
            if (_workoutNoteController.text.isNotEmpty) ...[
              Card(
                color: theme.colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.notes,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.workoutNotes,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _workoutNoteController.text,
                        style: TextStyle(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Exercise summaries
            ..._exercises.map((exercise) {
              final exerciseNoteKey = _getExerciseNoteKey(
                exercise.workoutExercise.id,
              );
              final exerciseNoteController =
                  _exerciseNoteControllers[exerciseNoteKey];
              final hasNote =
                  exerciseNoteController != null &&
                  exerciseNoteController.text.isNotEmpty;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.exercise.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (exercise.exercise.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          exercise.exercise.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Sets table header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 50,
                              child: Text(
                                l10n.setLabel,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                l10n.weight,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                l10n.reps,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Sets data
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(8),
                          ),
                        ),
                        child: Column(
                          children:
                              exercise.templates.map((template) {
                                final weightController =
                                    _getOrCreateSetController(
                                      exercise.workoutExercise.id,
                                      template.setNumber,
                                      'weight',
                                      exercise
                                              .existingSets[template.setNumber]
                                              ?.weight
                                              ?.toString() ??
                                          '',
                                    );
                                final repsController =
                                    _getOrCreateSetController(
                                      exercise.workoutExercise.id,
                                      template.setNumber,
                                      'reps',
                                      exercise
                                              .existingSets[template.setNumber]
                                              ?.reps
                                              ?.toString() ??
                                          '',
                                    );

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: theme.dividerColor.withOpacity(
                                          0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 50,
                                        child: Text(
                                          '${template.setNumber}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          weightController.text.isNotEmpty
                                              ? '${weightController.text} kg'
                                              : '--',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          repsController.text.isNotEmpty
                                              ? '${repsController.text} reps'
                                              : '--',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                        ),
                      ),

                      // Exercise note
                      if (hasNote) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant.withOpacity(
                              0.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.note,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  exerciseNoteController.text,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSetFocusedView(_ExerciseWithSets exerciseData, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final currentTemplate = exerciseData.templates[_currentSetIndex];
    final previousSet = exerciseData.previousSets[currentTemplate.setNumber];
    final exerciseNoteKey = _getExerciseNoteKey(
      exerciseData.workoutExercise.id,
    );
    final exerciseNoteController = _exerciseNoteControllers[exerciseNoteKey];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Text(
                    exerciseData.exercise.name,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (exerciseData.exercise.description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      exerciseData.exercise.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${l10n.setLabel}\n${currentTemplate.setNumber}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onSecondary,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (previousSet != null)
            Card(
              color: theme.colorScheme.surfaceVariant,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.lastTime,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${previousSet.weight?.toString() ?? '--'} kg × ${previousSet.reps ?? '--'} reps',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.noPreviousDataForSet,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.note_alt, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        l10n.exerciseNotes,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: exerciseNoteController,
                    decoration: InputDecoration(
                      hintText: l10n.exerciseFeelingHint,
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withOpacity(0.3),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.weight, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _getOrCreateSetController(
                      exerciseData.workoutExercise.id,
                      currentTemplate.setNumber,
                      'weight',
                      exerciseData
                              .existingSets[currentTemplate.setNumber]
                              ?.weight
                              ?.toString() ??
                          '',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      hintText: '0.0',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.reps, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _getOrCreateSetController(
                      exerciseData.workoutExercise.id,
                      currentTemplate.setNumber,
                      'reps',
                      exerciseData.existingSets[currentTemplate.setNumber]?.reps
                              ?.toString() ??
                          '',
                    ),
                    keyboardType: TextInputType.number,
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      hintText: '0',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.avgSets,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...exerciseData.templates.asMap().entries.map((entry) {
                    final index = entry.key;
                    final template = entry.value;
                    final isCurrent = index == _currentSetIndex;
                    final isPast = index < _currentSetIndex;

                    final weightController = _getOrCreateSetController(
                      exerciseData.workoutExercise.id,
                      template.setNumber,
                      'weight',
                      exerciseData.existingSets[template.setNumber]?.weight
                              ?.toString() ??
                          '',
                    );
                    final repsController = _getOrCreateSetController(
                      exerciseData.workoutExercise.id,
                      template.setNumber,
                      'reps',
                      exerciseData.existingSets[template.setNumber]?.reps
                              ?.toString() ??
                          '',
                    );

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color:
                                  isCurrent
                                      ? theme.colorScheme.primary
                                      : isPast
                                      ? Colors.green
                                      : theme.colorScheme.surfaceVariant,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${template.setNumber}',
                                style: TextStyle(
                                  color:
                                      isCurrent || isPast
                                          ? Colors.white
                                          : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isPast &&
                                      weightController.text.isNotEmpty &&
                                      repsController.text.isNotEmpty
                                  ? '${weightController.text} kg × ${repsController.text} reps'
                                  : isCurrent
                                  ? l10n.currentSetLabel
                                  : l10n.upcoming,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color:
                                    isPast && weightController.text.isNotEmpty
                                        ? null
                                        : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(ThemeData theme, AppLocalizations l10n) {
    final isFirstExercise = _currentExerciseIndex == 0;
    final isLastExercise = _currentExerciseIndex == _exercises.length - 1;
    final currentExercise = _exercises[_currentExerciseIndex];
    final isLastSet = _currentSetIndex == currentExercise.templates.length - 1;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _isSaving
                        ? null
                        : (isLastSet && isLastExercise
                            ? _completeWorkout
                            : _nextSet),
                icon: Icon(
                  isLastSet && isLastExercise
                      ? Icons.check
                      : Icons.arrow_forward,
                ),
                label: Text(
                  isLastSet && isLastExercise
                      ? l10n.completedWorkout
                      : isLastSet
                      ? l10n.nextExercise
                      : l10n.nextSet,
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor:
                      isLastSet && isLastExercise
                          ? Colors.green
                          : theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (!isFirstExercise)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _previousExercise,
                      icon: const Icon(Icons.arrow_back),
                      label: Text(l10n.prevExercise),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showWorkoutNotesDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.workoutNotes),
            content: TextField(
              controller: _workoutNoteController,
              decoration: InputDecoration(
                hintText: l10n.overallWorkoutHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.close),
              ),
            ],
          ),
    );
  }

  void _showExerciseList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => ListView.builder(
            itemCount: _exercises.length,
            itemBuilder: (context, index) {
              final exercise = _exercises[index];
              final isCurrent = index == _currentExerciseIndex;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      isCurrent
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceVariant,
                  child: Text('${index + 1}'),
                ),
                title: Text(
                  exercise.exercise.name,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  AppLocalizations.of(
                    context,
                  )!.setTemplatesCount(exercise.templates.length),
                ),
                onTap: () {
                  _saveCurrentExercise();
                  setState(() {
                    _currentExerciseIndex = index;
                    _currentSetIndex = 0;
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
    );
  }
}

/// Workout Summary Dialog - Using Column/Row layout
class WorkoutSummaryDialog extends StatelessWidget {
  final String workoutName;
  final List<_ExerciseWithSets> exercises;
  final String workoutNote;
  final TextEditingController? Function(
    int workoutExerciseId,
    int setNumber,
    String field,
  )
  getController;
  final TextEditingController? Function(int workoutExerciseId)
  getExerciseNoteController;
  const WorkoutSummaryDialog({
    super.key,
    required this.workoutName,
    required this.exercises,
    required this.workoutNote,
    required this.getController,
    required this.getExerciseNoteController,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.workoutComplete,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(workoutName, style: theme.textTheme.bodyLarge),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Workout note
                    if (workoutNote.isNotEmpty) ...[
                      Card(
                        color: theme.colorScheme.secondaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.notes,
                                    color:
                                        theme.colorScheme.onSecondaryContainer,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.workoutNotes,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color:
                                              theme
                                                  .colorScheme
                                                  .onSecondaryContainer,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                workoutNote,
                                style: TextStyle(
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    Text(
                      l10n.exercisesSummary,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Exercise summaries
                    ...exercises.map((exercise) {
                      final exerciseNoteController = getExerciseNoteController(
                        exercise.workoutExercise.id,
                      );
                      final hasNote =
                          exerciseNoteController != null &&
                          exerciseNoteController.text.isNotEmpty;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exercise.exercise.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Sets table header
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(8),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 50,
                                      child: Text(
                                        l10n.setLabel,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        l10n.weight,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        l10n.reps,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Sets data
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: theme.dividerColor),
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(8),
                                  ),
                                ),
                                child: Column(
                                  children:
                                      exercise.templates.map((template) {
                                        final weightController = getController(
                                          exercise.workoutExercise.id,
                                          template.setNumber,
                                          'weight',
                                        );
                                        final repsController = getController(
                                          exercise.workoutExercise.id,
                                          template.setNumber,
                                          'reps',
                                        );

                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: theme.dividerColor
                                                    .withOpacity(0.5),
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 50,
                                                child: Text(
                                                  '${template.setNumber}',
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  weightController?.text ??
                                                      '--',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  repsController?.text ?? '--',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                ),
                              ),

                              // Exercise note
                              if (hasNote) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceVariant
                                        .withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.note,
                                        size: 16,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          exerciseNoteController.text,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                fontStyle: FontStyle.italic,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.check),
                  label: Text(l10n.done),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseWithSets {
  final ExerciseTableData exercise;
  final WorkoutExerciseTableData workoutExercise;
  final List<WorkoutSetTemplateData> templates;
  final Map<int, WorkoutSetTableData> previousSets;
  final Map<int, WorkoutSetTableData> existingSets;
  int? scheduledExerciseId;
  _ExerciseWithSets({
    required this.exercise,
    required this.workoutExercise,
    required this.templates,
    required this.previousSets,
    this.scheduledExerciseId,
    required this.existingSets,
  });
}
