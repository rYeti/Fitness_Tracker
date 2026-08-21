import 'package:flutter/foundation.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/console_error.dart';

/// Drives the Workout Builder's create/edit state machine (see design handoff).
/// Deliberately separate from the trainee-facing `WorkoutProvider`
/// (gym_tracking) — that provider edits the signed-in user's own workouts, not
/// a trainer editing a client's plan.
///
/// Scope note: only plan *creation* actually writes. `WorkoutPlanRequestDto`
/// carries plan metadata alone (name/description/start/cycle pattern), and
/// `IWorkoutService` is caller-scoped with no trainer-facing variant, so the
/// design's per-exercise/set editor has no endpoint to save through. The
/// screen shows the client's current plan read-only rather than offering a
/// save button that would silently do nothing.
class WorkoutBuilderProvider extends ChangeNotifier {
  final TrainerConsoleRepository _repository;

  WorkoutBuilderProvider({TrainerConsoleRepository? repository})
    : _repository = repository ?? TrainerConsoleRepository();

  bool _isNew = false;
  List<WorkoutPlanTemplateSummary> _templates = [];
  WorkoutPlanSummary? _currentPlan;
  bool _isLoading = false;
  bool _isSaving = false;
  ConsoleError? _error;
  String? _loadedClientId;

  bool get isNew => _isNew;
  List<WorkoutPlanTemplateSummary> get templates => _templates;
  WorkoutPlanSummary? get currentPlan => _currentPlan;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  ConsoleError? get error => _error;
  String? get loadedClientId => _loadedClientId;

  /// Loads the templates for the create flow plus the client's active plan for
  /// the read-only view.
  Future<void> load(String clientId) async {
    _isLoading = true;
    _error = null;
    _currentPlan = null;
    _loadedClientId = clientId;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getWorkoutPlanTemplates(),
        _repository.getClientWorkoutSummary(clientId),
      ]);
      if (_loadedClientId != clientId) return;
      _templates = results[0] as List<WorkoutPlanTemplateSummary>;
      _currentPlan = (results[1] as ClientWorkoutSummary).currentPlan;
      // A client with no plan lands straight in the create flow — there's
      // nothing to show them otherwise.
      _isNew = _currentPlan == null;
    } catch (_) {
      if (_loadedClientId != clientId) return;
      _error = ConsoleError.loadWorkoutPlans;
    } finally {
      if (_loadedClientId == clientId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void startNewPlan() {
    if (_isNew) return;
    _isNew = true;
    notifyListeners();
  }

  void cancelNewPlan() {
    // Nothing to go back to if they have no plan.
    if (!_isNew || _currentPlan == null) return;
    _isNew = false;
    notifyListeners();
  }

  /// Creates and assigns a plan. Returns true on success so the screen can
  /// confirm; the error is exposed via [error] on failure.
  Future<bool> createPlan({
    required String clientId,
    required String name,
    String? description,
  }) async {
    if (name.trim().isEmpty) {
      _error = ConsoleError.planNameRequired;
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final plan = await _repository.createClientWorkoutPlan(
        clientId: clientId,
        name: name.trim(),
        description: description?.trim(),
      );
      _currentPlan = plan;
      _isNew = false;
      return true;
    } catch (_) {
      _error = ConsoleError.createPlan;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
