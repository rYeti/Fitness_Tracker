import 'package:flutter/foundation.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';

enum RosterLayout { grid, table }

/// Drives the Dashboard roster + KPIs. Not the client-switcher shared state
/// used by Chat/Builder/Nutrition/Session Review — that's ActiveClientProvider.
class TrainerConsoleProvider extends ChangeNotifier {
  final TrainerConsoleRepository _repository;

  TrainerConsoleProvider({TrainerConsoleRepository? repository})
    : _repository = repository ?? TrainerConsoleRepository();

  List<TrainerRosterEntry> _roster = [];
  TrainerDashboardKpis? _kpis;
  bool _isLoading = false;
  String? _error;
  RosterLayout _layout = RosterLayout.grid;

  List<TrainerRosterEntry> get roster => _roster;
  TrainerDashboardKpis? get kpis => _kpis;
  bool get isLoading => _isLoading;
  String? get error => _error;
  RosterLayout get layout => _layout;

  void setLayout(RosterLayout layout) {
    if (_layout == layout) return;
    _layout = layout;
    notifyListeners();
  }

  /// Loads roster and KPIs together — the Dashboard shows both at once, so
  /// two separate spinners would just make it flicker twice.
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getRosterWithStats(),
        _repository.getDashboardKpis(),
      ]);
      _roster = results[0] as List<TrainerRosterEntry>;
      _kpis = results[1] as TrainerDashboardKpis;
    } catch (_) {
      _error = 'Could not load your dashboard.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
