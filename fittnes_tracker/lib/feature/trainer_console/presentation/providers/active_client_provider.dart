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

  /// Loads the trainer's roster and defaults the selection to the first
  /// client. Safe to call more than once; a reload keeps the current
  /// selection if that client is still on the roster.
  Future<void> loadClients() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _clients = await _repository.getRosterWithStats();
      final stillPresent =
          _clients.any((c) => c.clientId == _activeClientId);
      if (!stillPresent) {
        _activeClientId = _clients.isEmpty ? null : _clients.first.clientId;
      }
    } catch (_) {
      _error = ConsoleError.loadRoster;
    } finally {
      _isLoading = false;
      notifyListeners();
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
