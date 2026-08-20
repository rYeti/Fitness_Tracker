import 'package:flutter/foundation.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';

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
  bool _isLoading = false;
  String? _error;

  List<ClientSessionSummary> get sessions => _sessions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedSessionId => _selectedSessionId;

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
  Future<void> load(String clientId) async {
    _isLoading = true;
    _error = null;
    // Drop the previous client's sessions immediately — showing one client's
    // history under another's name while the request is in flight would be
    // worse than showing the skeleton.
    _sessions = const [];
    _selectedSessionId = null;
    _loadedClientId = clientId;
    notifyListeners();

    try {
      final sessions = await _repository.getClientSessionHistory(clientId);
      // A slow response for a client the trainer has already switched away
      // from must not overwrite the newer one's data.
      if (_loadedClientId != clientId) return;
      _sessions = sessions;
    } catch (_) {
      if (_loadedClientId != clientId) return;
      _error = 'Could not load this client’s sessions.';
    } finally {
      if (_loadedClientId == clientId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Selects a session. Pure local state — the detail is already loaded.
  void selectSession(String scheduledWorkoutId) {
    if (_selectedSessionId == scheduledWorkoutId) return;
    _selectedSessionId = scheduledWorkoutId;
    notifyListeners();
  }
}
