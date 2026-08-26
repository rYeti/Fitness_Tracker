import 'package:drift/drift.dart' as drift hide Column;
import 'dart:convert';
import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/core/forge_motion.dart';
import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/di/service_locator.dart';
import 'package:ForgeForm/core/providers/access_provider.dart';
import 'package:ForgeForm/core/services/notification_service.dart';
import 'package:ForgeForm/feature/premium/paywall_launcher.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/exercise.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/widgets/exercise_selection_modal.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/widgets/expandable_description.dart';
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
  bool _isSaving = false;

  List<String?> _cyclePattern = [];
  DateTime? _startDate = DateTime.now();
  bool _isFreeChoice = false;
  int _durationWeeks = 12;

  // Map to store exercises for each workout name (exercise, sets, supersetGroupId)
  Map<String, List<(Exercise, List<SetTemplates>, int?)>> _workoutExercises = {};

  // Map to store the chosen color (ARGB int) per workout name.
  // 'Rest Day' gets a default grey.
  final Map<String, int> _workoutColors = {'Rest Day': 0xFF9E9E9E};

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
        children: List.generate(_isFreeChoice ? 2 : 3, (index) {
          final isCompleted = index < _currentStep;
          final isCurrent = index == _currentStep;
          final stepLabels = _isFreeChoice
              ? [l10n.workoutName, l10n.stepCycle]
              : [l10n.workoutName, l10n.stepCycle, l10n.stepStart];
          final totalSteps = stepLabels.length;

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
                        stepLabels[index],
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
                if (index < totalSteps - 1)
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
    final mq = MediaQuery.of(context);
    // Only add bottom system inset when the keyboard is hidden. When the
    // keyboard is visible the Scaffold has already shrunk the body upward, so
    // adding padding.bottom again causes a RenderFlex overflow.
    final bottomPadding =
        mq.viewInsets.bottom == 0 ? mq.padding.bottom : 0.0;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
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
                onPressed: _isSaving ? null : _nextOrSave,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _isLastStep ? Icons.check : Icons.arrow_forward,
                      ),
                label: Text(_isLastStep ? l10n.save : l10n.next),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor:
                      _isLastStep
                          ? ForgeColors.statusOkFor(Theme.of(context).brightness)
                          : theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
    );
  }

  Future<void> _saveWorkout() async {
    final l10n = AppLocalizations.of(context)!;
    final db = context.read<AppDatabase>();

    // Map to hold template IDs for workouts
    final Map<String, int> workoutMap = {};

    // Step 1️⃣: Save / ensure Rest Day template exists (cycle mode only)
    if (!_isFreeChoice) {
      final existingRestDay = await db.workoutDao.getWorkoutByNameOrNull(
        "Rest Day",
      );
      late int restDayId;
      if (existingRestDay == null) {
        final restWorkout = Workout(
          name: "Rest Day",
          isTemplate: true,
          exercises: [],
          difficulty: WorkoutDifficulty.beginner,
          estimatedDurationMinutes: 0,
        );
        restDayId = await db.workoutDao.saveCompleteWorkout(restWorkout);
        workoutMap["Rest Day"] = restDayId;
      } else {
        restDayId = existingRestDay.id;
        workoutMap["Rest Day"] = restDayId;
      }
      // Always update the Rest Day color (user may have changed it).
      final restColor = _workoutColors['Rest Day'];
      if (restColor != null) {
        await (db.update(db.workoutTable)..where(
          (t) => t.id.equals(restDayId),
        )).write(WorkoutTableCompanion(color: drift.Value(restColor)));
      }
    }

    // Step 2️⃣: Deactivate current active plans
    await (db.update(db.workoutPlanTable)..where(
      (t) => t.isActive.equals(true),
    )).write(WorkoutPlanTableCompanion(isActive: const drift.Value(false)));

    // Step 3️⃣: Create new workout plan
    final planCompanion = WorkoutPlanTableCompanion.insert(
      name: _workoutNameController.text.trim(),
      cyclePatternJson: _isFreeChoice ? '[]' : jsonEncode(_cyclePattern),
      startDate: _startDate!,
      isActive: const drift.Value(true),
      isFreeChoice: drift.Value(_isFreeChoice),
    );
    final planId = await db.into(db.workoutPlanTable).insert(planCompanion);
    if (!_isFreeChoice) {
      await (db.update(db.workoutPlanTable)
            ..where((t) => t.id.equals(planId)))
          .write(
            WorkoutPlanTableCompanion(
              durationDays: drift.Value(_durationWeeks * 7),
            ),
          );
    }

    // Step 4️⃣: Save templates for workouts
    final workoutNames = _isFreeChoice
        ? _workoutExercises.keys.toList()
        : _cyclePattern.where((w) => w != "Rest Day").toSet().toList();

    for (var workoutName in workoutNames) {
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

      // Persist the chosen color onto the template workout row.
      final chosenColor = _workoutColors[workoutName];
      if (chosenColor != null) {
        await (db.update(db.workoutTable)..where(
          (t) => t.id.equals(templateId),
        )).write(WorkoutTableCompanion(color: drift.Value(chosenColor)));
      }

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
        final (exercise, sets, supersetGroupId) = exercises[i];

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
                supersetGroupId: drift.Value(supersetGroupId),
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

    // Step 5️⃣: Schedule workouts for the chosen duration (cycle mode only)
    if (!_isFreeChoice) {
      for (int day = 0; day < _durationWeeks * 7; day++) {
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
    }

    if (!_isFreeChoice) {
      final planEndDate = _startDate!.add(Duration(days: _durationWeeks * 7));
      try {
        await sl<NotificationService>().schedulePlanExpiryWarning(
          planName: _workoutNameController.text.trim(),
          planEndDate: planEndDate,
        );
      } catch (_) {
        // Exact alarm permission not granted — notification skipped, save continues.
      }
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.workoutSavedSuccessfully)));
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _workoutNameController.dispose();
    super.dispose();
  }

  bool get _isLastStep =>
      (_isFreeChoice && _currentStep == 1) || _currentStep == 2;

  void _goBack() {
    setState(() {
      if (_currentStep > 0) {
        _currentStep--;
      }
    });
  }

  Future<void> _nextOrSave() async {
    if (_isSaving) return;
    final l10n = AppLocalizations.of(context)!;
    if (_currentStep == 0) {
      if (_workoutNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.pleaseEnterWorkoutName)));
        return;
      }
    } else if (_currentStep == 1) {
      if (_isFreeChoice) {
        if (_workoutExercises.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.pleaseEnterAtLeastOneWorkoutDay)),
          );
          return;
        }
      } else {
        if (_cyclePattern.isEmpty ||
            _cyclePattern.every((element) => element == "Rest Day")) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.pleaseEnterAtLeastOneWorkoutDay)),
          );
          return;
        }
      }
    } else if (_currentStep == 2) {
      if (_startDate == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.pleaseSelectStartDate)));
        return;
      }
    }
    if (_isLastStep) {
      setState(() => _isSaving = true);
      try {
        await _saveWorkout();
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.saveFailed(e.toString()))),
          );
        }
      }
    } else {
      // Dismiss the keyboard (open from step 0's autofocus) before showing
      // the next step, otherwise the reduced body height causes overflow.
      FocusScope.of(context).unfocus();
      setState(() => _currentStep++);
    }
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

    // SingleChildScrollView wraps the entire step so all fixed items
    // (mode selector, duration picker, cycle header) plus the list scroll as
    // one unit when the keyboard reduces the available height.
    // Lists use shrinkWrap+NeverScrollableScrollPhysics so they size to their
    // content inside the outer scroll view.
    // (hasScrollableList variable removed — no longer needed)

    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mode selector — compact segmented button replaces tall cards
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<bool>(
                        segments: [
                          ButtonSegment<bool>(
                            value: false,
                            label: Text(l10n.cyclePattern),
                            icon: const Icon(Icons.repeat),
                          ),
                          ButtonSegment<bool>(
                            value: true,
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(l10n.freeChoiceLabel),
                                if (!context
                                    .read<AccessProvider>()
                                    .hasPremiumAccess) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.lock,
                                    size: 12,
                                    color: theme.colorScheme.primary,
                                  ),
                                ],
                              ],
                            ),
                            icon: const Icon(Icons.shuffle),
                          ),
                        ],
                        selected: {_isFreeChoice},
                        onSelectionChanged: (selected) {
                          final wantFree = selected.first;
                          if (wantFree &&
                              !context
                                  .read<AccessProvider>()
                                  .hasPremiumAccess) {
                            openPaywall(context);
                            return;
                          }
                          setState(() => _isFreeChoice = wantFree);
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isFreeChoice
                          ? l10n.freeChoiceModeSubtitle
                          : l10n.cycleModeSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.dividerColor),

              // Duration picker (cycle mode only)
              if (!_isFreeChoice) _buildDurationPicker(theme, l10n),

              // Workout list / empty state.
              // Lists use shrinkWrap so they size to content inside the
              // outer SingleChildScrollView instead of needing Expanded.
              if (_isFreeChoice)
                _buildFreeChoiceList(theme, l10n)
              else if (_cyclePattern.isEmpty)
                _buildEmptyState(theme, l10n)
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 88,
                  ),
                  itemCount: _cyclePattern.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
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
                      exerciseCount: _workoutExercises[entry]?.length ?? 0,
                      workoutColor: _workoutColors[entry],
                      onTap: () {
                        if (!isRestDay) _showWorkoutDetails(entry);
                      },
                      onDelete: () {
                        setState(() {
                          _cyclePattern.removeAt(index);
                          if (!isRestDay) {
                            _workoutExercises.remove(entry);
                          }
                        });
                      },
                      onColorChanged: (color) {
                        setState(() => _workoutColors[entry] = color);
                      },
                    );
                  },
                ),
            ],
          ),
        ),

        // FAB — free choice shows simple add; cycle shows speed dial
        Positioned(
          right: 16,
          bottom: 16,
          child: _isFreeChoice
              ? FloatingActionButton.extended(
                  onPressed: _addWorkout,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addWorkout),
                )
              : _AddDaySpeedDial(
                  onAddWorkout: _addWorkout,
                  onAddRestDay: _addRestDay,
                ),
        ),
      ],
    );
  }

  Widget _buildDurationPicker(ThemeData theme, AppLocalizations l10n) {
    final hasPremium = context.read<AccessProvider>().hasPremiumAccess;
    const freeOptions = [4, 8, 12];
    const premiumOptions = [26, 52];
    final allOptions = [...freeOptions, ...premiumOptions];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.planDurationLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: allOptions.map((weeks) {
              final isPremiumOption = premiumOptions.contains(weeks);
              final isLocked = isPremiumOption && !hasPremium;
              final isSelected = _durationWeeks == weeks;
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.nWeeks(weeks)),
                    if (isLocked) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.lock, size: 14),
                    ],
                  ],
                ),
                selected: isSelected,
                onSelected: (_) {
                  if (isLocked) {
                    openPaywall(context);
                    return;
                  }
                  setState(() => _durationWeeks = weeks);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeChoiceList(ThemeData theme, AppLocalizations l10n) {
    if (_workoutExercises.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              l10n.noWorkoutsAddedYet,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.freeChoiceAddHint,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    final names = _workoutExercises.keys.toList();
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 88),
      itemCount: names.length,
      itemBuilder: (context, index) {
        final name = names[index];
        final exCount = _workoutExercises[name]?.length ?? 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: ListTile(
            leading:
                const Icon(Icons.fitness_center),
            title: Text(name,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Text(
              exCount == 0
                  ? l10n.noExercisesCount
                  : l10n.exerciseCount(exCount),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showWorkoutDetails(name),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: theme.colorScheme.error),
                  onPressed: () =>
                      setState(() => _workoutExercises.remove(name)),
                ),
              ],
            ),
            onTap: () => _showWorkoutDetails(name),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
            textAlign: TextAlign.center,
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

    // Dismiss any lingering keyboard from the dialog's autofocused TextField.
    if (mounted) FocusScope.of(context).unfocus();

    if (result != null && result.isNotEmpty) {
      setState(() {
        if (!_isFreeChoice) _cyclePattern.add(result);
        _workoutExercises[result] ??= [];
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
  final int? workoutColor;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<int> onColorChanged;

  const _WorkoutDayCard({
    super.key,
    required this.dayNumber,
    required this.workoutName,
    required this.isRestDay,
    required this.exerciseCount,
    this.workoutColor,
    required this.onTap,
    required this.onDelete,
    required this.onColorChanged,
  });

  static const List<int> _presetColors = [
    0xFFE53935, // red
    0xFFE91E63, // pink
    0xFF9C27B0, // purple
    0xFF3F51B5, // indigo
    0xFF2196F3, // blue
    0xFF00BCD4, // cyan
    0xFF009688, // teal
    0xFF4CAF50, // green
    0xFF8BC34A, // light green
    0xFFCDDC39, // lime
    0xFFFFEB3B, // yellow
    0xFFFF9800, // orange
    0xFFFF5722, // deep orange
    0xFF795548, // brown
    0xFF9E9E9E, // grey
    0xFF607D8B, // blue grey
  ];

  void _showColorPicker(BuildContext context) {
    showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(workoutName),
        content: SizedBox(
          width: 280,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _presetColors.map((colorValue) {
              final isSelected = workoutColor == colorValue;
              return GestureDetector(
                onTap: () => Navigator.pop(ctx, colorValue),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(colorValue),
                    border: isSelected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.onSurface,
                            width: 3,
                          )
                        : null,
                    boxShadow: isSelected
                        ? [BoxShadow(color: Color(colorValue).withValues(alpha: 0.6), blurRadius: 6)]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
        ],
      ),
    ).then((picked) {
      if (picked != null) onColorChanged(picked);
    });
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

                // Color dot — tap to pick a color
                GestureDetector(
                  onTap: () => _showColorPicker(context),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: workoutColor != null
                          ? Color(workoutColor!)
                          : theme.colorScheme.surfaceContainerHighest,
                      border: Border.all(
                        color: theme.colorScheme.outline,
                        width: 1.5,
                      ),
                    ),
                    child: workoutColor == null
                        ? Icon(Icons.palette_outlined, size: 14,
                            color: theme.colorScheme.onSurfaceVariant)
                        : null,
                  ),
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
  final List<(Exercise, List<SetTemplates>, int?)> exercises;
  final Function(List<(Exercise, List<SetTemplates>, int?)>) onExercisesChanged;

  const _WorkoutDetailsScreen({
    required this.workoutName,
    required this.exercises,
    required this.onExercisesChanged,
  });

  @override
  State<_WorkoutDetailsScreen> createState() => _WorkoutDetailsScreenState();
}

class _WorkoutDetailsScreenState extends State<_WorkoutDetailsScreen> {
  late List<(Exercise, List<SetTemplates>, int?)> _exercises;
  int? _supersetPickIndex;
  int _nextSupersetGroupId = 1;

  @override
  void initState() {
    super.initState();
    _exercises = List.from(widget.exercises);
    final maxGroupId = _exercises
        .map((e) => e.$3 ?? 0)
        .fold(0, (a, b) => a > b ? a : b);
    _nextSupersetGroupId = maxGroupId + 1;
  }

  void _handleLongPress(int index) {
    final l10n = AppLocalizations.of(context)!;
    final hasSuperset = _exercises[index].$3 != null;

    if (_supersetPickIndex != null && _supersetPickIndex != index) {
      // Second pick: link both exercises
      setState(() {
        final groupId = _nextSupersetGroupId++;
        final a = _exercises[_supersetPickIndex!];
        final b = _exercises[index];
        // Clear any existing groups first
        if (a.$3 != null) _clearSupersetGroup(a.$3!);
        if (b.$3 != null) _clearSupersetGroup(b.$3!);
        _exercises[_supersetPickIndex!] = (a.$1, a.$2, groupId);
        _exercises[index] = (b.$1, b.$2, groupId);
        _supersetPickIndex = null;
      });
      return;
    }

    showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(_exercises[index].$1.localizedName(Localizations.localeOf(context).languageCode)),
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
        setState(() => _clearSupersetGroup(_exercises[index].$3!));
      } else if (action == 'delete') {
        setState(() {
          if (_exercises[index].$3 != null) _clearSupersetGroup(_exercises[index].$3!);
          _exercises.removeAt(index);
        });
      }
    });
  }

  void _clearSupersetGroup(int groupId) {
    for (int i = 0; i < _exercises.length; i++) {
      if (_exercises[i].$3 == groupId) {
        _exercises[i] = (_exercises[i].$1, _exercises[i].$2, null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) widget.onExercisesChanged(_exercises);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.workoutName),
          actions: [
            if (_supersetPickIndex != null)
              TextButton(
                onPressed: () => setState(() => _supersetPickIndex = null),
                child: Text(l10n.cancel, style: TextStyle(color: theme.colorScheme.error)),
              ),
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () {
                widget.onExercisesChanged(_exercises);
                Navigator.pop(context);
              },
            ),
          ],
        ),
        body: _exercises.isEmpty
            ? _buildEmptyState(theme, l10n)
            : Column(
                children: [
                  if (_supersetPickIndex != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: theme.colorScheme.primaryContainer,
                      child: Text(
                        l10n.supersetPickHint,
                        style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                      ),
                    ),
                  Expanded(
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _exercises.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = _exercises.removeAt(oldIndex);
                          _exercises.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final exercise = _exercises[index];
                        final supersetGroupId = exercise.$3;
                        final showChainBelow = index + 1 < _exercises.length &&
                            supersetGroupId != null &&
                            _exercises[index + 1].$3 == supersetGroupId;
                        final isPickCandidate = _supersetPickIndex == index;

                        return Column(
                          key: ValueKey(exercise.$1.name + index.toString()),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ExerciseCard(
                              key: ValueKey('card_${exercise.$1.name}_$index'),
                              exercise: exercise.$1,
                              sets: exercise.$2,
                              supersetGroupId: supersetGroupId,
                              isPickCandidate: isPickCandidate,
                              exerciseNumber: index + 1,
                              onSetsChanged: (newSets) {
                                setState(() {
                                  _exercises[index] = (exercise.$1, newSets, exercise.$3);
                                });
                              },
                              onDelete: () {
                                setState(() {
                                  if (exercise.$3 != null) _clearSupersetGroup(exercise.$3!);
                                  _exercises.removeAt(index);
                                });
                              },
                              onLongPress: () => _handleLongPress(index),
                            ),
                            if (showChainBelow)
                              Padding(
                                padding: const EdgeInsets.only(left: 28, bottom: 4),
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
                        );
                      },
                    ),
                  ),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addExercise,
          icon: const Icon(Icons.add),
          label: Text(l10n.addExercise),
        ),
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
        _exercises.add((exercise, [], null));
      });
    }
  }
}

