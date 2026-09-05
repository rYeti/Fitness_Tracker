import 'dart:typed_data';

/// Ephemeral, in-memory decoded-bytes cache in front of [AttachmentStore] —
/// every platform, including web, where there is no permanent tier at all.
/// See docs/chat-attachments.md §C.4.
///
/// Capped by total bytes rather than entry count: a voice note and a
/// full-size photo differ by two orders of magnitude, so counting entries
/// would let a handful of large images blow the budget.
class AttachmentCache {
  static const _budgetBytes = 40 * 1024 * 1024;

  final _entries = <String, Uint8List>{};
  int _totalBytes = 0;

  /// Fetches in flight, keyed by attachment id — deduplicates two bubbles
  /// referencing the same attachment so neither mints two download URLs nor
  /// decrypts twice.
  final Map<String, Future<Uint8List?>> inFlight = {};

  Uint8List? get(String id) {
    final bytes = _entries.remove(id);
    if (bytes == null) return null;
    // Re-inserting moves it to the end — LinkedHashMap's iteration order is
    // insertion order, so this is what makes eviction below actually be LRU.
    _entries[id] = bytes;
    return bytes;
  }

  void put(String id, Uint8List bytes) {
    _entries.remove(id);
    _entries[id] = bytes;
    _totalBytes += bytes.length;
    while (_totalBytes > _budgetBytes && _entries.isNotEmpty) {
      final oldestKey = _entries.keys.first;
      final removed = _entries.remove(oldestKey);
      if (removed != null) _totalBytes -= removed.length;
    }
  }
}
