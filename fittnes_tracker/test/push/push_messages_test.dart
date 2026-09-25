import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/network/api_client.dart';
import 'package:ForgeForm/core/services/push_messages.dart';
import 'package:ForgeForm/core/services/push_service.dart';

/// What each data-only push does, in the foreground and in the background.
/// `sync_requested` is new with part four of the sync rework
/// (`docs/sync-architecture.md`); chat must behave exactly as it did.
///
/// Each test was run with the one rule it pins taken out, and failed there.
void main() {
  late List<Map<String, dynamic>> shownChats;
  late int syncRequests;

  Future<void> showChat(Map<String, dynamic> data) async => shownChats.add(data);
  void requestSync() => syncRequests++;

  setUp(() {
    shownChats = [];
    syncRequests = 0;
  });

  const syncRequested = {'type': 'sync_requested'};
  const chatMessage = {
    'type': 'chat_message',
    'threadId': 'trainer-1',
    'senderName': 'Robert Meyer',
    'ciphertext': 'b64',
    'iv': 'iv',
    'encryptionVersion': '2',
  };

  group('a sync_requested', () {
    test('in the foreground asks for a pull and shows nothing', () async {
      await handleForegroundPush(
        syncRequested,
        showChat: showChat,
        requestSync: requestSync,
      );

      expect(syncRequests, 1);
      expect(shownChats, isEmpty);
    });

    test('in the background shows nothing', () async {
      await handleBackgroundPush(syncRequested, showChat: showChat);

      expect(shownChats, isEmpty);
    });
  });

  group('a chat message, as before', () {
    test('in the foreground is shown, and asks for no pull', () async {
      await handleForegroundPush(
        chatMessage,
        showChat: showChat,
        requestSync: requestSync,
      );

      expect(shownChats, [chatMessage]);
      expect(syncRequests, 0);
    });

    test('in the background is shown', () async {
      await handleBackgroundPush(chatMessage, showChat: showChat);

      expect(shownChats, [chatMessage]);
    });
  });

  test('a type this build does not know does nothing anywhere', () async {
    const unknown = {'type': 'licence_changed'};

    await handleForegroundPush(
      unknown,
      showChat: showChat,
      requestSync: requestSync,
    );
    await handleBackgroundPush(unknown, showChat: showChat);

    expect(shownChats, isEmpty);
    expect(syncRequests, 0);
  });

  test('PushService hands a requested pull to whoever is listening', () async {
    final push = PushService(client: ApiClient(baseUrl: 'https://example.invalid/'));
    final heard = <void>[];
    final subscription = push.onSyncRequested.listen(heard.add);

    push.requestSync();
    await Future<void>.delayed(Duration.zero);

    expect(heard, hasLength(1));
    await subscription.cancel();
    await push.dispose();
  });
}
