import 'package:flutter/foundation.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/console_error.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/pane_reads.dart';

/// Drives Session Review: a history list for the active client (shared
/// ActiveClientProvider selection, same as Builder/Nutrition — see
/// CLAUDE.md's client-switcher rule) plus the detail of whichever entry is
/// selected. Not itself the client-switcher; the screen composes this with
/// ActiveClientProvider the same way NutritionScreen composes
/// NutritionProvider.
class SessionReviewProvider extends ChangeNotifier {
  final TrainerConsoleRepository _repository;

  SessionReviewProvider({TrainerConsoleRepository? repository})
    : _repository = repository ?? TrainerConsoleRepository();

  List<ClientSessionSummary> _sessions = [];
  String? _selectedSessionId;
  ConsoleError? _error;
  final _reads = PaneReads();

  List<ClientSessionSummary> get sessions => _sessions;
  bool get isLoading => _reads.isLoading;
  ConsoleError? get error => _error;
  String? get selectedSessionId => _selectedSessionId;

  /// Whether the last refresh failed, so the sessions shown are older than
  /// they could be.
  bool get refreshFailed => _reads.refreshFailed && _error == null;

  /// The selected session, or the newest one when nothing's been picked yet.
  /// Null only when [sessions] is empty.
  ClientSessionSummary? get selected {
    if (_sessions.isEmpty) return null;
    final id = _selectedSessionId;
    if (id == null) return _sessions.first;
    return _sessions.where((s) => s.scheduledWorkoutId == id).firstOrNull ?? _sessions.first;
  }

  /// The client currently loaded, so the screen can tell an active-client
  /// switch apart from a first load without tracking it itself.
  String? _loadedClientId;
  String? get loadedClientId => _loadedClientId;

  /// Loads the client's sessions (newest first). One request covers both the
  /// list and every entry's detail, so there's no per-selection fetch.
  ///
  /// [keepShown] is a refresh of the client already on screen — the console
  /// heard that their data changed. It leaves the list, the selection and the
  /// state on screen as they are while it reads, and if the read fails it
  /// keeps them rather than swapping a populated review for an error, and
  /// sets [refreshFailed]. For another client, or before the first load has
  /// settled, it is an ordinary load: there is nothing of theirs on screen to
  /// keep ([PaneReads]).
  Future<void> load(String clientId, {bool keepShown = false}) async {
    final read = _reads.start(
      keepShown: keepShown,
      shown: _loadedClientId == clientId,
    );
    if (read.isLoad) {
      _error = null;
      // Drop the previous client's sessions immediately — showing one client's
      // history under another's name while the request is in flight would be
      // worse than showing the skeleton.
      _sessions = const [];
      _selectedSessionId = null;
      _loadedClientId = clientId;
      notifyListeners();
    }

    try {
      final sessions = await _repository.getClientSessionHistory(clientId);
      // A slow response for a client the trainer has already switched away
      // from — or one overtaken by a later read — must not overwrite the newer
      // one's data.
      if (!read.settle()) return;
      _sessions = sessions;
      _error = null;
    } catch (_) {
      if (!read.settle(failed: true)) return;
      if (read.isLoad) _error = ConsoleError.loadSessions;
    }
    notifyListeners();
  }

  /// Selects a session. Pure local state — the detail is already loaded.
  void selectSession(String scheduledWorkoutId) {
    if (_selectedSessionId == scheduledWorkoutId) return;
    _selectedSessionId = scheduledWorkoutId;
    notifyListeners();
  }
}
