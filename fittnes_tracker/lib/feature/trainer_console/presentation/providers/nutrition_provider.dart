import 'package:flutter/foundation.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';

class NutritionProvider extends ChangeNotifier {
  final TrainerConsoleRepository _repository;

  NutritionProvider({TrainerConsoleRepository? repository})
    : _repository = repository ?? TrainerConsoleRepository();

  ClientNutritionSummary? _summary;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _error;

  ClientNutritionSummary? get summary => _summary;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load(String clientId) async {
    // TODO: fetch nutrition summary for clientId + _selectedDate via
    // _repository, set loading/error state.
  }

  void previousDay(String clientId) {
    // TODO: _selectedDate -= 1 day, reload.
  }

  void nextDay(String clientId) {
    // TODO: _selectedDate += 1 day, reload.
  }
}
