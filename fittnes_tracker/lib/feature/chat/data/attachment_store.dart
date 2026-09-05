import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

import 'package:ForgeForm/core/providers/enums.dart';
import 'package:ForgeForm/feature/chat/data/chat_attachment_file.dart';

/// One entry in the device media store's index.
class StoredAttachmentInfo {
  final String id;
  final String messageId;
  final String threadId;
  final MediaType kind;
  final int byteSize;
  final DateTime fetchedAt;

  const StoredAttachmentInfo({
    required this.id,
    required this.messageId,
    required this.threadId,
    required this.kind,
    required this.byteSize,
    required this.fetchedAt,
  });

  factory StoredAttachmentInfo.fromJson(Map<String, dynamic> json) {
    return StoredAttachmentInfo(
      id: json['id'] as String,
      messageId: json['messageId'] as String,
      threadId: json['threadId'] as String,
      kind: MediaType.values[json['kind'] as int],
      byteSize: json['byteSize'] as int,
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'messageId': messageId,
    'threadId': threadId,
    'kind': kind.index,
    'byteSize': byteSize,
    'fetchedAt': fetchedAt.toIso8601String(),
  };
}

/// Permanent, on-device library of decrypted attachment bytes — the WhatsApp
/// half of docs/chat-attachments.md §A.8's two-tier retention: the server
/// forgets a blob after 45 days, this remembers it forever, on whichever
/// device received it. Native platforms only — web has no permanent tier at
/// all (§C.4); every method below is a silent no-op there.
///
/// Bytes are stored decrypted, in app-private storage, never the shared
/// gallery — the OS sandbox is the boundary, the same argument
/// docs/chat-encryption.md §8 already makes for the outbox holding
/// plaintext. A small JSON index sits beside the files rather than a new
/// Drift table: build_runner cannot generate one in this sandbox (see the
/// Phase 3 commit), and unlike that phase's outbox columns, a brand-new
/// table has no existing generated code to safely pattern-match by hand
/// against. The index is small enough (one JSON object per attachment) that
/// this is a reasonable trade, revisited if/when codegen is available again.
class AttachmentStore {
  String? _basePath;
  Map<String, StoredAttachmentInfo>? _index;

  Future<String?> _base() async {
    if (kIsWeb) return null;
    final cached = _basePath;
    if (cached != null) return cached;
    final support = await getApplicationSupportDirectory();
    final path = '${support.path}/chat_media';
    _basePath = path;
    return path;
  }

  String? _indexPath(String base) => '$base/index.json';
  String _filePath(String base, String id) => '$base/$id.bin';

  Future<Map<String, StoredAttachmentInfo>> _loadIndex(String base) async {
    final cached = _index;
    if (cached != null) return cached;

    final bytes = await readAttachmentBytes(_indexPath(base)!);
    if (bytes == null) {
      _index = {};
      return _index!;
    }
    try {
      final decoded = jsonDecode(utf8.decode(bytes)) as List<dynamic>;
      _index = {
        for (final entry in decoded)
          if (entry is Map<String, dynamic>)
            StoredAttachmentInfo.fromJson(
              entry,
            ).id: StoredAttachmentInfo.fromJson(entry),
      };
    } catch (_) {
      // A corrupt index is a rebuild opportunity, not data loss — the files
      // on disk are untouched, only the index of them is gone.
      _index = {};
    }
    return _index!;
  }

  Future<void> _saveIndex(String base) async {
    final index = _index;
    if (index == null) return;
    final json = jsonEncode([for (final info in index.values) info.toJson()]);
    await writeAttachmentBytes(
      _indexPath(base)!,
      Uint8List.fromList(utf8.encode(json)),
    );
  }

  /// Decrypted bytes for [id], or null if this device has never stored it
  /// (or this is web).
  Future<Uint8List?> read(String id) async {
    final base = await _base();
    if (base == null) return null;
    final index = await _loadIndex(base);
    if (!index.containsKey(id)) return null;
    return readAttachmentBytes(_filePath(base, id));
  }

  /// Writes [bytes] permanently under [id], recording it in the index for
  /// [threadId]. A no-op on web.
  Future<void> write({
    required String id,
    required String messageId,
    required String threadId,
    required MediaType kind,
    required Uint8List bytes,
  }) async {
    final base = await _base();
    if (base == null) return;
    final index = await _loadIndex(base);
    await writeAttachmentBytes(_filePath(base, id), bytes);
    index[id] = StoredAttachmentInfo(
      id: id,
      messageId: messageId,
      threadId: threadId,
      kind: kind,
      byteSize: bytes.length,
      fetchedAt: DateTime.now().toUtc(),
    );
    await _saveIndex(base);
  }

  /// Every attachment this device holds for [threadId] — the storage
  /// management screen's per-thread breakdown (phase 4b) reads this.
  Future<List<StoredAttachmentInfo>> listForThread(String threadId) async {
    final base = await _base();
    if (base == null) return const [];
    final index = await _loadIndex(base);
    return index.values.where((i) => i.threadId == threadId).toList();
  }

  /// Every attachment this device holds, across every thread.
  Future<List<StoredAttachmentInfo>> listAll() async {
    final base = await _base();
    if (base == null) return const [];
    final index = await _loadIndex(base);
    return index.values.toList();
  }

  /// Deletes one stored attachment's bytes and index entry.
  Future<void> remove(String id) async {
    final base = await _base();
    if (base == null) return;
    final index = await _loadIndex(base);
    if (index.remove(id) == null) return;
    await deleteAttachmentFile(_filePath(base, id));
    await _saveIndex(base);
  }

  /// Wipes the whole library — sign-out, per docs/chat-attachments.md §C.4:
  /// the identity key deliberately survives sign-out, a library of somebody's
  /// progress photos must not.
  Future<void> clearAll() async {
    final base = await _base();
    if (base == null) return;
    final index = await _loadIndex(base);
    for (final id in index.keys.toList()) {
      await deleteAttachmentFile(_filePath(base, id));
    }
    _index = {};
    await deleteAttachmentFile(_indexPath(base)!);
  }
}
