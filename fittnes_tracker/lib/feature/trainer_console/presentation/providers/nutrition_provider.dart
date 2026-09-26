import 'dart:async';

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

  /// Every read of the summary, and every pin write. A refresh a pin write
  /// overlapped is read again once no write is in flight.
  late final _reads = PaneReads(
    onRefreshOwed: () {
      final clientId = _loadedClientId;
      if (clientId != null) unawaited(load(clientId, keepShown: true));
    },
  );

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

  /// The pin set the latest toggle sent, and whose it is. Pins are the
  /// trainer's per client, not per day, and each write sends the whole set,
  /// so while writes are in flight this is what the server will hold if the
  /// latest succeeds — and what a load they overlapped shows.
  ///
  /// It used to be read off the summary on screen instead. A day switch
  /// clears the summary before it reads, so the one read that most needed
  /// the guard — pin, then page to another day at once — found nothing to
  /// keep, took the old pins from a GET served before the PUT committed, and
  /// showed the pin as lost although it had saved.
  ({String clientId, List<String> keys})? _pinsSent;

  /// Whether the write [_pinsSent] made has failed. Its outcome is the one
  /// that settles the pins, but only once no write is in flight any more.
  bool _latestPinWriteFailed = false;

  /// The last pin set the server confirmed, per client: the last write that
  /// succeeded, or what a read that no write overlapped returned. What the
  /// pins go back to when the latest write fails.
  ///
  /// Not the set on screen when that write was sent. With two toggles in
  /// flight, the second one's "before" is the first one's optimistic set,
  /// which the server holds only if the first succeeded. Restoring it after
  /// both failed showed a pin the server never saved, in either order.
  final Map<String, List<String>> _pinsConfirmed = {};

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
      _summary = _withPinsKept(clientId, summary, read);
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

  /// [summary] as read for [clientId], with the pins a pin write it
  /// overlapped has settled — or is settling — in place of its own.
  ///
  /// A read a pin write overlapped can't tell whether its pins are from
  /// before the write or after. A refresh like that is dropped and read again
  /// ([PaneReads.write]); this is for a load, such as a day switch, which is
  /// applied. While a write is in flight it shows what the latest toggle
  /// sent, and once none is, what the server confirmed.
  ClientNutritionSummary _withPinsKept(
    String clientId,
    ClientNutritionSummary summary,
    PaneRead read,
  ) {
    final sent = _pinsSent;
    if (read.overlappedWrite && sent != null && sent.clientId == clientId) {
      final pins = _reads.isWriting ? sent.keys : _pinsConfirmed[clientId];
      if (pins != null) return _withPins(summary, pins);
    }
    _pinsConfirmed[clientId] = summary.pinnedNutrients;
    return summary;
  }

  /// Adds or removes [key] from the pinned set, optimistically — the bar
  /// list updates immediately rather than waiting on a round trip. If the
  /// latest toggle's write fails, puts back the last set the server confirmed
  /// and surfaces [pinError]; never leaves the UI claiming a selection the
  /// server never saved.
  ///
  /// Each write sends the whole set, so with several in flight it is the
  /// latest toggle's outcome that settles the pins, once the last of them
  /// has settled. An earlier write that fails meanwhile changes nothing: the
  /// later one sent its pins again.
  Future<void> togglePin(String clientId, String key) async {
    final current = _summary;
    if (current == null) return;

    final shown = current.pinnedNutrients;
    final after = shown.contains(key)
        ? shown.where((k) => k != key).toList()
        : [...shown, key];

    _pinError = null;
    _summary = _withPins(current, after);
    final sent = (clientId: clientId, keys: after);
    _pinsSent = sent;
    _latestPinWriteFailed = false;
    notifyListeners();

    final saved = await _reads.write(() async {
      try {
        await _repository.setClientNutrientPins(clientId, after);
        return true;
      } catch (e, stackTrace) {
        _logger.e(
          'Failed to save nutrient pins for client $clientId',
          error: e,
          stackTrace: stackTrace,
        );
        return false;
      }
    });
    if (saved) {
      _pinsConfirmed[clientId] = after;
    } else if (identical(_pinsSent, sent)) {
      _latestPinWriteFailed = true;
    }

    // The last write in flight decides, whichever it is.
    if (_reads.isWriting || !_latestPinWriteFailed) return;
    _latestPinWriteFailed = false;
    final latest = _pinsSent!;
    // Only on screen if this is still the client being shown — a slow
    // failure for a client the trainer has since left must not rewrite what
    // they're looking at now. Any day of theirs: pins aren't per day.
    if (_loadedClientId != latest.clientId) return;
    final shownNow = _summary;
    if (shownNow != null) {
      _summary = _withPins(shownNow, _pinsConfirmed[latest.clientId] ?? const []);
    }
    _pinError = ConsoleError.saveNutrientPins;
    notifyListeners();
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
