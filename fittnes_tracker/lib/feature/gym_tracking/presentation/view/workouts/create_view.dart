import 'package:drift/drift.dart' as drift hide Column;
import 'dart:convert';
import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/exercise.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/widgets/exercise_selection_modal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:ForgeForm/feature/gym_tracking/data/models/set_template.dart';

class CreateWorkoutView extends StatefulWidget {
  final List<DateTime>? selectedDates;

  const CreateWorkoutView({Key? key, this.selectedDates}) : super(key: key);

  @override
  State<CreateWorkoutView> createState() => _CreateWorkoutViewState();
}

class _CreateWorkoutViewState extends State<CreateWorkoutView> {
  final _workoutNameController = TextEditingController();
  int _currentStep = 0;

  List<String?> _cyclePattern = [];
  DateTime? _startDate = DateTime.now();

  // Map to store exercises for each workout name
  Map<String, List<(Exercise, List<SetTemplates>)>> _workoutExercises = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.createWorkout), elevation: 0),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(theme, l10n),

          // Content
          Expanded(child: _buildStepContent()),

          // Navigation buttons
          _buildNavigationBar(theme, l10n),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(ThemeData theme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        border: Border(bottom: BorderSide(color: theme.dividerColor, width: 1)),
      ),
      child: Row(
        children: List.generate(3, (index) {
          final isCompleted = index < _currentStep;
          final isCurrent = index == _currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color:
                              isCompleted || isCurrent
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.surfaceVariant,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                isCurrent
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child:
                              isCompleted
                                  ? Icon(
                                    Icons.check,
                                    color: theme.colorScheme.onPrimary,
                                    size: 18,
                                  )
                                  : Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color:
                                          isCurrent
                                              ? theme.colorScheme.onPrimary
                                              : theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [l10n.workoutName, l10n.stepCycle, l10n.stepStart][index],
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              isCurrent
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                          fontWeight: isCurrent ? FontWeight.bold : null,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < 2)
                  Container(
                    height: 2,
                    width: 24,
                    color:
                        isCompleted
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceVariant,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNavigationBar(ThemeData theme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _goBack,
                  icon: const Icon(Icons.arrow_back),
                  label: Text(l10n.back),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _nextOrSave,
                icon: Icon(
                  _currentStep == 2 ? Icons.check : Icons.arrow_forward,
                ),
                label: Text(_currentStep == 2 ? l10n.save : l10n.next),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor:
                      _currentStep == 2
                          ? Colors.green
                          : theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveWorkout() async {
    final l10n = AppLocalizations.of(context)!;
    final db = context.read<AppDatabase>();

    // Map to hold template IDs for workouts
    final Map<String, int> workoutMap = {};

    // Step 1️⃣: Save / ensure Rest Day template exists
    final existingRestDay = await db.workoutDao.getWorkoutByNameOrNull(
      "Rest Day",
    );
    if (existingRestDay == null) {
      final restWorkout = Workout(
        name: "Rest Day",
        isTemplate: true,
        exercises: [],
        difficulty: WorkoutDifficulty.beginner,
        estimatedDurationMinutes: 0,
      );
      final restId = await db.workoutDao.saveCompleteWorkout(restWorkout);
      workoutMap["Rest Day"] = restId;
    } else {
      workoutMap["Rest Day"] = existingRestDay.id;
    }

    // Step 2️⃣: Deactivate current active plans
    await (db.update(db.workoutPlanTable)..where(
      (t) => t.isActive.equals(true),
    )).write(WorkoutPlanTableCompanion(isActive: const drift.Value(false)));

    // Step 3️⃣: Create new workout plan
    final planCompanion = WorkoutPlanTableCompanion.insert(
      name: _workoutNameController.text.trim(),
      cyclePatternJson: jsonEncode(_cyclePattern),
      startDate: _startDate!,
      isActive: const drift.Value(true),
    );
    final planId = await db.into(db.workoutPlanTable).insert(planCompanion);

    // Step 4️⃣: Save templates for workouts (skip Rest Day)
    for (var workoutName
        in _cyclePattern.where((w) => w != "Rest Day").toSet()) {
      final exercises = _workoutExercises[workoutName] ?? [];

      final workoutTemplate = Workout(
        name: workoutName!,
        isTemplate: true,
        exercises: [],
        difficulty: WorkoutDifficulty.intermediate,
        estimatedDurationMinutes: 60,
      );

      final templateId = await db.workoutDao.saveCompleteWorkout(
        workoutTemplate,
      );
      workoutMap[workoutName] = templateId;

      await db
          .into(db.workoutPlanWorkoutTable)
          .insert(
            WorkoutPlanWorkoutTableCompanion(
              planId: drift.Value(planId),
              workoutId: drift.Value(templateId),
            ),
          );

      // Step 4a️⃣: Save exercises for this template
      for (int i = 0; i < exercises.length; i++) {
        final (exercise, sets) = exercises[i];

        final exerciseId =
            exercise.id ??
            await db.exerciseDao.saveExercise(
              db.exerciseDao.modelToEntity(exercise),
            );

        final workoutExerciseId = await db
            .into(db.workoutExerciseTable)
            .insert(
              WorkoutExerciseTableCompanion.insert(
                workoutId: templateId,
                exerciseId: exerciseId,
                orderPosition: i,
              ),
            );

        if (sets.isNotEmpty) {
          await db.batch((batch) {
            for (int setIndex = 0; setIndex < sets.length; setIndex++) {
              final set = sets[setIndex];
              batch.insert(
                db.workoutSetTemplateTable,
                WorkoutSetTemplateTableCompanion.insert(
                  workoutExerciseId: workoutExerciseId,
                  setNumber: set.setNumber,
                  targetReps: set.targetReps,
                  orderPosition: setIndex,
                ),
              );
            }
          });
        }
      }
    }

    // Step 5️⃣: Schedule workouts for 360 days
    for (int day = 0; day < 360; day++) {
      final date = _startDate!.add(Duration(days: day));
      final cycleIndex = day % _cyclePattern.length;
      final workoutName = _cyclePattern[cycleIndex];
      final templateId = workoutMap[workoutName]!;

      final scheduledWorkout = ScheduledWorkoutTableCompanion.insert(
        workoutId: templateId,
        templateWorkoutId: drift.Value(templateId),
        scheduledDate: date,
        workoutPlanId: drift.Value(planId),
      );

      await db.scheduledWorkoutDao.scheduleWorkout(scheduledWorkout);
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.workoutSavedSuccessfully)));
    await Future.delayed(const Duration(milliseconds: 500));
    if (context.mounted) Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _workoutNameController.dispose();
    super.dispose();
  }

  void _goBack() {
    setState(() {
      if (_currentStep > 0) {
        _currentStep--;
      }
    });
  }

  void _nextOrSave() {
    final l10n = AppLocalizations.of(context)!;
    if (_currentStep == 0) {
      if (_workoutNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.pleaseEnterWorkoutName)));
        return;
      }
    } else if (_currentStep == 1) {
      if (_cyclePattern.isEmpty ||
          _cyclePattern.every((element) => element == "Rest Day")) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pleaseEnterAtLeastOneWorkoutDay)),
        );
        return;
      }
    } else if (_currentStep == 2) {
      if (_startDate == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.pleaseSelectStartDate)));
        return;
      }
    }
    setState(() {
      if (_currentStep < 2) {
        _currentStep++;
      } else {
        _saveWorkout();
      }
    });
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildWorkoutNameStep();
      case 1:
        return _buildCyclePatternStep();
      case 2:
        return _buildDateSelectionStep();
      default:
        return Container();
    }
  }

  Widget _buildWorkoutNameStep() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Center(
            child: Icon(
              Icons.fitness_center,
              size: 64,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.nameYourWorkoutPlan,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.chooseMemorableName,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _workoutNameController,
            decoration: InputDecoration(
              labelText: l10n.workoutName,
              hintText: l10n.workoutPlanNameHint,
              prefixIcon: const Icon(Icons.edit),
              border: const OutlineInputBorder(),
              filled: true,
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCyclePatternStep() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Stack(
      children: [
        Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              child: Row(
                children: [
                  Icon(Icons.calendar_month, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.buildYourCycle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          l10n.dayCycleLength(_cyclePattern.length),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Workout list with drag and drop
            Expanded(
              child:
                  _cyclePattern.isEmpty
                      ? _buildEmptyState(theme, l10n)
                      : ReorderableListView.builder(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 16,
                          bottom: 88, // Space for FAB
                        ),
                        itemCount: _cyclePattern.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) {
                              newIndex -= 1;
                            }
                            final item = _cyclePattern.removeAt(oldIndex);
                            _cyclePattern.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final entry = _cyclePattern[index];
                          final isRestDay = entry == "Rest Day";

                          return _WorkoutDayCard(
                            key: ValueKey('$entry-$index'),
                            dayNumber: index + 1,
                            workoutName: entry!,
                            isRestDay: isRestDay,
                            exerciseCount:
                                _workoutExercises[entry]?.length ?? 0,
                            onTap: () {
                              if (!isRestDay) {
                                _showWorkoutDetails(entry);
                              }
                            },
                            onDelete: () {
                              setState(() {
                                _cyclePattern.removeAt(index);
                                if (!isRestDay) {
                                  _workoutExercises.remove(entry);
                                }
                              });
                            },
                          );
                        },
                      ),
            ),
          ],
        ),

        // Floating Action Button with Speed Dial
        Positioned(
          right: 16,
          bottom: 16,
          child: _AddDaySpeedDial(
            onAddWorkout: _addWorkout,
            onAddRestDay: _addRestDay,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noWorkoutsAddedYet,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.addWorkoutsToBuildCycle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _showWorkoutDetails(String workoutName) {
    final l10n = AppLocalizations.of(context)!;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => _WorkoutDetailsScreen(
              workoutName: workoutName,
              exercises: _workoutExercises[workoutName] ?? [],
              onExercisesChanged: (exercises) {
                setState(() {
                  _workoutExercises[workoutName] = exercises;
                });
              },
            ),
      ),
    );
  }

  void _addWorkout() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        Theme.of(context);
        return AlertDialog(
          title: Text(l10n.workoutNameLabel),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: l10n.workoutDayHint,
              border: const OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: Text(l10n.add),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _cyclePattern.add(result);
        _workoutExercises[result] = [];
      });
    }
  }

  void _addRestDay() {
    setState(() {
      _cyclePattern.add("Rest Day");
    });
  }

  Widget _buildDateSelectionStep() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Center(
            child: Icon(
              Icons.event,
              size: 64,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.chooseStartDate,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.whenToBeginProgram,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          Card(
            child: InkWell(
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: _startDate ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime(2100),
                );
                if (pickedDate != null) {
                  setState(() {
                    _startDate = pickedDate;
                  });
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.calendar_today,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.startDateLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _startDate == null
                                ? l10n.selectStartDate
                                : DateFormat(
                                  'EEEE, MMMM d, yyyy',
                                ).format(_startDate!),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.secondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.scheduledForNextDays,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Workout Day Card Widget
class _WorkoutDayCard extends StatelessWidget {
  final int dayNumber;
  final String workoutName;
  final bool isRestDay;
  final int exerciseCount;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _WorkoutDayCard({
    super.key,
    required this.dayNumber,
    required this.workoutName,
    required this.isRestDay,
    required this.exerciseCount,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.dividerColor, width: 1),
        ),
        child: InkWell(
          onTap: isRestDay ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Drag handle
                Icon(
                  Icons.drag_handle,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),

                // Day number badge
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$dayNumber',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Icon
                Icon(
                  isRestDay ? Icons.hotel : Icons.fitness_center,
                  color:
                      isRestDay
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workoutName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!isRestDay)
                        Text(
                          exerciseCount == 0
                              ? l10n.noExercisesCount
                              : l10n.exerciseCount(exerciseCount),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),

                // Arrow for workouts
                if (!isRestDay)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),

                const SizedBox(width: 8),

                // Delete button
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Workout Details Screen (for editing exercises)
class _WorkoutDetailsScreen extends StatefulWidget {
  final String workoutName;
  final List<(Exercise, List<SetTemplates>)> exercises;
  final Function(List<(Exercise, List<SetTemplates>)>) onExercisesChanged;

  const _WorkoutDetailsScreen({
    required this.workoutName,
    required this.exercises,
    required this.onExercisesChanged,
  });

  @override
  State<_WorkoutDetailsScreen> createState() => _WorkoutDetailsScreenState();
}

class _WorkoutDetailsScreenState extends State<_WorkoutDetailsScreen> {
  late List<(Exercise, List<SetTemplates>)> _exercises;

  @override
  void initState() {
    super.initState();
    _exercises = List.from(widget.exercises);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workoutName),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              widget.onExercisesChanged(_exercises);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body:
          _exercises.isEmpty
              ? _buildEmptyState(theme, l10n)
              : ReorderableListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _exercises.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final item = _exercises.removeAt(oldIndex);
                    _exercises.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  return _ExerciseCard(
                    key: ValueKey(_exercises[index].$1.name + index.toString()),
                    exercise: _exercises[index].$1,
                    sets: _exercises[index].$2,
                    exerciseNumber: index + 1,
                    onSetsChanged: (newSets) {
                      setState(() {
                        _exercises[index] = (_exercises[index].$1, newSets);
                      });
                    },
                    onDelete: () {
                      setState(() {
                        _exercises.removeAt(index);
                      });
                    },
                  );
                },
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExercise,
        icon: const Icon(Icons.add),
        label: Text(l10n.addExercise),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noExercisesYet,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.tapButtonToAddExercises,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addExercise() async {
    final exercise = await ExerciseSelectionModal.show(context);

    if (exercise != null) {
      setState(() {
        _exercises.add((exercise, []));
      });
    }
  }
}

// Exercise Card Widget
class _ExerciseCard extends StatefulWidget {
  final Exercise exercise;
  final List<SetTemplates> sets;
  final int exerciseNumber;
  final Function(List<SetTemplates>) onSetsChanged;
  final VoidCallback onDelete;

  const _ExerciseCard({
    super.key,
    required this.exercise,
    required this.sets,
    required this.exerciseNumber,
    required this.onSetsChanged,
    required this.onDelete,
  });

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  bool _isExpanded = false;
  late List<SetTemplates> _sets;
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _sets = List.from(widget.sets);
    _controllers =
        _sets
            .map((set) => TextEditingController(text: set.targetReps))
            .toList();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _notifyParent() {
    final updatedSets = List.generate(
      _sets.length,
      (i) => SetTemplates(
        setNumber: i + 1,
        targetRange: _sets[i].targetRange,
        targetReps: _controllers[i].text.trim(),
      ),
    );
    widget.onSetsChanged(updatedSets);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.dividerColor),
        ),
        child: Column(
          children: [
            // Header
            InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Drag handle
                    Icon(
                      Icons.drag_handle,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),

                    // Exercise number
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${widget.exerciseNumber}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Exercise info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.exercise.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _sets.isEmpty
                                ? 'No sets configured'
                                : '${_sets.length} set${_sets.length == 1 ? '' : 's'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Expand icon
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),

                    const SizedBox(width: 8),

                    // Delete button
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.error,
                      ),
                      onPressed: widget.onDelete,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),

            // Expanded content
            if (_isExpanded) ...[
              Divider(height: 1, color: theme.dividerColor),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Exercise description
                    if (widget.exercise.description != null &&
                        widget.exercise.description!.isNotEmpty) ...[
                      Text(
                        widget.exercise.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Divider(height: 1, color: theme.dividerColor),
                      const SizedBox(height: 16),
                    ],

                    // Sets header
                    Row(
                      children: [
                        Icon(
                          Icons.format_list_numbered,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sets Configuration',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Sets list
                    if (_sets.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No sets added yet',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    else
                      ..._sets.asMap().entries.map((entry) {
                        final index = entry.key;
                        final set = entry.value;
                        final controller = _controllers[index];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${set.setNumber}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: controller,
                                  decoration: InputDecoration(
                                    labelText: 'Target Reps',
                                    hintText: 'e.g., 8-12',
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                  onChanged: (value) => _notifyParent(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: theme.colorScheme.error,
                                  size: 20,
                                ),
                                onPressed: () => _removeSet(index),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        );
                      }),

                    const SizedBox(height: 8),

                    // Add set button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _addSet,
                        icon: const Icon(Icons.add),
                        label: Text(l10n.addSet),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
  }

  void _addSet() {
    setState(() {
      final newSetNumber = _sets.length + 1;
      _sets.add(
        SetTemplates(setNumber: newSetNumber, targetRange: '', targetReps: ''),
      );
      _controllers.add(TextEditingController());
      _notifyParent();
    });
  }

  void _removeSet(int index) {
    if (_sets.length > 0) {
      setState(() {
        _sets.removeAt(index);
        _controllers[index].dispose();
        _controllers.removeAt(index);

        // Renumber sets
        for (int i = 0; i < _sets.length; i++) {
          _sets[i] = SetTemplates(
            setNumber: i + 1,
            targetRange: _sets[i].targetRange,
            targetReps: _sets[i].targetReps,
          );
        }
        _notifyParent();
      });
    }
  }
}

// Speed Dial for adding workout days
class _AddDaySpeedDial extends StatefulWidget {
  final VoidCallback onAddWorkout;
  final VoidCallback onAddRestDay;

  const _AddDaySpeedDial({
    required this.onAddWorkout,
    required this.onAddRestDay,
  });

  @override
  State<_AddDaySpeedDial> createState() => _AddDaySpeedDialState();
}

class _AddDaySpeedDialState extends State<_AddDaySpeedDial>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.125, // 45 degrees (1/8 turn)
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Rest Day option
        if (_isOpen) ...[
          ScaleTransition(
            scale: _scaleAnimation,
            child: _buildSpeedDialOption(
              icon: Icons.hotel,
              label: l10n.addRestDay,
              backgroundColor: theme.colorScheme.secondaryContainer,
              foregroundColor: theme.colorScheme.onSecondaryContainer,
              onTap: () {
                _toggle();
                widget.onAddRestDay();
              },
            ),
          ),
          const SizedBox(height: 12),

          // Workout option
          ScaleTransition(
            scale: _scaleAnimation,
            child: _buildSpeedDialOption(
              icon: Icons.fitness_center,
              label: l10n.addWorkout,
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              onTap: () {
                _toggle();
                widget.onAddWorkout();
              },
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Main FAB
        FloatingActionButton(
          onPressed: _toggle,
          child: RotationTransition(
            turns: _rotationAnimation,
            child: Icon(_isOpen ? Icons.close : Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedDialOption({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
    required VoidCallback onTap,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(8),
          color: backgroundColor.withOpacity(0.9),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                label,
                style: TextStyle(
                  color: foregroundColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Icon button
        Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          color: backgroundColor,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: foregroundColor),
            ),
          ),
        ),
      ],
    );
  }
}
