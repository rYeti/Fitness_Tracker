import 'package:flutter/foundation.dart';

/// The reads behind what one console pane shows: numbered, so that only the
/// latest one asked for is applied, and each either a load or a refresh.
///
/// A **load** takes what is shown off screen — another client, a first visit,
/// a retry after an error. It raises [isLoading], and a failure is the pane's
/// error to show. A **refresh** reads again what is already shown, because
/// the console heard it changed, and keeps it on screen while it does: no
/// loading state, and a failure leaves the data up and sets [refreshFailed]
/// rather than an error.
///
/// Every console provider used to spell this out for itself. Five carried
/// the same request counter, the same `keepShown && !_isLoading` and the same
/// "swallow the failure on a refresh" block; the Workout Builder carried a
/// different scheme again — an epoch its seven write methods bumped by hand,
/// which its own refresh never bumped, so two refreshes weren't ordered, and
/// which any new write could forget with nothing failing. The rules live here
/// once now (`docs/sync-architecture.md` §52).
///
/// The shape of a provider's read:
///
/// ```dart
/// final read = _reads.start(keepShown: keepShown, shown: sameClient);
/// if (read.isLoad) { /* clear what's shown */ notifyListeners(); }
/// try {
///   final value = await fetch();
///   if (!read.settle()) return;          // overtaken: drop it
///   /* apply value, clear the error */
/// } catch (_) {
///   if (!read.settle(failed: true)) return;
///   if (read.isLoad) /* set the error */;
/// }
/// notifyListeners();
/// ```
class PaneReads {
  PaneReads({this.onRefreshOwed});

  /// Runs a refresh again, for a pane that writes: one a [write] overlapped
  /// is dropped, and owed once no write is in flight.
  final VoidCallback? onRefreshOwed;

  int _latest = 0;
  int _writeEpoch = 0;
  int _writes = 0;
  bool _loading = false;
  bool _refreshFailed = false;
  bool _refreshOwed = false;

  /// Whether a load — a read that took what was shown off screen — is the
  /// latest read, and in flight.
  bool get isLoading => _loading;

  /// Whether the latest read was a refresh that failed: what is shown is
  /// still up, and older than it could be. Cleared by the next read that
  /// succeeds, and by any load.
  bool get refreshFailed => _refreshFailed;

  /// Whether a [write] is in flight. Read after a write's own `await`, it
  /// says whether that was the last one: with several in flight, the one
  /// that settles last is the one left to decide what the pane shows.
  bool get isWriting => _writes > 0;

  /// Starts a read, and makes every read started before it out of date.
  ///
  /// It is a refresh only when [keepShown] asks for one, [shown] says what
  /// is on screen is what this read reads — the same client — and no load
  /// is in flight. A load in flight has nothing on screen to keep, and may
  /// have been answered from before the change the refresh was asked for;
  /// so the refresh becomes a load itself and supersedes it, rather than
  /// being dropped and leaving that change unread.
  PaneRead start({bool keepShown = false, bool shown = true}) {
    final keep = keepShown && shown && !_loading;
    if (!keep) {
      _loading = true;
      _refreshFailed = false;
    }
    return PaneRead._(this, ++_latest, keep, _writeEpoch, _writes > 0);
  }

  /// Runs [body], a write of something the pane shows.
  ///
  /// A refresh that overlapped it in any way — started before it and answered
  /// after, or started while it was in flight — can't tell whether its answer
  /// is from before the write or after, and applying one from before would
  /// put back what the write replaced. So it is dropped, and read again
  /// ([onRefreshOwed]) once no write is in flight: dropping it outright would
  /// lose the change it was asked for whenever the write failed, since only a
  /// write that succeeds brings an event of its own.
  ///
  /// Loads are not overtaken by a write: they are the trainer's own
  /// navigation, and the pane shows a skeleton, not a form, while one runs.
  Future<T> write<T>(Future<T> Function() body) async {
    _writes++;
    _writeEpoch++;
    try {
      return await body();
    } finally {
      _writes--;
      if (_writes == 0 && _refreshOwed) {
        _refreshOwed = false;
        onRefreshOwed?.call();
      }
    }
  }

  void _owe() {
    if (_writes > 0) {
      _refreshOwed = true;
    } else {
      onRefreshOwed?.call();
    }
  }
}

/// One read started by [PaneReads.start].
class PaneRead {
  PaneRead._(
    this._reads,
    this._number,
    this.keep,
    this._writeEpoch,
    this._startedDuringWrite,
  );

  final PaneReads _reads;
  final int _number;
  final int _writeEpoch;
  final bool _startedDuringWrite;

  /// Whether this is a refresh, which keeps what is shown.
  final bool keep;

  /// Whether this is a load, which took what was shown off screen.
  bool get isLoad => !keep;

  /// Whether a [PaneReads.write] overlapped this read: it started while one
  /// was in flight, or one started before its answer arrived. Its answer may
  /// then be from before that write or after it.
  ///
  /// A refresh that overlapped a write is dropped and read again by
  /// [settle]. A load is applied — it is the trainer's own navigation — so a
  /// pane whose load reads what its writes change asks this, and keeps what
  /// the writes set in place of that part of the answer.
  bool get overlappedWrite =>
      _startedDuringWrite || _writeEpoch != _reads._writeEpoch;

  bool get _overlappedWrite => keep && overlappedWrite;

  /// Whether this read's answer is still the one to show: no read has been
  /// started since, and — for a refresh — no write overlapped it. For a
  /// provider that applies parts of an answer as they arrive.
  bool get isCurrent => _number == _reads._latest && !_overlappedWrite;

  /// Settles this read, once its answer or its failure is in. Call it once.
  ///
  /// Returns whether the answer is to be applied. When it is, [PaneReads]
  /// now describes this read: no longer loading, and a failed refresh marked
  /// as one. When it isn't, a later read owns the pane's state, or a write
  /// overlapped this refresh and it is owed again.
  bool settle({bool failed = false}) {
    if (_number != _reads._latest) return false;
    if (_overlappedWrite) {
      _reads._owe();
      return false;
    }
    _reads._loading = false;
    _reads._refreshFailed = keep && failed;
    return true;
  }
}
