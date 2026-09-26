import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/console_error.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/pane_reads.dart';

class ClientDetailProvider extends ChangeNotifier {
  final TrainerConsoleRepository _repository;
  final Logger _logger = Logger();
  final String clientId;

  ClientDetailProvider({
    required this.clientId,
    TrainerConsoleRepository? repository,
  }) : _repository = repository ?? TrainerConsoleRepository();

  ClientWorkoutSummary? _workoutSummary;
  List<ClientWeightEntry> _weightHistory = [];
  ClientNutritionSummary? _nutrition;
  ConsoleError? _error;
  final _reads = PaneReads();

  ClientWorkoutSummary? get workoutSummary => _workoutSummary;
  List<ClientWeightEntry> get weightHistory => _weightHistory;
  ClientNutritionSummary? get nutrition => _nutrition;
  bool get isLoading => _reads.isLoading;
  ConsoleError? get error => _error;

  /// Whether any section of the last refresh failed, so what it shows is
  /// older than it could be.
  bool get refreshFailed => _reads.refreshFailed;

  /// Whether any of the three sections came back. Lets the screen show what did load
  /// instead of blanking on a single failed endpoint.
  bool get hasAnyData =>
      _workoutSummary != null || _weightHistory.isNotEmpty || _nutrition != null;

  /// Fetches the three sources this screen composes, in parallel and
  /// independently of each other.
  ///
  /// Each settles on its own: one endpoint failing costs its own section and nothing
  /// else. A single `Future.wait` with one try/catch used to mean any one of the three
  /// blanked the whole screen — a nutrition outage hid the client's training — and left
  /// the log as the only record of which had failed.
  ///
  /// [keepShown] is a refresh — the console heard that this client's data
  /// changed. It raises no loading state, and a section whose read fails keeps
  /// what it showed and sets [refreshFailed] (`docs/sync-architecture.md`,
  /// part four).
  Future<void> load({bool keepShown = false}) async {
    final read = _reads.start(keepShown: keepShown);
    if (read.isLoad) {
      _error = null;
      notifyListeners();
    }

    final failed = await Future.wait([
      _loadSection(
        read,
        'workout summary',
        () => _repository.getClientWorkoutSummary(clientId),
        (summary) => _workoutSummary = summary,
      ),
      _loadSection(
        read,
        'weight history',
        () => _repository.getClientWeightHistory(clientId),
        (history) => _weightHistory = history,
      ),
      _loadSection(
        read,
        'nutrition summary',
        () => _repository.getClientNutritionSummary(clientId, DateTime.now()),
        (nutrition) => _nutrition = nutrition,
      ),
    ]);

    // A later read has overtaken this one; its answers are the ones to show.
    final anyFailed = failed.contains(true);
    if (!read.settle(failed: anyFailed)) return;
    // A refresh is also how a screen that failed earlier recovers.
    if (!anyFailed) _error = null;
    notifyListeners();
  }

  /// Runs one section's fetch, recording a failure without letting it take the others
  /// down, and returns whether it failed. [what] only ever reaches the log — the trainer
  /// sees the screen's error state, or on a refresh the "couldn't refresh" notice.
  Future<bool> _loadSection<T>(
    PaneRead read,
    String what,
    Future<T> Function() fetch,
    void Function(T value) apply,
  ) async {
    try {
      final value = await fetch();
      if (read.isCurrent) apply(value);
      return false;
    } catch (e, stackTrace) {
      _logger.e(
        'Client detail $what failed for client $clientId',
        error: e,
        stackTrace: stackTrace,
      );
      if (read.isCurrent && read.isLoad) _error = ConsoleError.loadClientDetail;
      return true;
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
