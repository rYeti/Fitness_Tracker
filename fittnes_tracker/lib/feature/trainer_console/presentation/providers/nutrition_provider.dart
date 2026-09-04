import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/console_error.dart';

class NutritionProvider extends ChangeNotifier {
  final TrainerConsoleRepository _repository;
  final Logger _logger = Logger();

  NutritionProvider({TrainerConsoleRepository? repository})
    : _repository = repository ?? TrainerConsoleRepository();

  ClientNutritionSummary? _summary;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  ConsoleError? _error;
  String? _loadedClientId;

  ClientNutritionSummary? get summary => _summary;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;
  ConsoleError? get error => _error;
  String? get loadedClientId => _loadedClientId;

  /// Nothing after today can have been eaten yet, so the day-switcher stops
  /// there rather than paging into empty future days.
  bool get canGoForward {
    final today = DateTime.now();
    final selected = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    return selected.isBefore(DateTime(today.year, today.month, today.day));
  }

  Future<void> load(String clientId) async {
    _isLoading = true;
    _error = null;
    // Drop the old client's numbers immediately — showing one client's intake
    // under another's name is worse than a skeleton.
    _summary = null;
    _loadedClientId = clientId;
    final requestedDate = _selectedDate;
    notifyListeners();

    try {
      final summary = await _repository.getClientNutritionSummary(
        clientId,
        requestedDate,
      );
      // Ignore a slow response the trainer has already navigated away from.
      if (!_isCurrentRequest(clientId, requestedDate)) return;
      _summary = summary;
    } catch (e, stackTrace) {
      // The trainer only ever sees "could not load"; without this the cause
      // never surfaced anywhere, which is how a server-side 500 went unnoticed.
      _logger.e(
        'Nutrition summary failed for client $clientId on $requestedDate',
        error: e,
        stackTrace: stackTrace,
      );
      if (!_isCurrentRequest(clientId, requestedDate)) return;
      _error = ConsoleError.loadNutrition;
    } finally {
      if (_isCurrentRequest(clientId, requestedDate)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  bool _isCurrentRequest(String clientId, DateTime date) =>
      _loadedClientId == clientId && _selectedDate == date;

  void previousDay(String clientId) {
    _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    load(clientId);
  }

  void nextDay(String clientId) {
    if (!canGoForward) return;
    _selectedDate = _selectedDate.add(const Duration(days: 1));
    load(clientId);
  }

  /// Transient — cleared as soon as another pin toggle is attempted, and
  /// distinct from [error]: a failed pin write shouldn't replace the whole
  /// screen with an error view when the trainer can just try again.
  ConsoleError? _pinError;
  ConsoleError? get pinError => _pinError;

  /// Adds or removes [key] from the pinned set, optimistically — the bar
  /// list updates immediately rather than waiting on a round trip. Reverts
  /// and surfaces [pinError] if the write fails; never leaves the UI
  /// claiming a selection the server never saved.
  Future<void> togglePin(String clientId, String key) async {
    final current = _summary;
    if (current == null) return;

    final before = current.pinnedNutrients;
    final after = before.contains(key)
        ? before.where((k) => k != key).toList()
        : [...before, key];

    _pinError = null;
    _summary = _withPins(current, after);
    notifyListeners();

    try {
      await _repository.setClientNutrientPins(clientId, after);
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to save nutrient pins for client $clientId',
        error: e,
        stackTrace: stackTrace,
      );
      // Only revert if this is still the client/day being shown — a slow
      // failure for a pin toggle on a screen the trainer has since navigated
      // away from must not silently rewrite what they're looking at now.
      if (!_isCurrentRequest(clientId, _selectedDate)) return;
      _summary = _withPins(_summary ?? current, before);
      _pinError = ConsoleError.saveNutrientPins;
      notifyListeners();
    }
  }

  static ClientNutritionSummary _withPins(
    ClientNutritionSummary summary,
    List<String> pins,
  ) => ClientNutritionSummary(
    date: summary.date,
    calorieGoal: summary.calorieGoal,
    totalCalories: summary.totalCalories,
    macros: summary.macros,
    loggedMeals: summary.loggedMeals,
    sevenDayTrend: summary.sevenDayTrend,
    micronutrients: summary.micronutrients,
    micronutrientsLocked: summary.micronutrientsLocked,
    pinnedNutrients: pins,
  );
}
