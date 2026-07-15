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
  ClientWorkoutHistory? _selectedDayHistory;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _error;

  ClientWorkoutSummary? get workoutSummary => _workoutSummary;
  ClientWorkoutHistory? get selectedDayHistory => _selectedDayHistory;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    // TODO: fetch workout summary + weight history + nutrition summary for
    // clientId via _repository, set loading/error state.
  }

  void previousDay() {
    // TODO: _selectedDate -= 1 day, reload that day's workout history.
  }

  void nextDay() {
    // TODO: _selectedDate += 1 day, reload that day's workout history.
  }
}
