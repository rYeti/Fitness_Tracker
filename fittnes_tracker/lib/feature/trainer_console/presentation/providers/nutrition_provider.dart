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

  /// Which read of the summary is the latest; only its answer is applied.
  int _request = 0;

  /// Bumped when a pin write starts and when it ends, with [_pinWrites]
  /// counting those in flight. A read that overlapped a write can't tell
  /// whether its pins are from before the write or after, so it keeps the
  /// pins on screen and takes everything else — the write's own outcome is
  /// what settles them.
  int _pinEpoch = 0;
  int _pinWrites = 0;

  /// Loads [clientId]'s summary for the selected day.
  ///
  /// [keepShown] is a refresh of the client and day already on screen — the
  /// console heard that their data changed. The summary stays up while it
  /// reads, and a failed read keeps it rather than replacing it with an error
  /// (`docs/sync-architecture.md`, part four). For another client, or before
  /// the first load has settled, it is an ordinary load.
  Future<void> load(String clientId, {bool keepShown = false}) async {
    final request = ++_request;
    final keep = keepShown && _loadedClientId == clientId && !_isLoading;
    final requestedDate = _selectedDate;
    final pinEpoch = _pinEpoch;
    final pinWritesAtStart = _pinWrites;
    if (!keep) {
      _isLoading = true;
      _error = null;
      // Drop the old client's numbers immediately — showing one client's
      // intake under another's name is worse than a skeleton.
      _summary = null;
      _loadedClientId = clientId;
      notifyListeners();
    }

    try {
      final summary = await _repository.getClientNutritionSummary(
        clientId,
        requestedDate,
      );
      // Ignore a slow response the trainer has already navigated away from,
      // or one a later read has overtaken.
      if (!_isCurrentRequest(request, clientId, requestedDate)) return;
      final shown = _summary;
      final pinsOverlapped = pinEpoch != _pinEpoch || pinWritesAtStart > 0;
      _summary = shown != null && pinsOverlapped
          ? _withPins(summary, shown.pinnedNutrients)
          : summary;
      _error = null;
    } catch (e, stackTrace) {
      // The trainer only ever sees "could not load"; without this the cause
      // never surfaced anywhere, which is how a server-side 500 went unnoticed.
      _logger.e(
        'Nutrition summary failed for client $clientId on $requestedDate',
        error: e,
        stackTrace: stackTrace,
      );
      if (!_isCurrentRequest(request, clientId, requestedDate) || keep) return;
      _error = ConsoleError.loadNutrition;
    } finally {
      if (_isCurrentRequest(request, clientId, requestedDate)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  bool _isCurrentRequest(int request, String clientId, DateTime date) =>
      request == _request && _isShowing(clientId, date);

  bool _isShowing(String clientId, DateTime date) =>
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
    _pinEpoch++;
    _pinWrites++;
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
      if (!_isShowing(clientId, _selectedDate)) return;
      _summary = _withPins(_summary ?? current, before);
      _pinError = ConsoleError.saveNutrientPins;
      notifyListeners();
    } finally {
      _pinEpoch++;
      _pinWrites--;
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
