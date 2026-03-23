import 'package:flutter/material.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/exercise.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/widgets/muscle_group_selector.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/widgets/exercise_list_view.dart';

/// Modal bottom sheet for selecting exercises by muscle group
class ExerciseSelectionModal extends StatefulWidget {
  final Function(Exercise) onExerciseSelected;

  const ExerciseSelectionModal({Key? key, required this.onExerciseSelected})
    : super(key: key);

  /// Shows the exercise selection modal
  static Future<Exercise?> show(BuildContext context) {
    return showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder:
                (context, scrollController) => Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: ExerciseSelectionModal(
                    onExerciseSelected: (exercise) {
                      Navigator.of(context).pop(exercise);
                    },
                  ),
                ),
          ),
    );
  }

  @override
  State<ExerciseSelectionModal> createState() => _ExerciseSelectionModalState();
}

class _ExerciseSelectionModalState extends State<ExerciseSelectionModal> {
  MuscleGroup? _selectedMuscleGroup;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // App bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              if (_selectedMuscleGroup != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _selectedMuscleGroup = null;
                    });
                  },
                ),
              Expanded(
                child: Text(
                  _selectedMuscleGroup == null
                      ? 'Select Muscle Group'
                      : 'Select Exercise',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
        // Content
        Expanded(
          child:
              _selectedMuscleGroup == null
                  ? MuscleGroupSelector(
                    onMuscleGroupSelected: (muscleGroup) {
                      setState(() {
                        _selectedMuscleGroup = muscleGroup;
                      });
                    },
                  )
                  : ExerciseListView(
                    muscleGroup: _selectedMuscleGroup!,
                    onExerciseSelected: widget.onExerciseSelected,
                  ),
        ),
      ],
    );
  }
}
