import 'package:flutter/foundation.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/console_error.dart';

/// Shared "client-switcher" state used by Workout Builder, Nutrition, Session
/// Review (and future Chat) — NOT Client Detail, which takes an explicit
/// clientId route argument instead. See trainer-console-spec / design handoff
/// README.
///
/// Owns the roster as well as the selection: a switcher needs the list it's
/// switching among, and every screen with a picker would otherwise re-fetch
/// it. Per CLAUDE.md this must be registered once at the app-shell level, not
/// per screen, so switching a client re-derives the visible panes without a
/// navigation reload.
///
/// It owns it for the Dashboard too. This used to read `api/TrainerClient/my-clients`
/// while the Dashboard separately read `api/TrainerConsole/roster` — two requests on every
/// console open, for the same list, from two different queries that could disagree with
/// each other. The roster endpoint is a superset (it carries programme and adherence as
/// well) and is already filtered to active relationships server-side, so this reads that
/// one and the Dashboard renders from here.
class ActiveClientProvider extends ChangeNotifier {
  final TrainerConsoleRepository _repository;

  ActiveClientProvider({TrainerConsoleRepository? repository})
    : _repository = repository ?? TrainerConsoleRepository();

  String? _activeClientId;
  bool _pickerOpen = false;
  List<TrainerRosterEntry> _clients = [];
  bool _isLoading = false;
  ConsoleError? _error;

  String? get activeClientId => _activeClientId;
  bool get pickerOpen => _pickerOpen;
  List<TrainerRosterEntry> get clients => _clients;
  bool get isLoading => _isLoading;
  ConsoleError? get error => _error;

  /// The selected client, or null when the roster is empty or still loading.
  TrainerRosterEntry? get activeClient {
    if (_clients.isEmpty) return null;
    final id = _activeClientId;
    if (id == null) return _clients.first;
    return _clients.where((c) => c.clientId == id).firstOrNull ?? _clients.first;
  }

  /// Which [loadClients] call is the latest; only its answer is applied.
  int _request = 0;

  /// Loads the trainer's roster and defaults the selection to the first
  /// client. Safe to call more than once; a reload keeps the current
  /// selection if that client is still on the roster.
  ///
  /// [keepShown] is a refresh — the console heard that a client's data
  /// changed. It raises no loading state, and a refresh that fails leaves
  /// the roster as it was rather than replacing it with an error: every
  /// client-scoped pane renders a full-page error while [error] is set, so a
  /// failed background read would otherwise blank whatever the trainer was
  /// looking at. Until the first load has settled there is nothing shown to
  /// keep, and it is an ordinary load.
  Future<void> loadClients({bool keepShown = false}) async {
    final request = ++_request;
    final keep = keepShown && !_isLoading;
    if (!keep) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final clients = await _repository.getRosterWithStats();
      // A slower, older answer must not overwrite a newer one.
      if (request != _request) return;
      _clients = clients;
      _error = null;
      final stillPresent =
          _clients.any((c) => c.clientId == _activeClientId);
      if (!stillPresent) {
        _activeClientId = _clients.isEmpty ? null : _clients.first.clientId;
      }
    } catch (_) {
      if (request != _request || keep) return;
      _error = ConsoleError.loadRoster;
    } finally {
      if (request == _request) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void setActiveClient(String clientId) {
    if (_activeClientId == clientId && !_pickerOpen) return;
    _activeClientId = clientId;
    _pickerOpen = false;
    notifyListeners();
  }

  void togglePicker() {
    _pickerOpen = !_pickerOpen;
    notifyListeners();
  }

  void closePicker() {
    if (!_pickerOpen) return;
    _pickerOpen = false;
    notifyListeners();
  }
}
