import 'package:flutter/material.dart';

import 'package:ForgeForm/core/widgets/app_widgets.dart';
import 'package:ForgeForm/feature/chat/data/attachment_store.dart';
import 'package:ForgeForm/feature/chat/data/chat_api.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// One thread's worth of stored attachments, rolled up for display.
class _ThreadUsage {
  final String threadId;
  final String label;
  final int byteSize;
  final int count;
  final List<String> attachmentIds;

  const _ThreadUsage({
    required this.threadId,
    required this.label,
    required this.byteSize,
    required this.count,
    required this.attachmentIds,
  });
}

/// Settings → chat storage: how much of the device the on-device media
/// library (docs/chat-attachments.md §C.4) is using, broken down per
/// conversation, with a way to clear it.
///
/// Without a screen like this the store only ever grows — every attachment
/// a device has downloaded stays forever, by design (§A.8's WhatsApp-style
/// retention) — and the only "fix" a user could find on their own is
/// uninstalling the app.
class ChatStorageScreen extends StatefulWidget {
  /// Injection seams for tests.
  final AttachmentStore? store;
  final ChatApi? api;

  const ChatStorageScreen({super.key, this.store, this.api});

  @override
  State<ChatStorageScreen> createState() => _ChatStorageScreenState();
}

class _ChatStorageScreenState extends State<ChatStorageScreen> {
  late final AttachmentStore _store = widget.store ?? AttachmentStore();
  late final ChatApi _api = widget.api ?? ChatApi();

  bool _loading = true;
  bool _clearing = false;
  String? _error;
  List<_ThreadUsage> _threads = const [];
  int _totalBytes = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await _store.listAll();

      // Best-effort: a name for each thread reads better than a raw id, but
      // the screen's whole point is the storage data, which is already in
      // hand — a conversations fetch that fails must not block it.
      final names = <String, String>{};
      try {
        final conversations = await _api.fetchConversations();
        for (final row in conversations) {
          final id = row['otherPartyId'] as String?;
          final name = row['otherPartyName'] as String?;
          if (id != null && name != null && name.isNotEmpty) names[id] = name;
        }
      } catch (_) {
        // Falls back to id-based labels below.
      }

      final byThread = <String, List<StoredAttachmentInfo>>{};
      for (final info in all) {
        (byThread[info.threadId] ??= []).add(info);
      }

      final threads = [
        for (final entry in byThread.entries)
          _ThreadUsage(
            threadId: entry.key,
            label:
                names[entry.key] ??
                (entry.key.length > 8 ? entry.key.substring(0, 8) : entry.key),
            byteSize: entry.value.fold(0, (sum, i) => sum + i.byteSize),
            count: entry.value.length,
            attachmentIds: [for (final i in entry.value) i.id],
          ),
      ]..sort((a, b) => b.byteSize.compareTo(a.byteSize));

      if (!mounted) return;
      setState(() {
        _threads = threads;
        _totalBytes = all.fold(0, (sum, i) => sum + i.byteSize);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'error';
        _loading = false;
      });
    }
  }

  Future<void> _confirmClear({
    required String title,
    required String message,
    required Future<void> Function() onConfirm,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.chatDismiss),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.chatStorageClear),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    setState(() => _clearing = true);
    try {
      await onConfirm();
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
    await _load();
  }

  Future<void> _clearThread(_ThreadUsage thread) => _confirmClear(
    title: AppLocalizations.of(context)!.chatStorageClearThreadTitle,
    message: AppLocalizations.of(
      context,
    )!.chatStorageClearThreadBody(thread.label),
    onConfirm: () async {
      for (final id in thread.attachmentIds) {
        await _store.remove(id);
      }
    },
  );

  Future<void> _clearAll() => _confirmClear(
    title: AppLocalizations.of(context)!.chatStorageClearAllTitle,
    message: AppLocalizations.of(context)!.chatStorageClearAllBody,
    onConfirm: _store.clearAll,
  );

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.chatStorageTitle)),
      body: SafeArea(
        child:
            _loading
                ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: LoadingSkeleton(
                    rows: 5,
                    rowHeight: 56,
                    semanticsLabel: l10n.chatStorageLoading,
                  ),
                )
                : _error != null
                ? ErrorStateView(
                  message: l10n.chatStorageLoadError,
                  onRetry: _load,
                )
                : _threads.isEmpty
                ? EmptyStateView(
                  icon: Icons.storage_outlined,
                  title: l10n.chatStorageEmpty,
                  message: l10n.chatStorageEmptyBody,
                )
                : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: colors.outlineVariant),
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.storage_outlined,
                          color: colors.primary,
                        ),
                        title: Text(l10n.chatStorageTotalUsed),
                        subtitle: Text(_formatBytes(_totalBytes)),
                        trailing: TextButton(
                          onPressed: _clearing ? null : _clearAll,
                          child: Text(l10n.chatStorageClearAll),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.chatStorageByThread,
                      style: TextStyle(
                        fontFamily: 'Exo 2',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final thread in _threads)
                      Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: colors.outlineVariant),
                        ),
                        child: ListTile(
                          title: Text(thread.label),
                          subtitle: Text(
                            '${_formatBytes(thread.byteSize)} · ${thread.count}',
                          ),
                          trailing: IconButton(
                            tooltip: l10n.chatStorageClearThreadTitle,
                            icon: const Icon(Icons.delete_outline),
                            onPressed:
                                _clearing ? null : () => _clearThread(thread),
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
      ),
    );
  }
}
