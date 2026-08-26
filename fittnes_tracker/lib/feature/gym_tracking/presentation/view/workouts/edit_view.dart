import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/di/service_locator.dart';
import 'package:ForgeForm/core/utils/app_logger.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/view/workouts/edit_single_view.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/view/workouts/workouts_list_view.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/widgets/exercise_selection_modal.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout_exercise.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout_plan.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout_set.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';

class EditWorkoutView extends StatefulWidget {
  final int? planId;
  const EditWorkoutView({super.key, this.planId});

  @override
  State<EditWorkoutView> createState() => _EditWorkoutViewState();
}

// Preset colours shared with the create view.
const _kPresetColors = [
  0xFFE53935,
  0xFFE91E63,
  0xFF9C27B0,
  0xFF3F51B5,
  0xFF2196F3,
  0xFF00BCD4,
  0xFF009688,
  0xFF4CAF50,
  0xFF8BC34A,
  0xFFCDDC39,
  0xFFFFEB3B,
  0xFFFF9800,
  0xFFFF5722,
  0xFF795548,
  0xFF9E9E9E,
  0xFF607D8B,
];

class _EditWorkoutViewState extends State<EditWorkoutView> {
  List<WorkoutPlan>? _plans;
  bool _loading = true;
  int? _activePlanId;