// Exercise Card Widget
class _ExerciseCard extends StatefulWidget {
  final Exercise exercise;
  final List<SetTemplates> sets;
  final int exerciseNumber;
  final int? supersetGroupId;
  final bool isPickCandidate;
  final Function(List<SetTemplates>) onSetsChanged;
  final VoidCallback onDelete;
  final VoidCallback onLongPress;

  const _ExerciseCard({
    super.key,
    required this.exercise,
    required this.sets,
    required this.exerciseNumber,
    this.supersetGroupId,
    this.isPickCandidate = false,
    required this.onSetsChanged,
    required this.onDelete,
    required this.onLongPress,
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

    final borderColor = widget.isPickCandidate
        ? theme.colorScheme.primary
        : widget.supersetGroupId != null
            ? theme.colorScheme.primary.withValues(alpha: 0.5)
            : theme.dividerColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: borderColor,
            width: widget.isPickCandidate || widget.supersetGroupId != null ? 2 : 1,
          ),
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
              onLongPress: widget.onLongPress,
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
                            color: theme.colorScheme.onPrimaryContainer,
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
                            widget.exercise.localizedName(Localizations.localeOf(context).languageCode),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _sets.isEmpty
                                ? l10n.noSetsConfigured
                                : l10n.setCount(_sets.length),
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
                      ExpandableDescription(
                        description: widget.exercise.description!,
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
                                    labelText: l10n.targetReps,
                                    hintText: l10n.targetRepsHint,
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
      duration: ForgeMotion.standard,
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: ForgeMotion.curve,
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.125, // 45 degrees (1/8 turn)
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // AnimationController is built in initState, before MediaQuery exists, so
    // the reduce-motion setting can only be applied once dependencies resolve.
    _animationController.duration = ForgeMotion.of(context);
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
