import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:ForgeForm/feature/chat/data/chat_signalr_client.dart'
    show ChatConnectionStatus;
import 'package:ForgeForm/feature/trainer_console/domain/models/client_data_change.dart';

/// Something the console should read again.
sealed class ConsoleRefresh {
  const ConsoleRefresh();
}

/// The roster and the Dashboard's figures, which summarise every client — so
/// any client's change can move them.
class RosterRefresh extends ConsoleRefresh {
  const RosterRefresh();
}

/// The panes showing [clientId]'s [areas].
class ClientRefresh extends ConsoleRefresh {
  const ClientRefresh(this.clientId, this.areas);

  /// Every pane, whatever client it shows: the tab came back into focus, or
  /// the socket came back, and either may have missed an event.
  ClientRefresh.everything() : this(null, ClientDataArea.values.toSet());

  /// Null for every client.
  final String? clientId;
  final Set<ClientDataArea> areas;

  /// Whether a pane showing [shownClientId]'s [paneAreas] has to read again.
  ///
  /// Ids are compared without case. Both sides are the server's GUIDs, which
  /// it writes in lower case today, but a pane that silently stops refreshing
  /// because one serializer changed its mind is not worth the saved call.
  bool concerns(String? shownClientId, Set<ClientDataArea> paneAreas) {
    if (shownClientId == null) return false;
    final id = clientId;
    if (id != null && id.toLowerCase() != shownClientId.toLowerCase()) {
      return false;
    }
    return areas.any(paneAreas.contains);
  }
}

/// Turns "a client's data changed" into refetches, at a rate the API can take.
///
/// The server sends `ClientDataChanged {clientId, areas}` on the console's
/// existing `ChatHub` connection after it commits a change to a client's data.
/// It carries no data; this decides when each pane reads again through its own
/// endpoint (`docs/sync-architecture.md`, part four):
///
/// - a pane showing that client reads again [paneDelay] after the last event
///   of a burst — one push from a phone is several requests, each its own
///   event, and they should cost one refetch, not one each — but never more
///   than [paneMaxWait] after the first event it hasn't read for yet;
/// - the roster and the Dashboard's figures read again [rosterDelay] after the
///   last event for *any* client, and at most [rosterMaxWait] after the first;
/// - when the tab or window comes back into focus ([focusRegained]) or the
///   socket comes back after a drop, everything shown reads again. Events are
///   sent only to connections on the instance that made the change, so one can
///   be missed; this is what makes a missed one cost freshness and not
///   correctness. Either refetches at most once per [fallbackCooldown], and
///   once more when it ends if either was asked for meanwhile.
///
/// It only says *when*. What a refetch keeps on screen meanwhile is each
/// provider's business, and a pane nobody can see waits until it is shown
/// ([LiveRefreshPane]).
class ConsoleLiveUpdates {
  ConsoleLiveUpdates({
    Stream<ClientDataChange> changes = const Stream.empty(),
    Stream<void> reconnected = const Stream.empty(),
    this.paneDelay = const Duration(seconds: 1),
    this.paneMaxWait = const Duration(seconds: 5),
    this.rosterDelay = const Duration(seconds: 3),
    this.rosterMaxWait = const Duration(seconds: 15),
    this.fallbackCooldown = const Duration(seconds: 30),
  }) {
    _panes = _Debounce(paneDelay, paneMaxWait, _flushPanes);
    _roster = _Debounce(
      rosterDelay,
      rosterMaxWait,
      () => _emit(const RosterRefresh()),
    );
    _subscriptions = [
      changes.listen(_onChange),
      reconnected.listen((_) => _refetchEverything()),
    ];
  }

  final Duration paneDelay;
  final Duration paneMaxWait;
  final Duration rosterDelay;
  final Duration rosterMaxWait;
  final Duration fallbackCooldown;

  final _refreshes = StreamController<ConsoleRefresh>.broadcast();
  late final List<StreamSubscription<Object?>> _subscriptions;

  /// What to read again, as it falls due.
  Stream<ConsoleRefresh> get refreshes => _refreshes.stream;

  /// Areas changed per client since the last pane refetch.
  final Map<String, Set<ClientDataArea>> _pendingClients = {};
  bool _everythingPending = false;
  late final _Debounce _panes;
  late final _Debounce _roster;
  Timer? _cooldown;
  bool _askedInCooldown = false;

  /// Turns a connection's status into the moments it came back.
  ///
  /// Counts a fresh start after a close as well as SignalR's own automatic
  /// reconnect — both follow a gap in which events were sent to nobody — but
  /// not the first connect, which lands while the panes are making their first
  /// reads anyway.
  static Stream<void> reconnectsOf(Stream<ChatConnectionStatus> status) {
    ChatConnectionStatus? last;
    return status
        .where((s) {
          final cameBack = s == ChatConnectionStatus.connected &&
              last != null &&
              last != ChatConnectionStatus.connected;
          last = s;
          return cameBack;
        })
        .map((_) {});
  }

  /// The tab or window came back into focus.
  ///
  /// On web and desktop that is every alt-tab and every click back into the
  /// window, so it shares the reconnect path's cooldown: a trainer switching
  /// apps many times an hour would otherwise pay for the roster and KPI
  /// aggregates every time.
  void focusRegained() => _refetchEverything();

