import 'package:flutter/material.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/exercise.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/widgets/exercise_form_sheet.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/widgets/exercise_list_view.dart';

/// Standalone screen for browsing, creating, editing and deleting exercises.
///
/// Organised as scrollable tabs: "All" exercises followed by one tab per
/// muscle group. Tapping an exercise opens its edit form directly (no
/// selection / workout-assignment takes place here).
class ExerciseManagementScreen extends StatefulWidget {
  const ExerciseManagementScreen({super.key});

  @override
  State<ExerciseManagementScreen> createState() =>
      _ExerciseManagementScreenState();
}

class _ExerciseManagementScreenState extends State<ExerciseManagementScreen>
    with SingleTickerProviderStateMixin {
  // "All" + one entry per MuscleGroup
  static const _tabs = [null, ...MuscleGroup.values];

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _tabLabel(MuscleGroup? mg) {
    if (mg == null) return 'All';
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Exercises'),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: _tabs.map((mg) => Tab(text: _tabLabel(mg))).toList(),
          ),
        ),
        // Each tab gets its own ExerciseListView in management mode
        // (onExerciseSelected is omitted → tap = edit, no add-to-workout icon).
        body: TabBarView(
          controller: _tabController,
          children:
              _tabs.map((mg) => ExerciseListView(muscleGroup: mg)).toList(),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            // Pre-select the currently visible muscle group (if any).
            final currentMg = _tabs[_tabController.index];
            await ExerciseFormSheet.show(
              context,
              initialMuscleGroup: currentMg,
            );
            // The ExerciseListView inside the active tab handles its own refresh
            // via its internal _refreshKey, triggered by ExerciseFormSheet.
            // We call setState here to propagate any needed parent rebuild.
            if (mounted) setState(() {});
          },
          icon: const Icon(Icons.add),
          label: const Text('New Exercise'),
        ),
      ),
    );
  }
}
