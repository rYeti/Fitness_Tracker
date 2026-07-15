import 'package:flutter/foundation.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_client_summary.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';

enum RosterLayout { grid, table }

/// Drives the Dashboard roster + KPIs. Not the client-switcher shared state
/// used by Chat/Builder/Nutrition — that's a separate provider to add when
/// those screens are picked up.
class TrainerConsoleProvider extends ChangeNotifier {
  final TrainerConsoleRepository _repository;

  TrainerConsoleProvider({TrainerConsoleRepository? repository})
    : _repository = repository ?? TrainerConsoleRepository();

  List<TrainerClientSummary> _roster = [];
  bool _isLoading = false;
  String? _error;
  RosterLayout _layout = RosterLayout.grid;

  List<TrainerClientSummary> get roster => _roster;
  bool get isLoading => _isLoading;
  String? get error => _error;
  RosterLayout get layout => _layout;

  void setLayout(RosterLayout layout) {
    if (_layout == layout) return;
    _layout = layout;
    notifyListeners();
  }

  Future<void> loadRoster() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _roster = await _repository.getRoster();
    } catch (e) {
      _error = 'Could not load your clients.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  TrainerDashboardKpis? _kpis;
  TrainerDashboardKpis? get kpis => _kpis;

  Future<void> loadKpis() async {
    // TODO: fetch via _repository.getDashboardKpis(), set _kpis,
    // notifyListeners(). Note dashboard-kpis is still a NotImplementedException
    // stub server-side.
  }
}