  void _onChange(ClientDataChange change) {
    // An event with no area this build knows still moves the roster.
    if (change.areas.isNotEmpty) {
      (_pendingClients[change.clientId] ??= {}).addAll(change.areas);
      _panes.poke();
    }
    _roster.poke();
  }

  /// Everything shown reads again, at most once per [fallbackCooldown] —
  /// and once more when the cooldown ends if it was asked for meanwhile,
  /// since the last focus or drop inside the cooldown is exactly the one no
  /// refetch has covered yet.
  void _refetchEverything() {
    if (_cooldown != null) {
      _askedInCooldown = true;
      return;
    }
    _everythingPending = true;
    _panes.poke();
    _roster.poke();
    _cooldown = Timer(fallbackCooldown, () {
      _cooldown = null;
      if (!_askedInCooldown) return;
      _askedInCooldown = false;
      _refetchEverything();
    });
  }

  void _flushPanes() {
    if (_everythingPending) {
      _emit(ClientRefresh.everything());
    } else {
      for (final MapEntry(key: clientId, value: areas)
          in _pendingClients.entries) {
        _emit(ClientRefresh(clientId, areas));
      }
    }
    _everythingPending = false;
    _pendingClients.clear();
  }

  void _emit(ConsoleRefresh refresh) {
    if (!_refreshes.isClosed) _refreshes.add(refresh);
  }

  /// Stops every timer and closes [refreshes]. Nothing to wait for: the
  /// console has stopped listening by the time it calls this.
  void dispose() {
    _panes.cancel();
    _roster.cancel();
    _cooldown?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_refreshes.close());
  }
}

/// A trailing debounce with a ceiling: [fire] runs [delay] after the last
/// [poke], but never later than [maxWait] after the first poke it hasn't run
/// for yet.
///
/// The ceiling is what a plain trailing debounce lacks. Events for every
/// client share one timer, and a trainer with a dozen clients mid-session
/// sees them less than a second apart all afternoon; a timer every event
/// restarts would never run at all while that lasted. A steady stream now
/// costs freshness up to [maxWait], and a burst still costs one refetch.
class _Debounce {
  _Debounce(this.delay, this.maxWait, this.fire);

  final Duration delay;
  final Duration maxWait;
  final void Function() fire;

  Timer? _quiet;
  Timer? _ceiling;

  void poke() {
    _quiet?.cancel();
    _quiet = Timer(delay, _run);
    _ceiling ??= Timer(maxWait, _run);
  }

  void _run() {
    cancel();
    fire();
  }

  void cancel() {
    _quiet?.cancel();
    _ceiling?.cancel();
    _quiet = null;
    _ceiling = null;
  }
}

/// A console pane that keeps what it shows current while the console is open.
///
/// Mixed into the pane's [State]; the pane says whose data it shows
/// ([liveClientId]), which refreshes concern it ([concernsLive]), and how to
/// read again without taking what it shows off screen ([refreshLive]). The
/// [ConsoleLiveUpdates] comes from an ancestor provider; a pane mounted without
/// one — alone, in a test — simply never refreshes.
///
/// A pane that is kept alive but not shown — the console keeps every visited
/// section mounted — does not fetch for a refresh. It remembers it, and reads
/// again when it is next shown. A screen nobody can see should not be fetching
/// (`docs/trainer-console-loading.md`), and an event for a client the trainer
/// is looking at would otherwise refetch every section they had ever opened.
mixin LiveRefreshPane<W extends StatefulWidget> on State<W> {
  StreamSubscription<ConsoleRefresh>? _liveSubscription;
  bool _liveShown = true;
  bool _liveStale = false;
  String? _liveStaleClientId;

  /// The client this pane shows, or null when it shows none yet.
  String? get liveClientId;

  /// Whether [refresh] concerns what this pane shows.
  bool concernsLive(ConsoleRefresh refresh);

  /// Reads what this pane shows again, keeping it on screen meanwhile.
  void refreshLive();

  @override
  void initState() {
    super.initState();
    _liveSubscription = context
        .read<ConsoleLiveUpdates?>()
        ?.refreshes
        .listen(_onLiveRefresh);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Registers a dependency, so switching sections calls this again.
    final shown = Visibility.of(context);
    final cameIntoView = shown && !_liveShown;
    _liveShown = shown;
    // After the frame: the pane's own didChangeDependencies runs after this
    // one and may switch it to another client first, which makes the missed
    // refresh moot.
    if (cameIntoView && _liveStale) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _catchUp());
    }
  }

  void _onLiveRefresh(ConsoleRefresh refresh) {
    if (!mounted || !concernsLive(refresh)) return;
    if (_liveShown) {
      refreshLive();
      return;
    }
    _liveStale = true;
    _liveStaleClientId = liveClientId;
  }

  void _catchUp() {
    if (!mounted || !_liveStale || !_liveShown) return;
    _liveStale = false;
    // A pane switched to another client while hidden has read that client
    // since; the refresh it missed was for the one it no longer shows.
    if (_liveStaleClientId == liveClientId) refreshLive();
  }

  @override
  void dispose() {
    _liveSubscription?.cancel();
    super.dispose();
  }
}
