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
      // Pre-populate form fields with existing workout metadata
      _nameController.text = workout.name;
      _descriptionController.text = workout.description ?? '';
      _durationController.text =
          workout.estimatedDurationMinutes?.toString() ?? '';
      _difficulty = workout.difficulty ?? WorkoutDifficulty.beginner;
      _workout = workout;
    }

    setState(() => _loading = false);
  }

  Future<void> _saveWorkout() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final dao = sl<AppDatabase>().workoutDao;
      final duration = int.tryParse(_durationController.text) ?? 30;

      // First, ensure all exercises exist in the database.
      // Also assign orderPosition based on current list order (drag-reorder
      // kept original objects intact, so orderPosition may be stale here).
      final updatedExercises = <WorkoutExercise>[];
      for (final (index, exercise) in _workout!.exercises.indexed) {
        if (exercise.exerciseId == -1 && exercise.exercise != null) {
          // This is a new exercise that needs to be created
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

      // Refresh scheduled workouts provider so the scheduled view reflects edits immediately
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
    // Keep the same WorkoutExercise objects so their keys stay stable and
    // ExpansionTile state is preserved. orderPosition is corrected at save time.
    setState(() {
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
    });
  }

  void _addExercise() async {
    // Use the same exercise selection modal as the create view
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
    );

    setState(() {
      _workout = Workout(
        id: _workout!.id,
        name: _workout!.name,
        description: _workout!.description,
        difficulty: _workout!.difficulty,
        estimatedDurationMinutes: _workout!.estimatedDurationMinutes,
        isTemplate: _workout!.isTemplate,
        scheduledDate: _workout!.scheduledDate,
        completedDate: _workout!.completedDate,
        exercises: [..._workout!.exercises, newExercise],
      );
    });
  }

  void _removeExercise(WorkoutExercise exercise) {
    if (_workout == null) return;

    setState(() {
      _workout = Workout(
        id: _workout!.id,
        name: _workout!.name,
        description: _workout!.description,
        difficulty: _workout!.difficulty,
        estimatedDurationMinutes: _workout!.estimatedDurationMinutes,
        isTemplate: _workout!.isTemplate,
        scheduledDate: _workout!.scheduledDate,
        completedDate: _workout!.completedDate,
        exercises:
            _workout!.exercises.where((e) => e.id != exercise.id).toList(),
      );
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
      final updatedExercises =
          _workout!.exercises.map((e) {
            if (e.id == exercise.id) {
              return WorkoutExercise(
                id: e.id,
                workoutId: e.workoutId,
                exerciseId: e.exerciseId,
                orderPosition: e.orderPosition,
                exercise: e.exercise,
                sets: [...e.sets, newSet],
                notes: e.notes,
              );
            }
            return e;
          }).toList();

      _workout = Workout(
        id: _workout!.id,
        name: _workout!.name,
        description: _workout!.description,
        difficulty: _workout!.difficulty,
        estimatedDurationMinutes: _workout!.estimatedDurationMinutes,
        isTemplate: _workout!.isTemplate,
        scheduledDate: _workout!.scheduledDate,
        completedDate: _workout!.completedDate,
        exercises: updatedExercises,
      );
    });
  }

  void _removeSet(WorkoutSet set) {
    if (_workout == null) return;

    setState(() {
      final updatedExercises =
          _workout!.exercises.map((exercise) {
            // Use object identity so that unsaved sets (id == null) are not
            // confused with one another across different exercises.
            if (exercise.sets.any((s) => identical(s, set))) {
              return WorkoutExercise(
                id: exercise.id,
                workoutId: exercise.workoutId,
                exerciseId: exercise.exerciseId,
                orderPosition: exercise.orderPosition,
                exercise: exercise.exercise,
                sets: exercise.sets.where((s) => !identical(s, set)).toList(),
                notes: exercise.notes,
              );
            }
            return exercise;
          }).toList();

      _workout = Workout(
        id: _workout!.id,
        name: _workout!.name,
        description: _workout!.description,
        difficulty: _workout!.difficulty,
        estimatedDurationMinutes: _workout!.estimatedDurationMinutes,
        isTemplate: _workout!.isTemplate,
        scheduledDate: _workout!.scheduledDate,
        completedDate: _workout!.completedDate,
        exercises: updatedExercises,
      );
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
      final updatedExercises =
          _workout!.exercises.map((exercise) {
            if (exercise.sets.any((s) => identical(s, oldSet))) {
              final updatedSets =
                  exercise.sets.map((s) {
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

              return WorkoutExercise(
                id: exercise.id,
                workoutId: exercise.workoutId,
                exerciseId: exercise.exerciseId,
                orderPosition: exercise.orderPosition,
                exercise: exercise.exercise,
                sets: updatedSets,
                notes: exercise.notes,
              );
            }
            return exercise;
          }).toList();

      _workout = Workout(
        id: _workout!.id,
        name: _workout!.name,
        description: _workout!.description,
        difficulty: _workout!.difficulty,
        estimatedDurationMinutes: _workout!.estimatedDurationMinutes,
        isTemplate: _workout!.isTemplate,
        scheduledDate: _workout!.scheduledDate,
        completedDate: _workout!.completedDate,
        exercises: updatedExercises,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
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
              items:
                  WorkoutDifficulty.values.map((difficulty) {
                    return DropdownMenuItem(
                      value: difficulty,
                      child: Text(difficulty.name),
                    );
                  }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _difficulty = value);
                }
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_workout?.exercises.isEmpty ?? true)
              Text(l10n.noExercisesInWorkout)
            else
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: _onReorderExercises,
                buildDefaultDragHandles: false,
                onReorderStart: (_) => setState(() => _isReordering = true),
                onReorderEnd: (_) {
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted) setState(() => _isReordering = false);
                  });
                },
                children:
                    _workout!.exercises.asMap().entries.map((entry) {
                      final index = entry.key;
                      final exercise = entry.value;
                      return ReorderableDelayedDragStartListener(
                        key: ValueKey(exercise.id ?? exercise.hashCode),
                        index: index,
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: AbsorbPointer(
                            absorbing: _isReordering,
                            child: ExpansionTile(
                              initiallyExpanded: true,
                              leading: const Icon(
                                Icons.drag_indicator,
                                color: Colors.grey,
                              ),
                              title: Text(
                                exercise.exercise?.name ?? l10n.unknownExercise,
                              ),
                              subtitle: Text(
                                '${exercise.sets.length} ${l10n.setsLabel}',
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                                    () => _addSetToExercise(
                                                      exercise,
                                                    ),
                                                tooltip: l10n.addSet,
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete),
                                                onPressed:
                                                    () => _removeExercise(
                                                      exercise,
                                                    ),
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
                      );
                    }).toList(),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _addExercise,
              icon: const Icon(Icons.add),
              label: Text(l10n.addExercise),
            ),
          ],
        ),
      ),
    ));
  }
}
