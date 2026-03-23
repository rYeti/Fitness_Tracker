import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/exercise.dart';

/// Widget that displays a searchable list of exercises for a specific muscle group
class ExerciseListView extends StatefulWidget {
  final MuscleGroup muscleGroup;
  final Function(Exercise) onExerciseSelected;

  const ExerciseListView({
    Key? key,
    required this.muscleGroup,
    required this.onExerciseSelected,
  }) : super(key: key);

  @override
  State<ExerciseListView> createState() => _ExerciseListViewState();
}

class _ExerciseListViewState extends State<ExerciseListView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search exercises...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon:
                  _searchQuery.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                      : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        // Exercise list
        Expanded(
          child: FutureBuilder<List<ExerciseTableData>>(
            future: db.exerciseDao.searchExercisesByMuscleGroup(
              widget.muscleGroup,
              _searchQuery,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final exercises = snapshot.data ?? [];

              if (exercises.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.fitness_center,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No exercises available for this muscle group'
                            : 'No exercises found matching "$_searchQuery"',
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
                  final exerciseData = exercises[index];
                  final exercise = db.exerciseDao.entityToModel(exerciseData);

                  return _ExerciseListItem(
                    exercise: exercise,
                    onTap: () => widget.onExerciseSelected(exercise),
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
  final VoidCallback onTap;

  const _ExerciseListItem({
    Key? key,
    required this.exercise,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            _getExerciseTypeIcon(exercise.type),
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(exercise.name),
        subtitle:
            exercise.description != null && exercise.description!.isNotEmpty
                ? Text(
                  exercise.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
                : null,
        trailing: const Icon(Icons.add_circle_outline),
        onTap: onTap,
      ),
    );
  }

  IconData _getExerciseTypeIcon(ExerciseType type) {
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
