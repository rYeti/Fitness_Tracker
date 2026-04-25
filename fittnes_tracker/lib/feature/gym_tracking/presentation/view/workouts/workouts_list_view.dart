import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/di/service_locator.dart';
import 'package:ForgeForm/core/providers/access_provider.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/providers/workout_provider.dart';
import 'package:ForgeForm/feature/premium/paywall_screen.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/view/workouts/create_view.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/view/workouts/edit_view.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/view/workouts/importer/csv_import_screen.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/view/workouts/importer/fitnotes_import_view.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout_plan.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WorkoutsListView extends StatefulWidget {
  const WorkoutsListView({super.key});
  @override
  State<WorkoutsListView> createState() => WorkoutsListViewState();
}

class WorkoutsListViewState extends State<WorkoutsListView> {
  int? _activePlanId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      context.read<WorkoutProvider>().loadCompletePlans();
      // Restore the currently active plan so the UI reflects DB state on every visit
      final activePlans = await sl<AppDatabase>().workoutPlanDao.getActivePlans();
      if (mounted && activePlans.isNotEmpty) {
        setState(() => _activePlanId = activePlans.first.id);
      }
    });
  }

  Future<void> _setActivePlan(int planId) async {
    final db = sl<AppDatabase>();

    // Deactivate all plans
    await (db.update(db.workoutPlanTable)
          ..where((p) => p.isActive.equals(true)))
        .write(WorkoutPlanTableCompanion(isActive: drift.Value(false)));

    // Activate the selected plan
    await (db.update(db.workoutPlanTable)..where((p) => p.id.equals(planId)))
        .write(WorkoutPlanTableCompanion(isActive: drift.Value(true)));

    if (!mounted) return;
    setState(() => _activePlanId = planId);

    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.workoutPlanSetActive)));
  }

  void _showImportOptions(AppLocalizations l10n) {
    final hasPremium = context.read<AccessProvider>().hasPremiumAccess;
    final planCount = context.read<WorkoutProvider>().plans.length;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.add_circle_outline,
                color: (!hasPremium && planCount >= 1) ? Colors.grey : null,
              ),
              title: Row(
                children: [
                  Text(l10n.createFirstWorkout),
                  if (!hasPremium && planCount >= 1) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.lock, size: 14, color: Colors.orange),
                  ],
                ],
              ),
              subtitle: (!hasPremium && planCount >= 1)
                  ? const Text('Premium — upgrade to create multiple plans')
                  : null,
              onTap: () async {
                Navigator.pop(ctx);
                if (!hasPremium && planCount >= 1) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PaywallScreen()),
                  );
                  return;
                }
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CreateWorkoutView()),
                );
                if (mounted) context.read<WorkoutProvider>().loadCompletePlans();
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: Text(l10n.importFitNotes),
              subtitle: Text(l10n.importFitNotesHint),
              onTap: () async {
                Navigator.pop(ctx);
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FitNotesImportView(),
                  ),
                );
                if (result == true && mounted) {
                  context.read<WorkoutProvider>().loadCompletePlans();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: Text(l10n.importOptions),
              onTap: () async {
                Navigator.pop(ctx);
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CsvImportScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Show dialog to edit workout name
  Future<void> _showEditNameDialog(WorkoutPlan workout) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: workout.name);
    final result = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.editWorkoutName),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: l10n.workoutNameLabel,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.pop(ctx, value.trim());
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  final newName = controller.text.trim();
                  if (newName.isNotEmpty) {
                    Navigator.pop(ctx, newName);
                  }
                },
                child: Text(l10n.save),
              ),
            ],
          ),
    );
    if (result != null && result != workout.name) {
      await _updateWorkoutName(workout.id, result);
    }
  }

  /// Update workout name in database
  Future<void> _updateWorkoutName(int? workoutId, String newName) async {
    try {
      final db = context.read<AppDatabase>();
      await (db.update(db.workoutPlanTable)..where(
        (t) => t.id.equals(workoutId!),
      )).write(WorkoutPlanTableCompanion(name: drift.Value(newName)));

      // Refresh the list
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        context.read<WorkoutProvider>().loadCompletePlans();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.workoutRenamedTo(newName))),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorUpdatingName(e))),
        );
      }
    }
  }

  /// Show dialog to edit workout description and duration
  Future<void> _showEditDetailsDialog(WorkoutPlanTableData workout) async {
    final l10n = AppLocalizations.of(context)!;
    final descriptionController = TextEditingController(
      text: workout.description ?? '',
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.editDetails),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: l10n.descriptionOptional,
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
            ],
          ),
    );

    if (result != null) {
      await _updateWorkoutDetails(workout.id, result);
    }
  }

  /// Update workout details in database
  Future<void> _updateWorkoutDetails(
    int workoutId,
    Map<String, dynamic> details,
  ) async {
    try {
      final db = context.read<AppDatabase>();
      await (db.update(db.workoutTable)
        ..where((t) => t.id.equals(workoutId))).write(
        WorkoutTableCompanion(
          description: drift.Value(
            details['description'].isEmpty ? null : details['description'],
          ),
          estimatedDurationMinutes: drift.Value(details['duration']),
        ),
      );

      // Refresh the list
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        context.read<WorkoutProvider>().loadCompletePlans();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.workoutDetailsUpdated)),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorUpdatingDetails(e))),
        );
      }
    }
  }

  /// Show bottom sheet with edit options
  Future<void> _showEditOptions(WorkoutPlan workout) async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: Text(l10n.editName),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditNameDialog(workout);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.description),
                  title: Text(l10n.editDetails),
                  subtitle: Text(l10n.descriptionAndDuration),
                  onTap: () async {
                    final result = await Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) => EditWorkoutView(planId: workout.id),
                      ),
                    );
                    if (result == true && ctx.mounted) {
                      Navigator.pop(ctx, true);
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(
                    l10n.deleteWorkout,
                    style: const TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDeleteConfirmation(workout);
                  },
                ),
              ],
            ),
          ),
    );
    if (mounted) {
      context.read<WorkoutProvider>().loadCompletePlans();
    }
  }

  /// Show delete confirmation dialog
  Future<void> _showDeleteConfirmation(WorkoutPlan workout) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.deleteWorkout),
            content: Text(l10n.deleteWorkoutConfirmation(workout.name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(l10n.delete),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await _deleteWorkout(workout.id);
    }
  }

  /// Delete workout plan and its scheduled instances from database
  Future<void> _deleteWorkout(int? planId) async {
    if (planId == null) return;
    final db = context.read<AppDatabase>();

    // Remove all scheduled workouts belonging to this plan
    await (db.delete(db.scheduledWorkoutTable)
      ..where((t) => t.workoutPlanId.equals(planId))).go();

    // Remove the plan itself
    await (db.delete(db.workoutPlanTable)
      ..where((t) => t.id.equals(planId))).go();

    if (!mounted) return;
    context.read<WorkoutProvider>().loadCompletePlans();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.workoutDeleted)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.workouts)),
      body: Consumer<WorkoutProvider>(
        builder: (context, provider, _) {
          if (provider.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.plans.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.fitness_center,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noWorkoutsFound,
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CreateWorkoutView()),
                      );
                      if (mounted) {
                        provider.loadCompletePlans();
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: Text(l10n.createFirstWorkout),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.plans.length,
            itemBuilder: (context, index) {
              final plan = provider.plans[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.fitness_center,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(
                    plan.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (plan.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          plan.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_activePlanId == plan.id)
                        const Icon(Icons.check_circle, color: Colors.green),
                      TextButton(
                        onPressed: () => _setActivePlan(plan.id!),
                        child: Text(
                          _activePlanId == plan.id ? l10n.active : l10n.setActive,
                          style: TextStyle(
                            color:
                                _activePlanId == plan.id ? Colors.green : null,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        tooltip: l10n.moreOptions,
                        onPressed: () => _showEditOptions(plan),
                      ),
                    ],
                  ),
                  onTap: () {
                    // Show workout details or navigate to edit view
                    _showEditOptions(plan);
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.importOptions,
        onPressed: () => _showImportOptions(l10n),
        child: const Icon(Icons.file_upload),
      ),
    );
  }
}
