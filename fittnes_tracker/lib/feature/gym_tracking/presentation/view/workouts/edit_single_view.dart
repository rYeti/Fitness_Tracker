import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/di/service_locator.dart';
import 'package:ForgeForm/core/utils/app_logger.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout_exercise.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout_set.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/providers/scheduled_workout_provider.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/widgets/exercise_selection_modal.dart';

class EditSingleWorkoutView extends StatefulWidget {
  final int workoutId;
  const EditSingleWorkoutView({super.key, required this.workoutId});

  @override
  _EditSingleWorkoutViewState createState() => _EditSingleWorkoutViewState();
}

class _EditSingleWorkoutViewState extends State<EditSingleWorkoutView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();

  WorkoutDifficulty _difficulty = WorkoutDifficulty.beginner;
  Workout? _workout;
  bool _loading = true;
  bool _saving = false;
  bool _isReordering = false;

  int? _supersetPickIndex;
  int _nextSupersetGroupId = 1;

  @override
  void initState() {
    super.initState();
    _loadWorkout();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkout() async {
    final dao = sl<AppDatabase>().workoutDao;
    final workout = await dao.getCompleteWorkoutById(widget.workoutId);

    if (workout != null) {
      _nameController.text = workout.name;
      _descriptionController.text = workout.description ?? '';
      _durationController.text =
          workout.estimatedDurationMinutes?.toString() ?? '';
      _difficulty = workout.difficulty ?? WorkoutDifficulty.beginner;
      _workout = workout;
      _initSupersetGroupId();
    }

    setState(() => _loading = false);
  }

  void _initSupersetGroupId() {
    if (_workout == null) return;
    final maxGroupId = _workout!.exercises
        .map((e) => e.supersetGroupId ?? 0)
        .fold(0, (a, b) => a > b ? a : b);
    _nextSupersetGroupId = maxGroupId + 1;
  }

  void _handleSupersetTap(int index) {
    final l10n = AppLocalizations.of(context)!;
    final exercises = _workout!.exercises;
    final hasSuperset = exercises[index].supersetGroupId != null;

    if (_supersetPickIndex != null && _supersetPickIndex != index) {
      // Second pick: link both exercises into a new superset group
      setState(() {
        final groupId = _nextSupersetGroupId++;
        final a = exercises[_supersetPickIndex!];
        final b = exercises[index];
        if (a.supersetGroupId != null) _clearSupersetGroup(a.supersetGroupId!);
        if (b.supersetGroupId != null) _clearSupersetGroup(b.supersetGroupId!);
        final updated = List<WorkoutExercise>.from(_workout!.exercises);
        updated[_supersetPickIndex!] = updated[_supersetPickIndex!].copyWith(supersetGroupId: groupId);
        updated[index] = updated[index].copyWith(supersetGroupId: groupId);
        _supersetPickIndex = null;
        _rebuildWorkout(updated);
      });
      return;
    }

    showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(exercises[index].exercise?.localizedName(Localizations.localeOf(context).languageCode) ?? ''),
        children: [
          if (!hasSuperset)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'pick'),
              child: Row(children: [
                const Icon(Icons.link),
                const SizedBox(width: 8),
                Flexible(child: Text(l10n.superset)),
              ]),
            ),
          if (hasSuperset)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'unlink'),
              child: Row(children: [
                const Icon(Icons.link_off),
                const SizedBox(width: 8),
                Flexible(child: Text(l10n.removeSupersetLink)),
              ]),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: Row(children: [
              Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 8),
              Flexible(child: Text(l10n.delete)),
            ]),
          ),
        ],
      ),
    ).then((action) {
      if (action == 'pick') {
        setState(() => _supersetPickIndex = index);
      } else if (action == 'unlink') {
        setState(() {
          _clearSupersetGroup(exercises[index].supersetGroupId!);
        });
      } else if (action == 'delete') {
        setState(() {
          final groupId = exercises[index].supersetGroupId;
          if (groupId != null) _clearSupersetGroup(groupId);
          final updated = List<WorkoutExercise>.from(_workout!.exercises)
            ..removeAt(index);
          _rebuildWorkout(updated);
        });
      }
    });
  }

  void _clearSupersetGroup(int groupId) {
    final updated = _workout!.exercises.map((e) {
      if (e.supersetGroupId == groupId) {
        return e.copyWith(supersetGroupId: null);
      }
      return e;
    }).toList();
    _rebuildWorkout(updated);
  }

  void _rebuildWorkout(List<WorkoutExercise> exercises) {
    _workout = Workout(
      id: _workout!.id,
      name: _workout!.name,
      description: _workout!.description,
      difficulty: _workout!.difficulty,
      estimatedDurationMinutes: _workout!.estimatedDurationMinutes,
      isTemplate: _workout!.isTemplate,
      scheduledDate: _workout!.scheduledDate,
      completedDate: _workout!.completedDate,
      exercises: exercises,
    );
  }

  Future<void> _saveWorkout() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final dao = sl<AppDatabase>().workoutDao;
      final duration = int.tryParse(_durationController.text) ?? 30;

      final updatedExercises = <WorkoutExercise>[];
      for (final (index, exercise) in _workout!.exercises.indexed) {
        if (exercise.exerciseId == -1 && exercise.exercise != null) {
          final exerciseCompanion = ExerciseTableCompanion(
            name: Value(exercise.exercise!.name),
            description: Value('Added to workout'),
            type: Value(exercise.exercise!.type.index),
            targetMuscleGroups: Value(
              exercise.exercise!.targetMuscleGroups
                  .map((m) => m.index.toString())
                  .join(','),
            ),
            imageUrl: Value(exercise.exercise!.imageUrl),
            isCustom: Value(exercise.exercise!.isCustom),
          );

          final exerciseId = await sl<AppDatabase>().exerciseDao.saveExercise(
            exerciseCompanion,
          );
          updatedExercises.add(
            WorkoutExercise(
              id: exercise.id,
              workoutId: exercise.workoutId,
              exerciseId: exerciseId,
              orderPosition: index + 1,
              exercise: exercise.exercise,
              sets: exercise.sets,
              notes: exercise.notes,
              supersetGroupId: exercise.supersetGroupId,
            ),
          );
        } else {
          updatedExercises.add(
            WorkoutExercise(
              id: exercise.id,
              workoutId: exercise.workoutId,
              exerciseId: exercise.exerciseId,
              orderPosition: index + 1,
              exercise: exercise.exercise,
              sets: exercise.sets,
              notes: exercise.notes,
              supersetGroupId: exercise.supersetGroupId,
            ),
          );
        }
      }

      final updatedWorkout = Workout(
        id: widget.workoutId,
        name: _nameController.text,
        description: _descriptionController.text,
        difficulty: _difficulty,
        estimatedDurationMinutes: duration,
        isTemplate: true,
        exercises: updatedExercises,
      );

      await dao.saveCompleteWorkout(updatedWorkout);

      try {
        if (mounted) {
          context.read<ScheduleWorkoutProvider>().refresh();
        }
      } catch (e) {
        AppLogger.i('Failed to refresh ScheduleWorkoutProvider: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.workoutUpdatedSuccessfully,
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.saveFailed(e.toString()),
            ),
          ),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  void _onReorderExercises(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final exercises = List<WorkoutExercise>.from(_workout!.exercises);
    final moved = exercises.removeAt(oldIndex);
    exercises.insert(newIndex, moved);
    setState(() => _rebuildWorkout(exercises));
  }

  void _addExercise() async {
    final selectedExercise = await ExerciseSelectionModal.show(context);

    if (selectedExercise == null || _workout == null) return;

    final newExercise = WorkoutExercise(
      workoutId: _workout!.id!,
      exerciseId: selectedExercise.id ?? -1,
      orderPosition: _workout!.exercises.length + 1,
      exercise: selectedExercise,
      sets: [
        WorkoutSet(
          exerciseInstanceId: -1,
          setNumber: 1,
          reps: 10,
          weight: 0,
          weightUnit: 'kg',
          isCompleted: false,
        ),
      ],
      supersetGroupId: null,
    );

    setState(() {
      _rebuildWorkout([..._workout!.exercises, newExercise]);
    });
  }

  void _removeExercise(WorkoutExercise exercise) {
    if (_workout == null) return;

    setState(() {
      if (exercise.supersetGroupId != null) {
        _clearSupersetGroup(exercise.supersetGroupId!);
      }
      final updated = _workout!.exercises
          .where((e) => !identical(e, exercise))
          .toList();
      _rebuildWorkout(updated);
    });
  }

  void _addSetToExercise(WorkoutExercise exercise) {
    if (_workout == null) return;

    final newSet = WorkoutSet(
      exerciseInstanceId: exercise.id ?? 0,
      setNumber: exercise.sets.length + 1,
      targetReps: "8 - 12",
    );

    setState(() {
      final updated = _workout!.exercises.map((e) {
        if (identical(e, exercise)) {
          return e.copyWith(sets: [...e.sets, newSet]);
        }
        return e;
      }).toList();
      _rebuildWorkout(updated);
    });
  }

  void _removeSet(WorkoutSet set) {
    if (_workout == null) return;

    setState(() {
      final updated = _workout!.exercises.map((exercise) {
        if (exercise.sets.any((s) => identical(s, set))) {
          final remaining = exercise.sets
              .where((s) => !identical(s, set))
              .toList();
          // Re-sequence set numbers so display stays 1, 2, 3…
          final renumbered = remaining.asMap().entries.map((entry) {
            final s = entry.value;
            return WorkoutSet(
              id: s.id,
              exerciseInstanceId: s.exerciseInstanceId,
              setNumber: entry.key + 1,
              reps: s.reps,
              weight: s.weight,
              weightUnit: s.weightUnit,
              durationSeconds: s.durationSeconds,
              isCompleted: s.isCompleted,
              notes: s.notes,
              targetReps: s.targetReps,
            );
          }).toList();
          return exercise.copyWith(sets: renumbered);
        }
        return exercise;
      }).toList();
      _rebuildWorkout(updated);
    });
  }

  void _editSet(WorkoutSet set) {
    final l10n = AppLocalizations.of(context)!;

    final targetController = TextEditingController(text: set.targetReps ?? '');

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.editSet(set.setNumber)),
            content: TextField(
              controller: targetController,
              decoration: InputDecoration(
                labelText: l10n.targetReps,
                hintText: l10n.targetRepsHintLong,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () {
                  _updateSet(set, targetController.text.trim());
                  Navigator.pop(context);
                },
                child: Text(l10n.saveButton),
              ),
            ],
          ),
    );
  }

  void _updateSet(WorkoutSet oldSet, String targetReps) {
    if (_workout == null) return;

    setState(() {
      final updated = _workout!.exercises.map((exercise) {
        if (exercise.sets.any((s) => identical(s, oldSet))) {
          final updatedSets = exercise.sets.map((s) {
            if (identical(s, oldSet)) {
              return WorkoutSet(
                id: s.id,
                exerciseInstanceId: s.exerciseInstanceId,
                setNumber: s.setNumber,
                targetReps: targetReps,
              );
            }
            return s;
          }).toList();
          return exercise.copyWith(sets: updatedSets);
        }
        return exercise;
      }).toList();
      _rebuildWorkout(updated);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (_loading) {
      return SafeArea(child: Scaffold(
        appBar: AppBar(title: Text(l10n.editWorkout)),
        body: const Center(child: CircularProgressIndicator()),
      ));
    }

    return SafeArea(child: Scaffold(
      appBar: AppBar(
        title: Text(l10n.editWorkout),
        actions: [
          if (_supersetPickIndex != null)
            TextButton(
              onPressed: () => setState(() => _supersetPickIndex = null),
              child: Text(l10n.cancel, style: TextStyle(color: theme.colorScheme.error)),
            ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(icon: const Icon(Icons.save), onPressed: _saveWorkout),
        ],
      ),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            // ── Form fields ───────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(labelText: l10n.workoutName),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return l10n.pleaseEnterWorkoutName;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(labelText: l10n.description),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<WorkoutDifficulty>(
                    value: _difficulty,
                    decoration: InputDecoration(labelText: l10n.difficulty),
                    items: WorkoutDifficulty.values.map((difficulty) {
                      return DropdownMenuItem(
                        value: difficulty,
                        child: Text(difficulty.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _difficulty = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _durationController,
                    decoration: InputDecoration(
                      labelText: l10n.duration,
                      suffixText: l10n.minutesSuffix,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return l10n.pleaseEnterDuration;
                      }
                      final duration = int.tryParse(value!);
                      if (duration == null || duration <= 0) {
                        return l10n.pleaseEnterValidDuration;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.exercises,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_supersetPickIndex != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n.supersetPickHint,
                        style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                      ),
                    ),
                  if (_workout?.exercises.isEmpty ?? true)
                    Text(l10n.noExercisesInWorkout),
                ]),
              ),
            ),

            // ── Reorderable exercise list ─────────────────────────────────
            if (_workout?.exercises.isNotEmpty ?? false)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverReorderableList(
                  itemCount: _workout!.exercises.length,
                  onReorder: _onReorderExercises,
                  onReorderStart: (_) => setState(() => _isReordering = true),
                  onReorderEnd: (_) {
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (mounted) setState(() => _isReordering = false);
                    });
                  },
                  itemBuilder: (ctx, index) {
                    final items = _buildExerciseItems(theme, l10n);
                    return items[index];
                  },
                ),
              ),

            // ── Add exercise button ───────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: FilledButton.icon(
                  onPressed: _addExercise,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addExercise),
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  List<Widget> _buildExerciseItems(ThemeData theme, AppLocalizations l10n) {
    final items = <Widget>[];
    final exercises = _workout!.exercises;

    for (int index = 0; index < exercises.length; index++) {
      final exercise = exercises[index];
      final supersetGroupId = exercise.supersetGroupId;
      final showChainBelow = index + 1 < exercises.length &&
          supersetGroupId != null &&
          exercises[index + 1].supersetGroupId == supersetGroupId;
      final isPickCandidate = _supersetPickIndex == index;

      items.add(
        Column(
          key: ValueKey(exercise.id ?? exercise.hashCode),
          mainAxisSize: MainAxisSize.min,
          children: [
            Card(
              margin: EdgeInsets.only(bottom: showChainBelow ? 0 : 8),
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isPickCandidate
                      ? theme.colorScheme.tertiary
                      : supersetGroupId != null
                          ? theme.colorScheme.primary
                          : theme.dividerColor,
                  width: isPickCandidate || supersetGroupId != null ? 2 : 1,
                ),
              ),
              child: AbsorbPointer(
                absorbing: _isReordering,
                child: GestureDetector(
                  onLongPress: () => _handleSupersetTap(index),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    leading: ReorderableDelayedDragStartListener(
                      index: index,
                      child: const Icon(
                        Icons.drag_indicator,
                        color: Colors.grey,
                      ),
                    ),
                      title: Text(
                        exercise.exercise?.localizedName(Localizations.localeOf(context).languageCode) ?? l10n.unknownExercise,
                      ),
                      subtitle: Text(
                        '${exercise.sets.length} ${l10n.setsLabel}',
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${l10n.setsLabel}:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.add),
                                        onPressed:
                                            () => _addSetToExercise(exercise),
                                        tooltip: l10n.addSet,
                                      ),
                                      if (supersetGroupId != null)
                                        IconButton(
                                          icon: const Icon(Icons.link_off),
                                          onPressed: () => setState(
                                            () => _clearSupersetGroup(supersetGroupId),
                                          ),
                                          tooltip: l10n.removeSupersetLink,
                                        )
                                      else
                                        IconButton(
                                          icon: const Icon(Icons.link),
                                          onPressed: () => setState(
                                            () => _supersetPickIndex = index,
                                          ),
                                          tooltip: l10n.superset,
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed: () => _removeExercise(exercise),
                                        tooltip: l10n.delete,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${l10n.setsLabel} (${exercise.sets.length}):',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ...exercise.sets.map(
                                (set) => Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Set ${set.setNumber}: ${set.targetReps ?? "-"}',
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _editSet(set),
                                      tooltip: l10n.edit,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _removeSet(set),
                                      tooltip: l10n.delete,
                                    ),
                                  ],
                                ),
                              ),
                              if (exercise.sets.isEmpty)
                                Text(l10n.noSetsFound),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (showChainBelow)
              Padding(
                padding: const EdgeInsets.only(left: 28, bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.link, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      l10n.superset,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return items;
  }
}
