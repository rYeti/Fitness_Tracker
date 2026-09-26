import 'package:flutter/foundation.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/console_error.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/pane_reads.dart';

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
  ConsoleError? _error;
  RosterLayout _layout = RosterLayout.grid;
  final _reads = PaneReads();

  TrainerDashboardKpis? get kpis => _kpis;
  bool get isLoading => _reads.isLoading;
  ConsoleError? get error => _error;
  RosterLayout get layout => _layout;

  /// Whether the last refresh of the KPIs failed, so the figures shown are
  /// older than they could be.
  bool get refreshFailed => _reads.refreshFailed && _error == null;

  void setLayout(RosterLayout layout) {
    if (_layout == layout) return;
    _layout = layout;
    notifyListeners();
  }

  /// Loads the KPI row. [keepShown] is a refresh: no loading state, and a
  /// failure keeps the figures already shown instead of swapping them for the
  /// error strip, and sets [refreshFailed] — see
  /// [ActiveClientProvider.loadClients].
  Future<void> load({bool keepShown = false}) async {
    final read = _reads.start(keepShown: keepShown);
    if (read.isLoad) {
      _error = null;
      notifyListeners();
    }

    try {
      final kpis = await _repository.getDashboardKpis();
      if (!read.settle()) return;
      _kpis = kpis;
      _error = null;
    } catch (_) {
      if (!read.settle(failed: true)) return;
      if (read.isLoad) _error = ConsoleError.loadDashboard;
    }
    notifyListeners();
  }
}
