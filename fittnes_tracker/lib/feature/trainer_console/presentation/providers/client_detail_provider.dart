import 'package:flutter/foundation.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';

class ClientDetailProvider extends ChangeNotifier {
  final TrainerConsoleRepository _repository;
  final String clientId;

  ClientDetailProvider({
    required this.clientId,
    TrainerConsoleRepository? repository,
  }) : _repository = repository ?? TrainerConsoleRepository();

  ClientWorkoutSummary? _workoutSummary;
  List<ClientWeightEntry> _weightHistory = [];
  ClientNutritionSummary? _nutrition;
  bool _isLoading = false;
  String? _error;

  ClientWorkoutSummary? get workoutSummary => _workoutSummary;
  List<ClientWeightEntry> get weightHistory => _weightHistory;
  ClientNutritionSummary? get nutrition => _nutrition;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetches the three sources this screen composes in parallel — they're
  /// independent endpoints and the screen shows them together.
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getClientWorkoutSummary(clientId),
        _repository.getClientWeightHistory(clientId),
        _repository.getClientNutritionSummary(clientId, DateTime.now()),
      ]);
      _workoutSummary = results[0] as ClientWorkoutSummary;
      _weightHistory = results[1] as List<ClientWeightEntry>;
      _nutrition = results[2] as ClientNutritionSummary;
    } catch (_) {
      _error = 'Could not load this client’s details.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Net weight change across the logged history, or null with fewer than two
  /// entries (a single reading isn't a trend).
  double? get weightDelta {
    if (_weightHistory.length < 2) return null;
    return _weightHistory.last.weight - _weightHistory.first.weight;
  }

  /// Completed / planned across every attendance week the summary returned.
  double? get overallAdherence {
    final weeks = _workoutSummary?.attendance ?? const [];
    final planned = weeks.fold<int>(0, (sum, w) => sum + w.plannedSessions);
    if (planned == 0) return null;
    final completed = weeks.fold<int>(0, (sum, w) => sum + w.completedSessions);
    return completed / planned * 100;
  }
}
