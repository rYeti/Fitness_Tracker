import 'dart:async';
import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/utils/app_logger.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/exercise_selection_modal.dart';
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
  bool _restTimerEnabled = true;
  final TextEditingController _workoutNoteController = TextEditingController();
  final Map<String, TextEditingController> _exerciseNoteControllers = {};
  final Map<String, TextEditingController> _setControllers = {};
  List<_ExerciseWithSets> _exercises = [];
  Timer? _saveDebounce;
  int _nextSupersetGroupId = 1;

  /// Returns the index of the superset partner of [index], or null if none.
  int? _supersetPartnerIndex(int index) {
    final groupId = _exercises[index].supersetGroupId;
    if (groupId == null) return null;
    for (var i = 0; i < _exercises.length; i++) {
      if (i != index && _exercises[i].supersetGroupId == groupId) return i;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadWorkoutData();
    _loadRestTimerPreference();
    if (!widget.isReadOnly) {
      _saveInProgressWorkout();
    }
  }

  Future<void> _loadRestTimerPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _restTimerEnabled = prefs.getBool('rest_timer_enabled') ?? true;
      });
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

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(
      const Duration(milliseconds: 800),
      _saveCurrentExercise,
    );
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _workoutNoteController.dispose();
    _exerciseNoteControllers.values.forEach((c) => c.dispose());
    _setControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused &&
        !_isLoading &&
        !widget.isReadOnly) {
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
        // If a per-day override exercise was saved, load that instead
        final overrideId = scheduledExercise?.overrideExerciseId;
        final resolvedExercise =
            overrideId != null
                ? (await db.exerciseDao.getExerciseById(overrideId)) ?? exercise
                : exercise;

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

        exercises.add(
          _ExerciseWithSets(
            exercise: resolvedExercise,
            workoutExercise: workoutExercise,
            templates: templates,
            previousSets: previousSetsMap,
            scheduledExerciseId: scheduledExercise?.id,
            existingSets: existingSetsMap,
            supersetGroupId: workoutExercise.supersetGroupId,
          ),
        );
      }
      final maxGroupId = exercises
          .map((e) => e.supersetGroupId ?? 0)
          .fold(0, (a, b) => a > b ? a : b);
      setState(() {
        _exercises = exercises;
        _nextSupersetGroupId = maxGroupId + 1;
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
          if (weight != null || reps != null) {
            await db
                .into(db.workoutSetTable)
                .insert(
                  WorkoutSetTableCompanion.insert(
                    scheduledWorkoutExerciseId: scheduledExerciseId,
                    setNumber: template.setNumber,
                    weight: Value(weight ?? 0.0),
                    reps: Value(reps ?? 0),
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
    final partnerIndex = _supersetPartnerIndex(_currentExerciseIndex);

    if (partnerIndex != null) {
      // Superset: alternate to partner for the same set number, then advance
      final isOnFirst = _currentExerciseIndex < partnerIndex;
      final partnerSets = _exercises[partnerIndex].templates.length;
      final currentSets = currentExercise.templates.length;
      final maxSets = currentSets > partnerSets ? currentSets : partnerSets;

      if (isOnFirst) {
        // Jump to partner at same set index (clamped to its length)
        _saveCurrentExercise();
        final partnerSetIndex =
            _currentSetIndex < partnerSets ? _currentSetIndex : partnerSets - 1;
        setState(() {
          _currentExerciseIndex = partnerIndex;
          _currentSetIndex = partnerSetIndex;
        });
        if (_restTimerEnabled) showRestTimer(context);
      } else {
        // Back on second exercise — advance set or leave superset
        if (_currentSetIndex < maxSets - 1) {
          final nextSet = _currentSetIndex + 1;
          _saveCurrentExercise();
          final firstIndex = partnerIndex; // partner is now the "first"
          final firstSets = _exercises[firstIndex].templates.length;
          final firstSetIndex = nextSet < firstSets ? nextSet : firstSets - 1;
          setState(() {
            _currentExerciseIndex = firstIndex;
            _currentSetIndex = firstSetIndex;
          });
          if (_restTimerEnabled) showRestTimer(context);
        } else {
          _saveCurrentExercise();
          // Both exercises done — skip past the superset pair
          final afterSuperset =
              (partnerIndex > _currentExerciseIndex
                  ? partnerIndex
                  : _currentExerciseIndex) +
              1;
          if (afterSuperset < _exercises.length) {
            setState(() {
              _currentExerciseIndex = afterSuperset;
              _currentSetIndex = 0;
            });
          }
        }
      }
      return;
    }

    // Normal (non-superset) flow
    if (_currentSetIndex < currentExercise.templates.length - 1) {
      setState(() {
        _currentSetIndex++;
      });
      if (_restTimerEnabled) showRestTimer(context);
    } else {
      _nextExercise();
    }
  }

  void _addSet() {
    if (widget.isReadOnly) return;
    final exercise = _exercises[_currentExerciseIndex];
    final nextSetNumber =
        exercise.templates.isEmpty ? 1 : exercise.templates.last.setNumber + 1;
    final newTemplate = WorkoutSetTemplateData(
      id: -nextSetNumber, // ephemeral id, not persisted to template table
      workoutExerciseId: exercise.workoutExercise.id,
      setNumber: nextSetNumber,
      targetReps: '',
      orderPosition: nextSetNumber,
      syncStatus: 0,
    );
    setState(() {
      exercise.templates = List.from(exercise.templates)..add(newTemplate);
    });
    _scheduleSave();
  }

  void _removeSet() {
    if (widget.isReadOnly) return;
    final exercise = _exercises[_currentExerciseIndex];
    if (exercise.templates.length <= 1) return;
    setState(() {
      exercise.templates = List.from(exercise.templates)..removeLast();
      if (_currentSetIndex >= exercise.templates.length) {
        _currentSetIndex = exercise.templates.length - 1;
      }
    });
    _scheduleSave();
  }

  Future<void> _replaceCurrentExercise() async {
    final selected = await ExerciseSelectionModal.show(context);
    if (selected == null || selected.id == null) return;
    if (!mounted) return;

    final db = context.read<AppDatabase>();
    final exerciseData = await db.exerciseDao.getExerciseById(selected.id!);
    if (exerciseData == null) return;

    final current = _exercises[_currentExerciseIndex];

    // Ensure a scheduledWorkoutExercise row exists so we can write the override
    int scheduledExerciseId;
    if (current.scheduledExerciseId != null) {
      scheduledExerciseId = current.scheduledExerciseId!;
      await (db.update(db.scheduledWorkoutExerciseTable)
        ..where((t) => t.id.equals(scheduledExerciseId))).write(
        ScheduledWorkoutExerciseTableCompanion(
          overrideExerciseId: Value(selected.id),
        ),
      );
    } else {
      scheduledExerciseId = await db
          .into(db.scheduledWorkoutExerciseTable)
          .insert(
            ScheduledWorkoutExerciseTableCompanion.insert(
              scheduledWorkoutId: widget.scheduledWorkout.scheduled.id,
              workoutExerciseId: current.workoutExercise.id,
              overrideExerciseId: Value(selected.id),
            ),
          );
    }

    final setCount = current.templates.length;
    final newTemplates = List.generate(
      setCount,
      (i) => WorkoutSetTemplateData(
        id: -(i + 1),
        workoutExerciseId: current.workoutExercise.id,
        setNumber: i + 1,
        targetReps: '',
        orderPosition: i + 1,
        syncStatus: 0,
      ),
    );

    // Remove stale controllers for the old exercise
    for (final t in current.templates) {
      _setControllers.remove(
        _getSetControllerKey(current.workoutExercise.id, t.setNumber, 'weight'),
      );
      _setControllers.remove(
        _getSetControllerKey(current.workoutExercise.id, t.setNumber, 'reps'),
      );
    }

    setState(() {
      _exercises[_currentExerciseIndex] = _ExerciseWithSets(
        exercise: exerciseData,
        workoutExercise: current.workoutExercise,
        templates: newTemplates,
        previousSets: const {},
        existingSets: const {},
        scheduledExerciseId: scheduledExerciseId,
      );
      _currentSetIndex = 0;
    });
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
      return SafeArea(
        child: Scaffold(
          appBar: AppBar(title: Text(l10n.loading)),
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_exercises.isEmpty) {
      return SafeArea(
        child: Scaffold(
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
        ),
      );
    }

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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _saveCurrentExercise();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: SafeArea(
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.scheduledWorkout.workout?.name ?? 'Workout'),
            actions: [
              IconButton(
                icon: const Icon(Icons.swap_horiz),
                tooltip: l10n.replaceExercise,
                onPressed: _replaceCurrentExercise,
              ),
              if (_restTimerEnabled)
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
        ),
      ),
    );
  }

  /// FIX #2: Build workout overview for completed workouts
  Widget _buildWorkoutOverview(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Scaffold(
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
                          exercise.exercise.localizedName(Localizations.localeOf(context).languageCode),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (exercise.exercise.localizedDescription(Localizations.localeOf(context).languageCode) != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            exercise.exercise.localizedDescription(Localizations.localeOf(context).languageCode)!,
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
                                                .existingSets[template
                                                    .setNumber]
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
                                                .existingSets[template
                                                    .setNumber]
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
                              color: theme.colorScheme.surfaceVariant
                                  .withOpacity(0.5),
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
                    onChanged: (_) => _scheduleSave(),
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
                    onChanged: (_) => _scheduleSave(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

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

                    return GestureDetector(
                      onTap: () => setState(() => _currentSetIndex = index),
                      child: Padding(
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
                            if (!isCurrent)
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                          ],
                        ),
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
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        currentExercise.templates.length > 1
                            ? _removeSet
                            : null,
                    icon: const Icon(Icons.remove, size: 16),
                    label: Text(
                      l10n.removeSet,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addSet,
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(
                      l10n.addSet,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
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
      builder: (sheetContext) {
        int? supersetPickIndex;
        return StatefulBuilder(
          builder:
              (sheetContext, setSheetState) => SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.of(sheetContext)!.exercises,
                            style: Theme.of(sheetContext).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            tooltip:
                                AppLocalizations.of(sheetContext)!.addExercise,
                            onPressed: () async {
                              final selected =
                                  await ExerciseSelectionModal.show(
                                    sheetContext,
                                  );
                              if (selected == null || selected.id == null)
                                return;
                              if (!mounted) return;
                              final db = context.read<AppDatabase>();
                              final exerciseData = await db.exerciseDao
                                  .getExerciseById(selected.id!);
                              if (exerciseData == null) return;
                              // Use a placeholder workoutExerciseId — sets are saved via scheduledExercise
                              // We reuse the first exercise's workoutExercise as a reference for the
                              // controller key namespace, using a unique negative id.
                              final tempId = -(_exercises.length + 100);
                              final newExercise = _ExerciseWithSets(
                                exercise: exerciseData,
                                workoutExercise: WorkoutExerciseTableData(
                                  id: tempId,
                                  workoutId:
                                      _exercises
                                          .first
                                          .workoutExercise
                                          .workoutId,
                                  exerciseId: exerciseData.id,
                                  orderPosition: _exercises.length + 1,
                                  notes: null,
                                  syncStatus: 0,
                                ),
                                templates: [
                                  WorkoutSetTemplateData(
                                    id: tempId,
                                    workoutExerciseId: tempId,
                                    setNumber: 1,
                                    targetReps: '',
                                    orderPosition: 1,
                                    syncStatus: 0,
                                  ),
                                ],
                                previousSets: const {},
                                existingSets: const {},
                              );
                              setState(() => _exercises.add(newExercise));
                              setSheetState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _exercises.length,
                        itemBuilder: (context, index) {
                          final exercise = _exercises[index];
                          final isCurrent = index == _currentExerciseIndex;
                          final l10n = AppLocalizations.of(context)!;
                          final theme = Theme.of(context);
                          final partnerIdx = _supersetPartnerIndex(index);
                          final isInSuperset = partnerIdx != null;
                          final isSelected = supersetPickIndex == index;
                          final isPendingPartner =
                              supersetPickIndex != null && !isSelected;

                          // Chain connector drawn below an item when the next item is its superset partner
                          final showChainBelow =
                              index + 1 < _exercises.length &&
                              _exercises[index + 1].supersetGroupId != null &&
                              _exercises[index + 1].supersetGroupId ==
                                  exercise.supersetGroupId;

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                tileColor:
                                    isSelected
                                        ? theme.colorScheme.primaryContainer
                                        : isInSuperset
                                        ? theme.colorScheme.secondaryContainer
                                            .withValues(alpha: 0.4)
                                        : null,
                                leading: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CircleAvatar(
                                      backgroundColor:
                                          isCurrent
                                              ? theme.colorScheme.primary
                                              : isInSuperset
                                              ? theme.colorScheme.secondary
                                              : theme
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color:
                                              isCurrent || isInSuperset
                                                  ? Colors.white
                                                  : null,
                                        ),
                                      ),
                                    ),
                                    if (isInSuperset)
                                      Positioned(
                                        right: -4,
                                        top: -4,
                                        child: Icon(
                                          Icons.link,
                                          size: 14,
                                          color: theme.colorScheme.secondary,
                                        ),
                                      ),
                                  ],
                                ),
                                title: Text(
                                  exercise.exercise.localizedName(Localizations.localeOf(context).languageCode),
                                  style: TextStyle(
                                    fontWeight:
                                        isCurrent
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        l10n.setTemplatesCount(
                                          exercise.templates.length,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isInSuperset) ...[
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          l10n.superset,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: theme.colorScheme.secondary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing:
                                    isSelected
                                        ? Icon(
                                          Icons.link,
                                          color: theme.colorScheme.primary,
                                        )
                                        : null,
                                onTap: () {
                                  if (supersetPickIndex != null) {
                                    // Second selection — link as superset
                                    if (supersetPickIndex != index) {
                                      setState(() {
                                        // If either already has a group, break it first
                                        final existingGroupA =
                                            _exercises[supersetPickIndex!]
                                                .supersetGroupId;
                                        final existingGroupB =
                                            exercise.supersetGroupId;
                                        if (existingGroupA != null) {
                                          for (final e in _exercises) {
                                            if (e.supersetGroupId ==
                                                existingGroupA)
                                              e.supersetGroupId = null;
                                          }
                                        }
                                        if (existingGroupB != null) {
                                          for (final e in _exercises) {
                                            if (e.supersetGroupId ==
                                                existingGroupB)
                                              e.supersetGroupId = null;
                                          }
                                        }
                                        final groupId = _nextSupersetGroupId++;
                                        _exercises[supersetPickIndex!]
                                            .supersetGroupId = groupId;
                                        exercise.supersetGroupId = groupId;
                                      });
                                    }
                                    setSheetState(
                                      () => supersetPickIndex = null,
                                    );
                                  } else {
                                    _saveCurrentExercise();
                                    setState(() {
                                      _currentExerciseIndex = index;
                                      _currentSetIndex = 0;
                                    });
                                    Navigator.pop(sheetContext);
                                  }
                                },
                                onLongPress: () async {
                                  setSheetState(() => supersetPickIndex = null);
                                  final action = await showDialog<String>(
                                    context: sheetContext,
                                    builder:
                                        (ctx) => SimpleDialog(
                                          title: Text(exercise.exercise.localizedName(Localizations.localeOf(ctx).languageCode)),
                                          children: [
                                            if (isInSuperset)
                                              SimpleDialogOption(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      ctx,
                                                      'unlink',
                                                    ),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.link_off),
                                                    const SizedBox(width: 8),
                                                    Flexible(
                                                      child: Text(
                                                        l10n.removeSupersetLink,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            else
                                              SimpleDialogOption(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      ctx,
                                                      'superset',
                                                    ),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.link),
                                                    const SizedBox(width: 8),
                                                    Flexible(
                                                      child: Text(
                                                        l10n.superset,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            if (_exercises.length > 1)
                                              SimpleDialogOption(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      ctx,
                                                      'delete',
                                                    ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.delete,
                                                      color: Colors.red,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Flexible(
                                                      child: Text(
                                                        l10n.delete,
                                                        style: const TextStyle(
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                  );
                                  if (action == 'unlink') {
                                    final groupId = exercise.supersetGroupId;
                                    setState(() {
                                      for (final e in _exercises) {
                                        if (e.supersetGroupId == groupId)
                                          e.supersetGroupId = null;
                                      }
                                    });
                                    setSheetState(() {});
                                  } else if (action == 'superset') {
                                    setSheetState(
                                      () => supersetPickIndex = index,
                                    );
                                  } else if (action == 'delete') {
                                    setState(() {
                                      _exercises.removeAt(index);
                                      if (_currentExerciseIndex >=
                                          _exercises.length) {
                                        _currentExerciseIndex =
                                            _exercises.length - 1;
                                      }
                                      _currentSetIndex = 0;
                                    });
                                    setSheetState(() {});
                                  }
                                },
                              ),
                              if (showChainBelow)
                                Padding(
                                  padding: const EdgeInsets.only(left: 28),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.more_vert,
                                        size: 16,
                                        color: theme.colorScheme.secondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        l10n.superset,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: theme.colorScheme.secondary,
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: theme.colorScheme.secondary,
                                          thickness: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    if (supersetPickIndex != null)
                      Container(
                        color:
                            Theme.of(sheetContext).colorScheme.primaryContainer,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.link,
                              color: Theme.of(sheetContext).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                AppLocalizations.of(
                                  sheetContext,
                                )!.supersetPickHint,
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  () => setSheetState(
                                    () => supersetPickIndex = null,
                                  ),
                              child: Text(
                                AppLocalizations.of(sheetContext)!.cancel,
                              ),
                            ),
                          ],
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
                                exercise.exercise.localizedName(Localizations.localeOf(context).languageCode),
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
  List<WorkoutSetTemplateData> templates;
  final Map<int, WorkoutSetTableData> previousSets;
  final Map<int, WorkoutSetTableData> existingSets;
  int? scheduledExerciseId;
  int? supersetGroupId;
  _ExerciseWithSets({
    required this.exercise,
    required this.workoutExercise,
    required this.templates,
    required this.previousSets,
    this.scheduledExerciseId,
    required this.existingSets,
    this.supersetGroupId,
  });
}
