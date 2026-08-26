import 'package:flutter/foundation.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/console_error.dart';

enum RosterLayout { grid, table }

/// Drives the Dashboard's KPI row and its grid/table toggle.
///
/// It does *not* own the roster. The roster is the client-switcher's list, which lives in
/// ActiveClientProvider at the app-shell level, and the Dashboard renders from there — one
/// request for one list, rather than the two this used to make.
///
/// Keeping the KPIs separate is the point rather than an accident: they load independently
/// of the roster, so the trainer sees their clients as soon as that request lands instead
/// of waiting on a `Future.wait` for both.
class TrainerConsoleProvider extends ChangeNotifier {
  final TrainerConsoleRepository _repository;

  TrainerConsoleProvider({TrainerConsoleRepository? repository})
    : _repository = repository ?? TrainerConsoleRepository();

  TrainerDashboardKpis? _kpis;
  bool _isLoading = false;
  ConsoleError? _error;
  RosterLayout _layout = RosterLayout.grid;

  TrainerDashboardKpis? get kpis => _kpis;
  bool get isLoading => _isLoading;
  ConsoleError? get error => _error;
  RosterLayout get layout => _layout;

  void setLayout(RosterLayout layout) {
    if (_layout == layout) return;
    _layout = layout;
    notifyListeners();
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _kpis = await _repository.getDashboardKpis();
    } catch (_) {
      _error = ConsoleError.loadDashboard;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
