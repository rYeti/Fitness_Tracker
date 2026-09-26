import 'package:shared_preferences/shared_preferences.dart';

import 'package:ForgeForm/core/sync/sync_service.dart';
import 'package:ForgeForm/feature/auth/presentation/providers/auth_provider.dart'
    show lastPullPrefsKey;

/// The pull the app runs while someone is looking at it: on launch, on
/// resume, and when the server asks for one.
///
/// The pull asks the server only for what changed since the last one
/// (`docs/sync-architecture.md`, part three), so it no longer needs the
/// six-hour throttle it had while it downloaded the whole account every time:
/// that throttle is why a trainer's edit could take hours to reach the phone.
/// [interval] only keeps a burst of resumes — a permission dialog, a glance at
/// the notification shade — from pulling once each.
class ForegroundPull {
  ForegroundPull({
    required Future<SyncService?> Function() service,
    this.interval = const Duration(minutes: 2),
  }) : _service = service;

  /// A service to pull with, or null when nobody is signed in.
  final Future<SyncService?> Function() _service;

  final Duration interval;

  /// Pulls what changed elsewhere, and says whether a pull ran whole.
  ///
  /// A launch or resume pulls at most once per [interval]. A [requested] pull
  /// — a `sync_requested` push, received in the foreground — does not wait for
  /// it: the server has just said there is something to fetch, and the
  /// interval exists to stop pulls nobody asked for.
  ///
  /// It skips nothing else. It goes through [SyncService.pullAll], so it takes
  /// the lease and joins a pull already running here rather than starting a
  /// second alongside it. But it first waits for this isolate to be idle, and
  /// only then pulls: a pull already running may have asked the server before
  /// the change being announced was committed, and joining it would answer
  /// the request with that older answer. Waiting costs at most the rest of
  /// that run; joining it could cost the change until the next resume.
  Future<bool> run({bool requested = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!requested) {
      final lastPullMs = prefs.getInt(lastPullPrefsKey);
      if (lastPullMs != null) {
        final lastPull = DateTime.fromMillisecondsSinceEpoch(lastPullMs);
        if (DateTime.now().difference(lastPull) < interval) return false;
      }
    }

    final service = await _service();
    if (service == null) return false; // not signed in

    try {
      if (requested) await SyncService.whenIdle();
      await service.pullAll();
      // Only a pull that finished every step counts: pullAll throws
      // SyncIncompleteException otherwise, and is tried again on the next
      // launch or resume.
      await prefs.setInt(
        lastPullPrefsKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      return true;
    } catch (_) {
      // Silent — no network, the server is down, or another run held the
      // lease (SyncBusyException). Tried again on the next trigger.
      return false;
    }
  }
}
