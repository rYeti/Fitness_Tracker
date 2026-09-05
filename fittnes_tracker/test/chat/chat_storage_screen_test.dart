import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/providers/enums.dart';
import 'package:ForgeForm/feature/chat/data/attachment_store.dart';
import 'package:ForgeForm/feature/chat/data/chat_api.dart';
import 'package:ForgeForm/feature/chat/presentation/view/chat_storage_screen.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// An in-memory [AttachmentStore] — the real one goes through path_provider's
/// platform channel, which plain `flutter_test` has no mock for. Overriding
/// every method keeps this screen's tests about the screen's own logic
/// (summing, grouping, the confirm-before-wipe flow), not about disk I/O
/// already covered elsewhere.
class _FakeAttachmentStore implements AttachmentStore {
  final Map<String, StoredAttachmentInfo> _entries = {};

  @override
  Future<void> write({
    required String id,
    required String messageId,
    required String threadId,
    required MediaType kind,
    required Uint8List bytes,
  }) async {
    _entries[id] = StoredAttachmentInfo(
      id: id,
      messageId: messageId,
      threadId: threadId,
      kind: kind,
      byteSize: bytes.length,
      fetchedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<Uint8List?> read(String id) async => null;

  @override
  Future<List<StoredAttachmentInfo>> listAll() async =>
      _entries.values.toList();

  @override
  Future<List<StoredAttachmentInfo>> listForThread(String threadId) async =>
      _entries.values.where((i) => i.threadId == threadId).toList();

  @override
  Future<void> remove(String id) async => _entries.remove(id);

  @override
  Future<void> clearAll() async => _entries.clear();
}

/// The name lookup is best-effort — this fails instantly rather than
/// against a real, slow socket, so the screen's own logic (not network
/// timing) is what these tests exercise.
class _FailingChatApi implements ChatApi {
  @override
  Future<List<Map<String, dynamic>>> fetchConversations() async {
    throw StateError('no network in tests');
  }

  @override
  Future<List<Map<String, dynamic>>> fetchHistory(
    String otherPartyId, {
    int range = 50,
  }) async => throw UnimplementedError();

  @override
  Future<void> markRead(String otherPartyId) async =>
      throw UnimplementedError();
}

void main() {
  Future<void> pump(WidgetTester tester, {AttachmentStore? store}) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChatStorageScreen(
          store: store ?? _FakeAttachmentStore(),
          api: _FailingChatApi(),
        ),
      ),
    );
  }

  testWidgets('an empty store shows the empty state', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('No chat media stored'), findsOneWidget);
  });

  testWidgets('usage is summed and broken down by thread', (tester) async {
    final store = _FakeAttachmentStore();
    await store.write(
      id: 'a1',
      messageId: 'm1',
      threadId: 'thread-a',
      kind: MediaType.picture,
      bytes: Uint8List.fromList(List.filled(2048, 1)),
    );
    await store.write(
      id: 'a2',
      messageId: 'm2',
      threadId: 'thread-a',
      kind: MediaType.document,
      bytes: Uint8List.fromList(List.filled(1024, 1)),
    );

    await pump(tester, store: store);
    await tester.pumpAndSettle();

    expect(find.text('3 KB'), findsWidgets); // total, and the one thread
  });

  testWidgets('clearing all asks for confirmation before wiping', (
    tester,
  ) async {
    final store = _FakeAttachmentStore();
    await store.write(
      id: 'a1',
      messageId: 'm1',
      threadId: 'thread-a',
      kind: MediaType.picture,
      bytes: Uint8List.fromList(List.filled(2048, 1)),
    );

    await pump(tester, store: store);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();

    // A destructive action must not fire on a single tap with no undo path.
    expect(find.text('Clear all chat media?'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('No chat media stored'), findsOneWidget);
    expect(await store.listAll(), isEmpty);
  });
}
