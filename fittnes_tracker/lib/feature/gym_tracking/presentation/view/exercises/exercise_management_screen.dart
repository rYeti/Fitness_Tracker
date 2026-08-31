import 'package:flutter/material.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/exercise.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/widgets/exercise_form_sheet.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/widgets/exercise_list_view.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:ForgeForm/core/widgets/forge_app_bar.dart';
import 'package:ForgeForm/core/widgets/content_pane.dart';

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

  String _tabLabel(AppLocalizations l10n, MuscleGroup? mg) {
    if (mg == null) return l10n.all;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: ForgeAppBar(
        title: l10n.exercises,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs:
              _tabs.map((mg) => Tab(text: _tabLabel(l10n, mg))).toList(),
        ),
      ),
      body: ContentPane(
        child: TabBarView(
          controller: _tabController,
          children:
              _tabs.map((mg) => ExerciseListView(muscleGroup: mg)).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final currentMg = _tabs[_tabController.index];
          await ExerciseFormSheet.show(
            context,
            initialMuscleGroup: currentMg,
          );
          if (mounted) setState(() {});
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.newExercise),
      ),
    );
  }
}
