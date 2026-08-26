/// Everything chat does with an instant, in one place.
///
/// Three separate surfaces render a message time — the day divider in a thread,
/// the time under a bubble, and the right-hand column of a conversation row —
/// and each used to do its own parsing and its own formatting. That is how the
/// two bugs this file exists to close got in: a timestamp that is a *UTC
/// instant* was being read as a local wall-clock time, and a timestamp the
/// server could not supply was being rendered as the year 1 rather than as
/// nothing.
///
/// Nothing here is localised, which matches the rest of the chat widgets. When
/// chat is localised, this is the one file that has to change.
class ChatTimestamps {
  const ChatTimestamps._();

  /// Below this, a value is a sentinel rather than a message time.
  ///
  /// `DateTime(1)` on this side and `default(DateTime)` on the server's both
  /// land on 0001-01-01, and both reach the UI as "01/01/0001" — a date no
  /// message has ever had. Anything before the Unix epoch is treated the same
  /// way: chat did not exist, so the value is missing data wearing a date.
  static final DateTime _sentinelCeiling = DateTime.utc(1970);

  /// Reads an instant the API sent us, or null if it did not really send one.
  ///
  /// Two things are handled that `DateTime.parse` alone gets wrong:
  ///
  /// * **A string with no zone designator is UTC, not local.** The API stamps
  ///   `SentAt` with `DateTime.UtcNow`, but whether that reaches JSON with a
  ///   trailing `Z` depends on the DateTime's `Kind` surviving the round trip
  ///   through the database provider. Without the `Z`, `DateTime.parse` returns
  ///   a *local* DateTime holding UTC digits, and every message is then shown
  ///   offset by the reader's timezone — an hour or two out, which is just
  ///   plausible enough that nobody files it as a bug.
  /// * **A sentinel is not a date.** See [_sentinelCeiling].
  static DateTime? parseInstant(Object? raw) {
    if (raw is DateTime) return _rejectSentinel(raw.toUtc());
    if (raw is! String || raw.isEmpty) return null;

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;

    // `tryParse` marks a string carrying `Z` or an explicit offset as UTC. One
    // with neither comes back local, and that is exactly the case that has to be
    // reinterpreted rather than converted.
    final utc = parsed.isUtc
        ? parsed
        : DateTime.utc(
            parsed.year,
            parsed.month,
            parsed.day,
            parsed.hour,
            parsed.minute,
            parsed.second,
            parsed.millisecond,
            parsed.microsecond,
          );

    return _rejectSentinel(utc);
  }

  /// A stored instant, or now if what was stored is a sentinel.
  ///
  /// The outbox is written by this app and should never hold one — but the
  /// thread's day dividers are cut from these values just as they are from the
  /// server's, so a single bad row would put "01/01/0001" back on screen. One
  /// guard on the way in is cheaper than trusting two sources instead of one.
  static DateTime sanitize(DateTime at) =>
      _rejectSentinel(at.toUtc()) ?? DateTime.now().toUtc();

  static DateTime? _rejectSentinel(DateTime utc) =>
      utc.isBefore(_sentinelCeiling) ? null : utc;

  /// `14:07`, in the reader's timezone. The resolution a chat message needs.
  static String timeOfDay(DateTime at) {
    final local = at.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  /// `Today` / `Yesterday` / `04/08/2026`, in the reader's timezone.
  ///
  /// [now] is injectable so the relative branches are testable without waiting
  /// for midnight.
  static String dayLabel(DateTime at, {DateTime? now}) {
    final local = at.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final today = _startOfDay(now ?? DateTime.now());
    final difference = today.difference(day).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    return '${_two(day.day)}/${_two(day.month)}/${day.year}';
  }

  /// The conversation-list column: time today, weekday inside the last week, a
  /// date beyond that — the resolution a reader actually needs at each distance.
  static String listLabel(DateTime at, {DateTime? now}) {
    final local = at.toLocal();
    final reference = now ?? DateTime.now();
    final day = DateTime(local.year, local.month, local.day);
    final today = _startOfDay(reference);
    final difference = today.difference(day).inDays;

    if (difference == 0) return timeOfDay(local);
    if (difference > 0 && difference < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[local.weekday - 1];
    }
    // The year is carried outside the current one. Without it a message from
    // last August and one from this August are the same two digits, and the
    // conversation list is sorted by exactly that value.
    return day.year == today.year
        ? '${_two(day.day)}/${_two(day.month)}'
        : '${_two(day.day)}/${_two(day.month)}/${day.year}';
  }

  /// The full stamp, for a screen reader and for the bubble's tooltip: the time
  /// alone is ambiguous the moment a thread spans more than one day.
  static String accessibleLabel(DateTime at, {DateTime? now}) =>
      '${dayLabel(at, now: now)} at ${timeOfDay(at)}';

  /// Whether a day divider belongs between [previous] and [next].
  static bool crossesDay(DateTime? previous, DateTime next) {
    if (previous == null) return true;
    final a = previous.toLocal();
    final b = next.toLocal();
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }

  static DateTime _startOfDay(DateTime at) {
    final local = at.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