  // workoutId → ARGB color int (null = no color set)
  final Map<int, int?> _workoutColors = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_plans == null) {
      _loadPlans();
    }
  }

  Future<void> _loadColors(List<WorkoutPlan> plans) async {
    final db = sl<AppDatabase>();
    final ids =
        plans
            .expand((p) => p.workouts)
            .map((w) => w.id)
            .whereType<int>()
            .toSet();
    for (final id in ids) {
      final row =
          await (db.select(db.workoutTable)
            ..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row != null) _workoutColors[id] = row.color;
    }
  }

  Future<void> _pickColor(int workoutId, String workoutName) async {
    final current = _workoutColors[workoutId];
    final picked = await showDialog<int>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(workoutName),
            content: SizedBox(
              width: 280,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children:
                    _kPresetColors.map((c) {
                      final isSel = current == c;
                      return GestureDetector(
                        onTap: () => Navigator.pop(ctx, c),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(c),
                            border:
                                isSel
                                    ? Border.all(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                      width: 3,
                                    )
                                    : null,
                            boxShadow:
                                isSel
                                    ? [
                                      BoxShadow(
                                        color: Color(c).withValues(alpha: 0.6),
                                        blurRadius: 6,
                                      ),
                                    ]
                                    : null,
                          ),
                          child:
                              isSel
                                  ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                  : null,
                        ),
                      );
                    }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
            ],
          ),
    );
    if (picked == null) return;
    setState(() => _workoutColors[workoutId] = picked);
    await (sl<AppDatabase>().update(sl<AppDatabase>().workoutTable)..where(
      (t) => t.id.equals(workoutId),
    )).write(WorkoutTableCompanion(color: drift.Value(picked)));
  }

  Future<void> _loadPlans() async {
    setState(() => _loading = true);

    final dao = sl<AppDatabase>().workoutPlanDao;

    if (widget.planId != null) {
      // Load only the specific plan
      final plan = await dao.getCompletePlanById(widget.planId!);
      if (plan != null) {
        // If the plan has no workouts, dump the junction table and
        // referenced workout rows to help diagnose missing/stale links.
        if (plan.workouts.isEmpty) {
          try {
            final db = sl<AppDatabase>();
            final links =
                await db
                    .customSelect(
                      'SELECT * FROM workout_plan_workout_table WHERE plan_id = ?',
                      variables: [drift.Variable.withInt(plan.id!)],
                    )
                    .get();
          } catch (e) {
            AppLogger.i('Debug(Edit): failed to inspect junction: $e');
          }
        }
      }
      if (plan != null) {
        setState(() {
          _plans = [plan];
          _loading = false;
          _activePlanId = plan.isActive ? plan.id : null;
        });
        await _loadColors(_plans!);
      } else {
        AppLogger.i(
          '❌ Plan not found for ID: ${widget.planId} - falling back to loading all plans',
        );

        // If a specific planId was requested but not found, fall back to loading
        // all plans so the user can pick one to edit instead of showing an empty view.
        final planData = await (sl<AppDatabase>().workoutPlanDao).getAllPlans();
        final plans = await Future.wait(
          planData.map(
            (p) => (sl<AppDatabase>().workoutPlanDao).getCompletePlanById(p.id),
          ),
        );

        setState(() {
          _plans = plans.whereType<WorkoutPlan>().toList();
          _loading = false;
        });
        await _loadColors(_plans!);

        if (_plans!.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.requestedPlanNotFound,
              ),
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.requestedPlanNotFoundShowingAll,
              ),
            ),
          );
        }
      }
    } else {
      // Load all plans
      final planData = await (sl<AppDatabase>().workoutPlanDao).getAllPlans();

      final plans = await Future.wait(
        planData.map(
          (p) => (sl<AppDatabase>().workoutPlanDao).getCompletePlanById(p.id),
        ),
      );
      setState(() {
        _plans = plans.whereType<WorkoutPlan>().toList();
        _loading = false;
        // Set active plan
        final activePlan = _plans!.where((p) => p.isActive).firstOrNull;
        _activePlanId = activePlan?.id;
      });
      await _loadColors(_plans!);
    }
  }

  Future<void> _setActivePlan(int planId) async {
    // Deactivate all plans
    await (sl<AppDatabase>().update(sl<AppDatabase>().workoutPlanTable)..where(
      (p) => p.isActive.equals(true),
    )).write(WorkoutPlanTableCompanion(isActive: drift.Value(false)));

    // Activate the selected plan
    await (sl<AppDatabase>().update(sl<AppDatabase>().workoutPlanTable)..where(
      (p) => p.id.equals(planId),
    )).write(WorkoutPlanTableCompanion(isActive: drift.Value(true)));

    setState(() {
      _activePlanId = planId;
    });

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.workoutPlanSetActive)));
  }

  Future<void> _activateCurrentPlan() async {
    final plan = _plans!.first;
    await _setActivePlan(plan.id!);
  }

  Future<void> _showDeleteWorkoutDialog(Workout workout) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.removeWorkoutFromPlan),
          content: Text(l10n.removeWorkoutFromPlanConfirm(workout.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: ForgeColors.statusBadFor(Theme.of(context).brightness)),
              child: Text(l10n.remove),
            ),
          ],
        );
      },
    );

    if (confirmed == true && workout.id != null) {
      try {
        final plan = _plans!.first;
        await sl<AppDatabase>().workoutPlanDao.removeWorkoutFromPlan(
          plan.id!,
          workout.id!,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.workoutRemovedFromPlan(workout.name))),
        );
        // Reload the plan to reflect the changes
        _loadPlans();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToRemoveWorkoutFromPlan(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditingSinglePlan = widget.planId != null;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditingSinglePlan ? l10n.editWorkoutsTitle : l10n.workouts,
        ),
        actions:
            isEditingSinglePlan
                ? [
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    tooltip: l10n.activatePlan,
                    onPressed: () => _activateCurrentPlan(),
                  ),
                ]
                : null,
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _plans == null || _plans!.isEmpty
              ? Center(child: Text(l10n.noWorkoutPlansFound))
              : isEditingSinglePlan
              ? _buildSinglePlanView()
              : _buildAllPlansView(),
      floatingActionButton:
          isEditingSinglePlan
              ? _buildAddWorkoutButton()
              : _buildCreatePlanButton(),
    );
  }

  Widget _buildSinglePlanView() {
    final plan = _plans!.first;
    final l10n = AppLocalizations.of(context)!;
    final modeHeader = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        child: SwitchListTile(
          title: Text(l10n.freeChoiceMode),
          subtitle: Text(
            plan.isFreeChoice
                ? l10n.freeChoiceModeSubtitle
                : l10n.cycleModeSubtitle,
          ),
          value: plan.isFreeChoice,
          onChanged: _toggleFreeChoice,
        ),
      ),
    );

    if (plan.workouts.isEmpty) {
      return Column(
        children: [modeHeader, Expanded(child: _buildEmptyPlanView(plan))],
      );
    }

    return Column(
      children: [
        modeHeader,
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: plan.workouts.length,
            itemBuilder: (context, index) {
              final workout = plan.workouts[index];
              return _buildExpandableWorkoutCard(workout, index);
            },
          ),
        ),
      ],
    );
  }

  Future<void> _toggleFreeChoice(bool value) async {
    final plan = _plans!.first;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ctxL10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(
            value
                ? ctxL10n.switchToFreeChoiceTitle
                : ctxL10n.switchToCyclePlanTitle,
          ),
          content: Text(
            value
                ? ctxL10n.switchToFreeChoiceBody
                : ctxL10n.switchToCyclePlanBody,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctxL10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctxL10n.confirm),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final db = sl<AppDatabase>();

    // When switching to free choice, remove all future scheduled workouts for this plan
    if (value && plan.id != null) {
      final today = DateTime.now();
      final normalizedToday = DateTime(today.year, today.month, today.day).add(
        const Duration(days: 1),
      ); // Start from tomorrow to avoid deleting today's workout if it exists
      await (db.delete(db.scheduledWorkoutTable)..where(
        (t) =>
            t.workoutPlanId.equals(plan.id!) &
            t.scheduledDate.isBiggerOrEqualValue(normalizedToday),
      )).go();
    }

    await (db.update(db.workoutPlanTable)..where(
      (t) => t.id.equals(plan.id!),
    )).write(WorkoutPlanTableCompanion(isFreeChoice: drift.Value(value)));

    await _loadPlans();
  }

  Widget _buildExpandableWorkoutCard(Workout workout, int workoutIndex) {
    final color = workout.id != null ? _workoutColors[workout.id] : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            // Colour dot — tap to pick
            if (workout.id != null)
              GestureDetector(
                onTap: () => _pickColor(workout.id!, workout.name),
                child: Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        color != null
                            ? Color(color)
                            : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                      width: 1.5,
                    ),
                  ),
                  child:
                      color == null
                          ? Icon(
                            Icons.palette_outlined,
                            size: 14,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          )
                          : null,
                ),
              ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (workout.id != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) =>
                                EditSingleWorkoutView(workoutId: workout.id!),
                      ),
                    ).then((result) {
                      _loadPlans();
                    });
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workout.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppLocalizations.of(context)!.exercisesAndSets(
                        workout.exercises.length,
                        workout.exercises.fold<int>(
                          0,
                          (sum, ex) => sum + ex.sets.length,
                        ),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip:
                      AppLocalizations.of(context)!.editWorkoutDetailsTooltip,
                  onPressed: () {
                    if (workout.id != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) =>
                                  EditSingleWorkoutView(workoutId: workout.id!),
                        ),
                      ).then((result) {
                        _loadPlans();
                      });
                    }
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: ForgeColors.statusBadFor(Theme.of(context).brightness)),
                  tooltip:
                      AppLocalizations.of(
                        context,
                      )!.removeWorkoutFromPlanTooltip,
                  onPressed: () => _showDeleteWorkoutDialog(workout),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseTile(Workout workout, WorkoutExercise exercise) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  exercise.exercise?.localizedName(
                        Localizations.localeOf(context).languageCode,
                      ) ??
                      AppLocalizations.of(context)!.unknownExercise,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete, size: 18, color: ForgeColors.statusBadFor(Theme.of(context).brightness)),
                tooltip: AppLocalizations.of(context)!.removeExerciseTooltip,
                onPressed: () => _removeExerciseFromWorkout(workout, exercise),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Sets list
          ...exercise.sets.map((set) => _buildSetTile(workout, exercise, set)),
          // Add set button
          TextButton.icon(
            onPressed: () => _addSetToExercise(workout, exercise),
            icon: const Icon(Icons.add, size: 16),
            label: Text(AppLocalizations.of(context)!.addSet),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetTile(
    Workout workout,
    WorkoutExercise exercise,
    WorkoutSet set,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4, left: 8, right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${set.setNumber}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${set.reps ?? 0} reps × ${set.weight ?? 0} ${set.weightUnit ?? 'kg'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 16),
                tooltip: AppLocalizations.of(context)!.edit,
                onPressed: () => _editSet(workout, exercise, set),
              ),
              IconButton(
                icon: Icon(Icons.delete, size: 16, color: ForgeColors.statusBadFor(Theme.of(context).brightness)),
                tooltip: AppLocalizations.of(context)!.removeSet,
                onPressed: () => _removeSetFromExercise(workout, exercise, set),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlanView(WorkoutPlan plan) {
    return FutureBuilder<List<ScheduledWorkoutWithDetails>>(
      future: _getScheduledWorkoutsForPlan(plan.id!),
      builder: (context, snapshot) {
        final scheduledWorkouts = snapshot.data ?? [];
        final templateWorkoutIds =
            scheduledWorkouts
                .map((s) => s.scheduled.templateWorkoutId)
                .whereType<int>()
                .toSet();

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.fitness_center, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.noWorkoutsInPlanYet,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  templateWorkoutIds.isNotEmpty
                      ? AppLocalizations.of(
                        context,
                      )!.foundTemplateWorkouts(templateWorkoutIds.length)
                      : AppLocalizations.of(context)!.addWorkoutsToPlanHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                if (templateWorkoutIds.isNotEmpty) ...[
                  ElevatedButton.icon(
                    onPressed:
                        () => _addTemplateWorkoutsFromScheduled(
                          plan.id!,
                          templateWorkoutIds.toList(),
                        ),
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(
                      AppLocalizations.of(context)!.addFromScheduledWorkouts,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const WorkoutsListView(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.file_upload),
                  label: Text(AppLocalizations.of(context)!.importCsvWorkouts),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddWorkoutButton() {
    return FloatingActionButton(
      onPressed: _addWorkoutToPlan,
      tooltip: AppLocalizations.of(context)!.addWorkoutToPlanTitle,
      child: const Icon(Icons.add),
    );
  }

  Future<void> _addWorkoutToPlan() async {
    final dao = sl<AppDatabase>().workoutDao;
    final allWorkouts = await dao.getAllWorkouts();
    if (!mounted) return;

    // Show debug info
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Found ${allWorkouts.length} workouts in database'),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // Filter out workouts that are already in the plan
    final plan = _plans!.first;
    final existingWorkoutIds =
        plan.workouts.map((w) => w.id).whereType<int>().toSet();

    final availableWorkouts =
        allWorkouts.where((w) => !existingWorkoutIds.contains(w.id)).toList();

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    if (availableWorkouts.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.noWorkoutsAvailableToAdd)));
      return;
    }

    // Show dialog to select workout
    final selectedWorkout = await showDialog<WorkoutTableData>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.addWorkoutToPlanTitle),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: availableWorkouts.length,
              itemBuilder: (context, index) {
                final workout = availableWorkouts[index];
                return ListTile(
                  title: Text(workout.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (workout.description != null)
                        Text(workout.description!),
                      Text(
                        workout.isTemplate
                            ? l10n.templateWorkoutLabel
                            : l10n.scheduledWorkoutLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              workout.isTemplate ? ForgeColors.statusOkFor(Theme.of(context).brightness) : ForgeColors.statusWarnFor(Theme.of(context).brightness),
                        ),
                      ),
                    ],
                  ),
                  onTap: () => Navigator.of(context).pop(workout),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );

    if (selectedWorkout != null) {
      // Add the workout to the plan
      await _addWorkoutToPlanById(selectedWorkout.id);
    }
  }

  Future<List<ScheduledWorkoutWithDetails>> _getScheduledWorkoutsForPlan(
    int planId,
  ) async {
    final scheduledDao = sl<AppDatabase>().scheduledWorkoutDao;
    final today = DateTime.now();
    final scheduledWorkouts = await scheduledDao.getScheduledWithDetailsForDate(
      today,
    );
    return scheduledWorkouts
        .where((s) => s.scheduled.workoutPlanId == planId)
        .toList();
  }

  Future<void> _addTemplateWorkoutsFromScheduled(
    int planId,
    List<int> templateWorkoutIds,
  ) async {
    for (final templateWorkoutId in templateWorkoutIds) {
      try {
        await (sl<AppDatabase>().into(
          sl<AppDatabase>().workoutPlanWorkoutTable,
        )).insert(
          WorkoutPlanWorkoutTableCompanion(
            planId: drift.Value(planId),
            workoutId: drift.Value(templateWorkoutId),
          ),
        );
        AppLogger.i(
          'Added template workout $templateWorkoutId to plan $planId',
        );
      } catch (e) {
        AppLogger.i('Failed to add template workout $templateWorkoutId: $e');
      }
    }

    // Reload the plan
    await _loadPlans();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${templateWorkoutIds.length} workouts from scheduled workouts',
          ),
        ),
      );
    }
  }

  Future<void> _addWorkoutToPlanById(int workoutId) async {
    final plan = _plans!.first;

    // Add link between plan and workout
    await (sl<AppDatabase>().into(
      sl<AppDatabase>().workoutPlanWorkoutTable,
    )).insert(
      WorkoutPlanWorkoutTableCompanion(
        planId: drift.Value(plan.id!),
        workoutId: drift.Value(workoutId),
      ),
    );

    // Reload the plan
    await _loadPlans();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.workoutAddedToPlan),
        ),
      );
    }
  }

  Widget _buildAllPlansView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _plans!.length,
      itemBuilder: (context, index) {
        final plan = _plans![index];
        final isActive = _activePlanId == plan.id;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: isActive ? 8 : 2,
          color:
              isActive
                  ? Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withOpacity(0.1)
                  : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plan Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.name,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall?.copyWith(
                              color:
                                  isActive
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: ForgeColors.statusOkFor(Theme.of(context).brightness),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.activePlanBadge,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        ElevatedButton(
                          onPressed: () => _setActivePlan(plan.id!),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isActive ? ForgeColors.statusOkFor(Theme.of(context).brightness) : null,
                            foregroundColor: isActive ? Colors.white : null,
                          ),
                          child: Text(
                            isActive
                                ? AppLocalizations.of(context)!.active
                                : AppLocalizations.of(context)!.setActive,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add),
                              tooltip:
                                  AppLocalizations.of(
                                    context,
                                  )!.addWorkoutToPlanTitle,
                              onPressed:
                                  () => _addWorkoutToPlanForSpecificPlan(plan),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip:
                                  AppLocalizations.of(context)!.openPlanEditor,
                              onPressed: () {
                                // Open the same EditWorkoutView focused on this plan
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => EditWorkoutView(planId: plan.id),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: ForgeColors.statusBadFor(Theme.of(context).brightness)),
                              tooltip:
                                  AppLocalizations.of(
                                    context,
                                  )!.deletePlanTooltip,
                              onPressed: () => _deletePlan(plan),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Workouts Section
              if (plan.workouts.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        AppLocalizations.of(context)!.noWorkoutsInPlanYet,
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _addWorkoutToPlanForSpecificPlan(plan),
                        icon: const Icon(Icons.add),
                        label: Text(AppLocalizations.of(context)!.addWorkout),
                      ),
                    ],
                  ),
                )
              else
                ...plan.workouts.map(
                  (workout) =>
                      _buildExpandableWorkoutCardForPlan(plan, workout),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addExerciseToWorkout(Workout workout) async {
    final cannotAddMsg =
        AppLocalizations.of(context)!.cannotAddExerciseToUnsavedWorkout;
    // Use the same selection modal as in create_view to pick an exercise
    final selectedExercise = await ExerciseSelectionModal.show(context);

    if (selectedExercise == null) return;
    if (workout.id == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(cannotAddMsg)));
      return;
    }

    try {
      // Ensure exercise exists in DB (modal should return an existing exercise with id)
      int exerciseId;
      if (selectedExercise.id != null) {
        exerciseId = selectedExercise.id!;
      } else {
        // Fallback: save exercise to DB
        final companion = ExerciseTableCompanion(
          name: drift.Value(selectedExercise.name),
          description: drift.Value(selectedExercise.description),
          type: drift.Value(selectedExercise.type.index),
          targetMuscleGroups: drift.Value(
            selectedExercise.targetMuscleGroups
                .map((m) => m.index.toString())
                .join(','),
          ),
          imageUrl: drift.Value(selectedExercise.imageUrl),
          isCustom: drift.Value(selectedExercise.isCustom),
        );
        exerciseId = await sl<AppDatabase>().exerciseDao.saveExercise(
          companion,
        );
      }

      // Create a minimal workout exercise entry with one default set
      final newExercise = WorkoutExercise(
        workoutId: workout.id!,
        exerciseId: exerciseId,
        orderPosition: workout.exercises.length + 1,
        exercise: selectedExercise.copyWith(id: exerciseId),
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

      await sl<AppDatabase>().workoutDao.saveCompleteWorkout(
        workout.copyWith(exercises: [...workout.exercises, newExercise]),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.exerciseAddedToWorkout(
              selectedExercise.localizedName(
                Localizations.localeOf(context).languageCode,
              ),
            ),
          ),
        ),
      );
      _loadPlans();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.failedToAddExercise(e)),
        ),
      );
    }
  }

  Future<void> _removeExerciseFromWorkout(
    Workout workout,
    WorkoutExercise exercise,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.removeExerciseTitle),
          content: Text(
            l10n.removeExerciseConfirmBody(
              exercise.exercise?.localizedName(
                    Localizations.localeOf(context).languageCode,
                  ) ??
                  'exercise',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: ForgeColors.statusBadFor(Theme.of(context).brightness)),
              child: Text(l10n.remove),
            ),
          ],
        );
      },
    );

    if (confirmed == true && workout.id != null) {
      try {
        final updatedExercises =
            workout.exercises.where((e) => e.id != exercise.id).toList();
        await sl<AppDatabase>().workoutDao.saveCompleteWorkout(
          workout.copyWith(exercises: updatedExercises),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exerciseRemovedFromWorkout)),
        );
        _loadPlans();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.failedToRemoveExercise(e))));
      }
    }
  }

  Future<void> _addSetToExercise(
    Workout workout,
    WorkoutExercise exercise,
  ) async {
    if (workout.id == null) return;

    try {
      final newSet = WorkoutSet(
        exerciseInstanceId: exercise.id ?? 0,
        setNumber: exercise.sets.length + 1,
        reps: 10,
        weight: 0,
        weightUnit: 'kg',
        isCompleted: false,
      );

      final updatedExercises =
          workout.exercises.map((e) {
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

      await sl<AppDatabase>().workoutDao.saveCompleteWorkout(
        workout.copyWith(exercises: updatedExercises),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.setAddedToExercise),
        ),
      );
      _loadPlans();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.failedToAddSet(e)),
        ),
      );
    }
  }

  Future<void> _removeSetFromExercise(
    Workout workout,
    WorkoutExercise exercise,
    WorkoutSet set,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.removeSet),
          content: Text(
            l10n.removeSetConfirmBody(
              set.setNumber,
              exercise.exercise?.localizedName(
                    Localizations.localeOf(context).languageCode,
                  ) ??
                  'exercise',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: ForgeColors.statusBadFor(Theme.of(context).brightness)),
              child: Text(l10n.remove),
            ),
          ],
        );
      },
    );

    if (confirmed == true && workout.id != null) {
      try {
        final updatedExercises =
            workout.exercises.map((e) {
              if (e.id == exercise.id) {
                return WorkoutExercise(
                  id: e.id,
                  workoutId: e.workoutId,
                  exerciseId: e.exerciseId,
                  orderPosition: e.orderPosition,
                  exercise: e.exercise,
                  sets: e.sets.where((s) => s.id != set.id).toList(),
                  notes: e.notes,
                );
              }
              return e;
            }).toList();

        await sl<AppDatabase>().workoutDao.saveCompleteWorkout(
          workout.copyWith(exercises: updatedExercises),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.setRemovedFromExercise)));
        _loadPlans();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToRemoveSet(e)),
          ),
        );
      }
    }
  }

  Future<void> _editSet(
    Workout workout,
    WorkoutExercise exercise,
    WorkoutSet set,
  ) async {
    final repsController = TextEditingController(
      text: set.reps?.toString() ?? '',
    );
    final weightController = TextEditingController(
      text: set.weight?.toString() ?? '',
    );
    String weightUnit = set.weightUnit ?? 'kg';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.editSet(set.setNumber)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: repsController,
                decoration: InputDecoration(labelText: l10n.repsLabel),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: weightController,
                decoration: InputDecoration(labelText: l10n.weightLabel),
                keyboardType: TextInputType.number,
              ),
              DropdownButtonFormField<String>(
                value: weightUnit,
                decoration: InputDecoration(labelText: l10n.unit),
                items:
                    ['kg', 'lbs'].map((unit) {
                      return DropdownMenuItem(value: unit, child: Text(unit));
                    }).toList(),
                onChanged: (value) {
                  if (value != null) weightUnit = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.saveButton),
            ),
          ],
        );
      },
    );

    if (result == true && workout.id != null) {
      try {
        final updatedSet = WorkoutSet(
          id: set.id,
          exerciseInstanceId: set.exerciseInstanceId,
          setNumber: set.setNumber,
          reps: int.tryParse(repsController.text) ?? set.reps,
          weight:
              double.tryParse(weightController.text.replaceAll(',', '.')) ??
              set.weight,
          weightUnit: weightUnit,
          isCompleted: set.isCompleted,
        );

        final updatedExercises =
            workout.exercises.map((e) {
              if (e.id == exercise.id) {
                return WorkoutExercise(
                  id: e.id,
                  workoutId: e.workoutId,
                  exerciseId: e.exerciseId,
                  orderPosition: e.orderPosition,
                  exercise: e.exercise,
                  sets:
                      e.sets
                          .map((s) => s.id == set.id ? updatedSet : s)
                          .toList(),
                  notes: e.notes,
                );
              }
              return e;
            }).toList();

        await sl<AppDatabase>().workoutDao.saveCompleteWorkout(
          workout.copyWith(exercises: updatedExercises),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.setUpdated)),
          );
        }
        _loadPlans();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.failedToUpdateSet(e)),
            ),
          );
        }
      }
    }
  }

  Widget _buildCreatePlanButton() {
    return FloatingActionButton(
      onPressed: _createNewWorkoutPlan,
      tooltip: AppLocalizations.of(context)!.createWorkoutPlan,
      child: const Icon(Icons.add),
    );
  }

  Future<void> _createNewWorkoutPlan() async {
    final planNameController = TextEditingController();

    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.createWorkoutPlan),
          content: TextField(
            controller: planNameController,
            decoration: InputDecoration(
              labelText: l10n.planName,
              hintText: l10n.planNameHint,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, planNameController.text),
              child: Text(l10n.create),
            ),
          ],
        );
      },
    );

    if (result != null && result.trim().isNotEmpty) {
      try {
        final newPlan = WorkoutPlan(
          name: result.trim(),
          startDate: DateTime.now(),
          workouts: [], // Start with empty workouts
          isActive: false,
        );

        await sl<AppDatabase>().workoutPlanDao.saveWorkoutPlan(newPlan);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.workoutPlanCreated(result.trim()))),
          );
        }

        _loadPlans(); // Refresh the list
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.failedToCreatePlan(e))));
        }
      }
    }
  }

  Future<void> _addWorkoutToPlanForSpecificPlan(WorkoutPlan plan) async {
    final dao = sl<AppDatabase>().workoutDao;
    final allWorkouts = await dao.getAllWorkouts();

    // Filter out workouts that are already in this plan
    final existingWorkoutIds =
        plan.workouts.map((w) => w.id).whereType<int>().toSet();
    final availableWorkouts =
        allWorkouts.where((w) => !existingWorkoutIds.contains(w.id)).toList();

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    if (availableWorkouts.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.noWorkoutsAvailableToAdd)));
      return;
    }

    // Show dialog to select workout
    final selectedWorkout = await showDialog<WorkoutTableData>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.addWorkoutToPlanTitle),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: availableWorkouts.length,
              itemBuilder: (context, index) {
                final workout = availableWorkouts[index];
                return ListTile(
                  title: Text(workout.name),
                  subtitle: Text(l10n.templateWorkoutLabel),
                  onTap: () => Navigator.pop(context, workout),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );

    if (selectedWorkout != null) {
      try {
        // Add the workout to the plan
        await _addWorkoutToPlanById(selectedWorkout.id);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.workoutAddedToPlan),
          ),
        );

        _loadPlans(); // Refresh the view
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToAddWorkout(e)),
          ),
        );
      }
    }
  }

  Future<void> _deletePlan(WorkoutPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.deletePlanTooltip),
          content: Text(l10n.deletePlanConfirmBody(plan.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: ForgeColors.statusBadFor(Theme.of(context).brightness)),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await sl<AppDatabase>().workoutPlanDao.deleteWorkoutPlan(plan.id!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.deletedWorkoutPlan(plan.name),
            ),
          ),
        );
        _loadPlans(); // Refresh the view
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToDeletePlan(e)),
          ),
        );
      }
    }
  }

  Widget _buildExpandableWorkoutCardForPlan(WorkoutPlan plan, Workout workout) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (workout.id != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) =>
                                EditSingleWorkoutView(workoutId: workout.id!),
                      ),
                    ).then((result) {
                      _loadPlans();
                    });
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workout.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppLocalizations.of(context)!.exercisesAndSets(
                        workout.exercises.length,
                        workout.exercises.fold<int>(
                          0,
                          (sum, ex) => sum + ex.sets.length,
                        ),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip:
                      AppLocalizations.of(context)!.editWorkoutDetailsTooltip,
                  onPressed: () {
                    if (workout.id != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) =>
                                  EditSingleWorkoutView(workoutId: workout.id!),
                        ),
                      ).then((result) {
                        _loadPlans();
                      });
                    }
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: ForgeColors.statusBadFor(Theme.of(context).brightness)),
                  tooltip:
                      AppLocalizations.of(
                        context,
                      )!.removeWorkoutFromPlanTooltip,
                  onPressed:
                      () => _showDeleteWorkoutDialogForPlan(plan, workout),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteWorkoutDialogForPlan(
    WorkoutPlan plan,
    Workout workout,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.removeWorkoutFromPlan),
          content: Text(l10n.removeWorkoutFromPlanConfirm(workout.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: ForgeColors.statusBadFor(Theme.of(context).brightness)),
              child: Text(l10n.remove),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await sl<AppDatabase>().workoutPlanDao.removeWorkoutFromPlan(
          plan.id!,
          workout.id!,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.workoutRemovedFromPlan(workout.name))),
        );
        _loadPlans(); // Refresh the view
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToRemoveWorkoutFromPlan(e))),
        );
      }
    }
  }
}
