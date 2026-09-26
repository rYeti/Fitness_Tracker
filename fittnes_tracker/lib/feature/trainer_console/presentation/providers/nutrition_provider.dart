import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/console_error.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/pane_reads.dart';

class NutritionProvider extends ChangeNotifier {
  final TrainerConsoleRepository _repository;
  final Logger _logger = Logger();

  NutritionProvider({TrainerConsoleRepository? repository})
    : _repository = repository ?? TrainerConsoleRepository();

  ClientNutritionSummary? _summary;
  DateTime _selectedDate = DateTime.now();
  ConsoleError? _error;
  String? _loadedClientId;
  final _reads = PaneReads();

  ClientNutritionSummary? get summary => _summary;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _reads.isLoading;
  ConsoleError? get error => _error;
  String? get loadedClientId => _loadedClientId;

  /// Whether the last refresh failed, so the day shown is older than it
  /// could be.
  bool get refreshFailed => _reads.refreshFailed && _error == null;

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

  /// The pin set the latest pin write sent, and whose it is: optimistic
  /// while the write is in flight, what the server holds once it succeeds,
  /// and put back to the set before it if it fails.
  ///
  /// Pins are the trainer's per client, not per day, so every day's summary
  /// carries them — and a read that overlapped a write can't tell whether its
  /// pins are from before the write or after. This is laid over what such a
  /// read returns, so the write's own outcome is what settles the pins.
  ///
  /// It used to be read off the summary on screen instead. A day switch
  /// clears the summary before it reads, so the one read that most needed
  /// the guard — pin, then page to another day at once — found nothing to
  /// keep, took the old pins from a GET served before the PUT committed, and
  /// showed the pin as lost although it had saved.
  ({String clientId, List<String> keys})? _pinsWritten;

  /// Bumped when a pin write starts and when it ends, with [_pinWrites]
  /// counting those in flight: a read overlapped a write if either moved.
  int _pinEpoch = 0;
  int _pinWrites = 0;

  /// Loads [clientId]'s summary for the selected day.
  ///
  /// [keepShown] is a refresh of the client and day already on screen — the
  /// console heard that their data changed. The summary stays up while it
  /// reads, and a failed read keeps it rather than replacing it with an error,
  /// and sets [refreshFailed] (`docs/sync-architecture.md`, part four). For
  /// another client, or before the first load has settled, it is an ordinary
  /// load ([PaneReads]).
  Future<void> load(String clientId, {bool keepShown = false}) async {
    final read = _reads.start(
      keepShown: keepShown,
      shown: _loadedClientId == clientId,
    );
    final requestedDate = _selectedDate;
    final pinEpoch = _pinEpoch;
    final pinWritesAtStart = _pinWrites;
    if (read.isLoad) {
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
      if (!read.settle()) return;
      final pins = _pinsWritten;
      final pinsOverlapped = pinEpoch != _pinEpoch || pinWritesAtStart > 0;
      _summary = pinsOverlapped && pins != null && pins.clientId == clientId
          ? _withPins(summary, pins.keys)
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
      if (!read.settle(failed: true)) return;
      if (read.isLoad) _error = ConsoleError.loadNutrition;
    }
    notifyListeners();
  }

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
    final written = (clientId: clientId, keys: after);
    _pinsWritten = written;
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
      // A later toggle has sent the whole set again since, and its own
      // outcome settles the pins; putting this one's "before" back would
      // undo it on screen.
      if (identical(_pinsWritten, written)) {
        _pinsWritten = (clientId: clientId, keys: before);
      }
      // Only on screen if this is still the client being shown — a slow
      // failure for a client the trainer has since left must not rewrite
      // what they're looking at now. Any day of theirs: pins aren't per day.
      if (_loadedClientId != clientId) return;
      final shown = _summary;
      final pins = _pinsWritten;
      if (shown != null && pins != null && pins.clientId == clientId) {
        _summary = _withPins(shown, pins.keys);
      }
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
