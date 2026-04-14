import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/exercise.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/widgets/exercise_form_sheet.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// Widget that displays a searchable list of exercises.
///
/// **Selection mode** (for workout creation):
///   Provide [onExerciseSelected]. Tapping an exercise card passes it to the
///   callback. An "add" icon is shown on the trailing side of each card.
///
/// **Management mode** (standalone exercise manager):
///   Omit [onExerciseSelected] (leave it null). Tapping an exercise card opens
///   the edit form directly. Only the edit icon is shown in the trailing area.
///
/// When [muscleGroup] is null all exercises are shown regardless of group.
class ExerciseListView extends StatefulWidget {
  final MuscleGroup? muscleGroup;
  final Function(Exercise)? onExerciseSelected;

  const ExerciseListView({Key? key, this.muscleGroup, this.onExerciseSelected})
    : super(key: key);

  @override
  State<ExerciseListView> createState() => _ExerciseListViewState();
}

class _ExerciseListViewState extends State<ExerciseListView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  // Incrementing forces the FutureBuilder to re-run after create/edit/delete.
  int _refreshKey = 0;

  bool get _selectionMode => widget.onExerciseSelected != null;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCreateForm() async {
    final saved = await ExerciseFormSheet.show(
      context,
      initialMuscleGroup: widget.muscleGroup,
    );
    if (saved == true) setState(() => _refreshKey++);
  }

  Future<void> _openEditForm(Exercise exercise) async {
    final saved = await ExerciseFormSheet.show(context, exercise: exercise);
    if (saved == true) setState(() => _refreshKey++);
  }

  // Fetches exercises according to current filters.
  Future<List<ExerciseTableData>> _fetchExercises(AppDatabase db) {
    final mg = widget.muscleGroup;
    return mg != null
        ? db.exerciseDao.searchExercisesByMuscleGroup(mg, _searchQuery)
        : db.exerciseDao.searchExercises(_searchQuery);
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // ── Search bar ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.searchExercisesHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon:
                  _searchQuery.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                      : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),

        // ── Create custom exercise button ─────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Card(
            elevation: 0,
            color: theme.colorScheme.primaryContainer.withOpacity(0.45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.primary.withOpacity(0.25),
              ),
            ),
            child: ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                child: Icon(
                  Icons.add,
                  color: theme.colorScheme.onPrimary,
                  size: 20,
                ),
              ),
              title: Text(l10n.createCustomExercise),
              onTap: _openCreateForm,
            ),
          ),
        ),

        // ── Exercise list ─────────────────────────────────────────────────
        Expanded(
          child: FutureBuilder<List<ExerciseTableData>>(
            key: ValueKey('$_refreshKey:${widget.muscleGroup}:$_searchQuery'),
            future: _fetchExercises(db),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(l10n.errorLoadingExercises(snapshot.error!)),
                );
              }

              final exercises = snapshot.data ?? [];

              if (exercises.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fitness_center,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? l10n.noExercisesYet
                            : l10n.noExercisesFoundForQuery(_searchQuery),
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: exercises.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final exercise = db.exerciseDao.entityToModel(
                    exercises[index],
                  );

                  return _ExerciseListItem(
                    exercise: exercise,
                    selectionMode: _selectionMode,
                    onTap:
                        _selectionMode
                            ? () => widget.onExerciseSelected!(exercise)
                            : () => _openEditForm(exercise),
                    onEdit: () => _openEditForm(exercise),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ExerciseListItem extends StatelessWidget {
  final Exercise exercise;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _ExerciseListItem({
    Key? key,
    required this.exercise,
    required this.selectionMode,
    required this.onTap,
    required this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: selectionMode,
        leading: CircleAvatar(
          radius: selectionMode ? 18 : 20,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            _exerciseTypeIcon(exercise.type),
            size: selectionMode ? 18 : 20,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(exercise.localizedName(languageCode))),
            if (exercise.isCustom) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.customBadge,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: exercise.localizedDescription(languageCode) != null &&
                exercise.localizedDescription(languageCode)!.isNotEmpty
            ? Text(
                exercise.localizedDescription(languageCode)!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: selectionMode
            ? Icon(Icons.add_circle_outline, color: theme.colorScheme.primary)
            : IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                tooltip: l10n.editExercise,
                visualDensity: VisualDensity.compact,
                onPressed: onEdit,
              ),
        onTap: onTap,
      ),
    );
  }

  IconData _exerciseTypeIcon(ExerciseType type) {
    switch (type) {
      case ExerciseType.strength:
        return Icons.fitness_center;
      case ExerciseType.cardio:
        return Icons.directions_run;
      case ExerciseType.flexibility:
        return Icons.self_improvement;
      case ExerciseType.calisthenics:
        return Icons.accessibility_new;
    }
  }
}
