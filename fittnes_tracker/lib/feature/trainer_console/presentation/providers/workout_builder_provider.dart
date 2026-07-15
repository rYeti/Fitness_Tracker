import 'package:flutter/foundation.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';

/// Drives the Workout Builder's isBuilderNew/isBuilderEdit state machine
/// (see design handoff). Deliberately separate from the trainee-facing
/// `WorkoutProvider` (gym_tracking) — that provider edits the signed-in
/// user's own workouts, not a trainer editing a client's plan.
class WorkoutBuilderProvider extends ChangeNotifier {
  final TrainerConsoleRepository _repository;

  WorkoutBuilderProvider({TrainerConsoleRepository? repository})
    : _repository = repository ?? TrainerConsoleRepository();

  bool _isNew = true;
  List<WorkoutPlanTemplateSummary> _templates = [];
  bool _isLoading = false;
  String? _error;

  bool get isNew => _isNew;
  List<WorkoutPlanTemplateSummary> get templates => _templates;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadTemplates() async {
    // TODO: fetch templates via _repository.getWorkoutPlanTemplates().
  }

  void startNewPlan() {
    // TODO: _isNew = true, notifyListeners().
  }

  void startFromTemplate(String templateId) {
    // TODO: _isNew = false, load the template into an editable plan draft.
  }

  Future<void> assignToClient(String clientId) async {
    // TODO: POST the current plan draft via
    // _repository (needs a createClientWorkoutPlan/updateClientWorkoutPlan
    // wrapper analogous to the other repository methods).
  }
}
