import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/exercise.dart';

/// Bottom sheet for creating a new custom exercise or editing an existing one.
///
/// Pass [exercise] to pre-populate the form for editing.
/// Pass [initialMuscleGroup] to pre-select a muscle group when creating.
class ExerciseFormSheet extends StatefulWidget {
  final Exercise? exercise;
  final MuscleGroup? initialMuscleGroup;

  const ExerciseFormSheet({super.key, this.exercise, this.initialMuscleGroup});

  /// Shows the sheet and returns `true` if the exercise was saved or deleted.
  static Future<bool?> show(
    BuildContext context, {
    Exercise? exercise,
    MuscleGroup? initialMuscleGroup,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ExerciseFormSheet(
              exercise: exercise,
              initialMuscleGroup: initialMuscleGroup,
            ),
          ),
    );
  }

  @override
  State<ExerciseFormSheet> createState() => _ExerciseFormSheetState();
}

class _ExerciseFormSheetState extends State<ExerciseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  ExerciseType _selectedType = ExerciseType.strength;
  final Set<MuscleGroup> _selectedMuscleGroups = {};
  bool _isSaving = false;

  bool get _isEditing => widget.exercise != null;

  /// Only custom exercises may be deleted; predefined ones are kept as-is.
  bool get _canDelete => widget.exercise?.isCustom == true;

  @override
  void initState() {
    super.initState();
    final ex = widget.exercise;
    if (ex != null) {
      _nameController.text = ex.name;
      _descriptionController.text = ex.description ?? '';
      _selectedType = ex.type;
      _selectedMuscleGroups.addAll(ex.targetMuscleGroups);
    } else if (widget.initialMuscleGroup != null) {
      _selectedMuscleGroups.add(widget.initialMuscleGroup!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _muscleGroupName(MuscleGroup mg) {
    switch (mg) {
      case MuscleGroup.chest:
        return 'Chest';
      case MuscleGroup.back:
        return 'Back';
      case MuscleGroup.shoulders:
        return 'Shoulders';
      case MuscleGroup.biceps:
        return 'Biceps';
      case MuscleGroup.triceps:
        return 'Triceps';
      case MuscleGroup.legs:
        return 'Legs';
      case MuscleGroup.abs:
        return 'Abs';
      case MuscleGroup.fullBody:
        return 'Full Body';
    }
  }

  String _typeName(ExerciseType type) {
    switch (type) {
      case ExerciseType.strength:
        return 'Strength';
      case ExerciseType.cardio:
        return 'Cardio';
      case ExerciseType.flexibility:
        return 'Flexibility';
      case ExerciseType.calisthenics:
        return 'Calisthenics';
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMuscleGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one muscle group'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = context.read<AppDatabase>();
      final exercise = Exercise(
        id: widget.exercise?.id,
        name: _nameController.text.trim(),
        description:
            _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
        type: _selectedType,
        targetMuscleGroups: _selectedMuscleGroups.toList(),
        imageUrl: widget.exercise?.imageUrl,
        // New exercises are always custom; edited predefined exercises keep
        // their original flag so re-seeding behaviour is unaffected.
        isCustom: widget.exercise?.isCustom ?? true,
      );

      await db.exerciseDao.saveExercise(db.exerciseDao.modelToEntity(exercise));

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Exercise updated' : 'Exercise created'),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving exercise: $e')));
      }
    }
  }

  Future<void> _delete() async {
    final id = widget.exercise?.id;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Exercise'),
            content: Text('Delete "${widget.exercise!.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final db = context.read<AppDatabase>();
      await db.exerciseDao.deleteExercise(id);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Exercise deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting exercise: $e')));
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditing ? 'Edit Exercise' : 'Create Exercise',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Scrollable form
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Name ─────────────────────────────────────────────
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Exercise Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator:
                          (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Please enter a name'
                                  : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Description ───────────────────────────────────────
                    TextFormField(
                      controller: _descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Exercise type ─────────────────────────────────────
                    DropdownButtonFormField<ExerciseType>(
                      value: _selectedType,
                      decoration: InputDecoration(
                        labelText: 'Exercise Type',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items:
                          ExerciseType.values
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(_typeName(t)),
                                ),
                              )
                              .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedType = v);
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── Muscle groups ─────────────────────────────────────
                    Text('Muscle Groups', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children:
                          MuscleGroup.values.map((mg) {
                            final selected = _selectedMuscleGroups.contains(mg);
                            return FilterChip(
                              label: Text(_muscleGroupName(mg)),
                              selected: selected,
                              onSelected: (v) {
                                setState(() {
                                  if (v) {
                                    _selectedMuscleGroups.add(mg);
                                  } else {
                                    _selectedMuscleGroups.remove(mg);
                                  }
                                });
                              },
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 28),

                    // ── Action buttons ────────────────────────────────────
                    Row(
                      children: [
                        if (_canDelete) ...[
                          OutlinedButton.icon(
                            onPressed: _isSaving ? null : _delete,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.colorScheme.error,
                              side: BorderSide(color: theme.colorScheme.error),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: FilledButton(
                            onPressed: _isSaving ? null : _save,
                            child:
                                _isSaving
                                    ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : Text(
                                      _isEditing
                                          ? 'Save Changes'
                                          : 'Create Exercise',
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
