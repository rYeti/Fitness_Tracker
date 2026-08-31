import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/exercise.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

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

  String _muscleGroupName(AppLocalizations l10n, MuscleGroup mg) {
    switch (mg) {
      case MuscleGroup.chest:
        return l10n.muscleGroupChest;
      case MuscleGroup.back:
        return l10n.muscleGroupBack;
      case MuscleGroup.shoulders:
        return l10n.muscleGroupShoulders;
      case MuscleGroup.biceps:
        return l10n.muscleGroupBiceps;
      case MuscleGroup.triceps:
        return l10n.muscleGroupTriceps;
      case MuscleGroup.legs:
        return l10n.muscleGroupLegs;
      case MuscleGroup.abs:
        return l10n.muscleGroupAbs;
      case MuscleGroup.fullBody:
        return l10n.muscleGroupFullBody;
    }
  }

  String _typeName(AppLocalizations l10n, ExerciseType type) {
    switch (type) {
      case ExerciseType.strength:
        return l10n.exerciseTypeStrength;
      case ExerciseType.cardio:
        return l10n.exerciseTypeCardio;
      case ExerciseType.flexibility:
        return l10n.exerciseTypeFlexibility;
      case ExerciseType.calisthenics:
        return l10n.exerciseTypeCalisthenics;
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _save(AppLocalizations l10n) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMuscleGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectAtLeastOneMuscleGroup)),
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
        isCustom: widget.exercise?.isCustom ?? true,
      );

      await db.exerciseDao.saveExercise(db.exerciseDao.modelToEntity(exercise));

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? l10n.exerciseUpdated : l10n.exerciseCreated,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorSavingExercise(e))),
        );
      }
    }
  }

  Future<void> _delete(AppLocalizations l10n) async {
    final id = widget.exercise?.id;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.deleteExercise),
            content: Text(
              l10n.deleteExerciseConfirmation(widget.exercise!.name),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: TextButton.styleFrom(foregroundColor: ForgeColors.statusBadFor(Theme.of(context).brightness)),
                child: Text(l10n.delete),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exerciseDeleted)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorDeletingExercise(e))),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      child: Container(
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
                      _isEditing ? l10n.editExercise : l10n.createExercise,
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
                          labelText: l10n.exerciseName,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? l10n.pleaseEnterName
                                    : null,
                      ),
                      const SizedBox(height: 16),

                      // ── Description ───────────────────────────────────────
                      TextFormField(
                        controller: _descriptionController,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: l10n.descriptionOptional,
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
                          labelText: l10n.exerciseType,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items:
                            ExerciseType.values
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(_typeName(l10n, t)),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedType = v);
                        },
                      ),
                      const SizedBox(height: 20),

                      // ── Muscle groups ─────────────────────────────────────
                      Text(
                        l10n.muscleGroupsLabel,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children:
                            MuscleGroup.values.map((mg) {
                              final selected = _selectedMuscleGroups.contains(
                                mg,
                              );
                              return FilterChip(
                                label: Text(_muscleGroupName(l10n, mg)),
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
                              onPressed: _isSaving ? null : () => _delete(l10n),
                              icon: const Icon(Icons.delete_outline),
                              label: Text(l10n.delete),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.colorScheme.error,
                                side: BorderSide(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: FilledButton(
                              onPressed: _isSaving ? null : () => _save(l10n),
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
                                            ? l10n.saveChanges
                                            : l10n.createExercise,
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
      ),
    );
  }
}
