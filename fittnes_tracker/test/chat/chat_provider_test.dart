import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/feature/chat/data/chat_repository.dart';
import 'package:ForgeForm/feature/chat/data/chat_signalr_client.dart';
import 'package:ForgeForm/feature/chat/presentation/providers/chat_provider.dart';

import 'fakes.dart';

const otherParty = '22222222-2222-2222-2222-222222222222';

void main() {
  late AppDatabase db;
  late FakeChatSignalRClient signalR;

  setUp(() {
    db = newTestDatabase();
    signalR = FakeChatSignalRClient();
  });

  tearDown(() async {
    await signalR.dispose();
    await db.close();
  });

  ChatProvider build({FakeChatApi? api}) {
    return ChatProvider(
      repository: ChatRepository(
        db: db,
        api: api ?? FakeChatApi(),
        signalR: signalR,
      ),
    );
  }

  Map<String, dynamic> conversationJson(String id, String name) => {
        'otherPartyId': id,
        'otherPartyName': name,
        'lastMessagePreview': 'see you thursday',
        'lastMessageAt': DateTime.utc(2026, 8, 1, 9).toIso8601String(),
        'unreadCount': 0,
      };

  group('conversations', () {
    test('reports loading while the list is in flight, then populates', () async {
      final gate = Completer<void>();
      final provider = build(
        api: FakeChatApi(conversations: [conversationJson(otherParty, 'Robert Meyer')], gate: gate),
      );

      final loading = provider.loadConversations();
      expect(provider.isLoading, isTrue);

      gate.complete();
      await loading;

      expect(provider.isLoading, isFalse);
      expect(provider.conversations.single.clientName, 'Robert Meyer');
      expect(provider.error, isNull);
    });

    test('surfaces a recoverable error rather than an empty list', () async {
      final provider = build(api: FakeChatApi(throwOnConversations: true));

      await provider.loadConversations();

      // An empty list and a failed request look identical on screen otherwise,
      // and one of them has a retry that works.
      expect(provider.error, isNotNull);
      expect(provider.conversations, isEmpty);
      expect(provider.isLoading, isFalse);
    });

    test('clears a previous error on a successful retry', () async {
      final api = FakeChatApi(conversations: [conversationJson(otherParty, 'Robert Meyer')])
        ..failConversationsTimes = 1;
      final provider = build(api: api);

      await provider.loadConversations();
      expect(provider.error, isNotNull);

      await provider.loadConversations();

      // A retry that leaves the old error on screen is indistinguishable from
      // one that never ran.
      expect(provider.error, isNull);
      expect(provider.conversations, hasLength(1));
    });
  });

  group('threads', () {
    test('opening a thread loads its messages', () async {
      final provider = build(
        api: FakeChatApi(history: {
          otherParty: [
            messageJson(
              id: 'server-1',
              body: 'how did it go?',
              senderId: otherParty,
              clientId: otherParty,
              sentAt: DateTime.utc(2026, 8, 1, 9),
            ),
          ],
        }),
      );

      await provider.openThread(otherParty);

      expect(provider.thread.single.messageId, 'server-1');
      expect(provider.activeThreadId, otherParty);
    });

    test('switching client leaves the old group and joins the new one', () async {
      final provider = build();

      await provider.openThread(otherParty);
      await provider.openThread('another-client');

      expect(signalR.left, [otherParty]);
      expect(signalR.joined, [otherParty, 'another-client']);
      expect(provider.activeThreadId, 'another-client');
    });

    test('a live message from the other party appends to the open thread', () async {
      final provider = build();
      await provider.openThread(otherParty);

      signalR.emitIncoming(signalR.ack(
        messageId: 'theirs',
        otherPartyId: otherParty,
        body: 'thanks!',
        senderId: otherParty,
      ));
      await pumpEventQueue();

      expect(provider.thread.single.messageId, 'theirs');
    });

    test('closing a thread leaves the group and clears the messages', () async {
      final provider = build();
      await provider.openThread(otherParty);

      await provider.closeThread();

      expect(signalR.left, [otherParty]);
      expect(provider.thread, isEmpty);
      expect(provider.activeThreadId, isNull);
    });

    test('a message sent by this user is not appended twice', () async {
      final provider = build();
      await provider.openThread(otherParty);

      await provider.sendMessage(otherParty, 'great set today');
      final id = provider.thread.single.messageId;
      signalR.emitIncoming(signalR.ack(
        messageId: id,
        otherPartyId: otherParty,
        body: 'great set today',
      ));
      await pumpEventQueue();

      expect(provider.thread, hasLength(1));
    });
  });

  group('sending', () {
    test('shows the bubble immediately, before the server has confirmed it', () async {
      final hold = Completer<void>();
      signalR.holdSend = hold;
      final provider = build();
      await provider.openThread(otherParty);

      unawaited(provider.sendMessage(otherParty, 'great set today'));
      await pumpEventQueue();

      // Waiting for the ack before drawing anything makes a slow network feel
      // like the send button is broken.
      expect(provider.thread.single.body, 'great set today');
      expect(provider.thread.single.status, ChatMessageStatus.pending);

      hold.complete();
    });

    test('settles the bubble to sent once acked', () async {
      final provider = build();
      await provider.openThread(otherParty);

      await provider.sendMessage(otherParty, 'great set today');

      expect(provider.thread.single.status, ChatMessageStatus.sent);
    });

    test('keeps a failed send visible so it can be retried', () async {
      signalR.throwOnSend = StateError('down');
      final provider = build();
      await provider.openThread(otherParty);

      await provider.sendMessage(otherParty, 'great set today');

      expect(provider.thread, hasLength(1));
      expect(provider.thread.single.status, ChatMessageStatus.pending);
    });

    test('ignores an empty composer', () async {
      final provider = build();
      await provider.openThread(otherParty);

      await provider.sendMessage(otherParty, '   ');

      expect(provider.thread, isEmpty);
      expect(signalR.sent, isEmpty);
    });
  });

  group('connection status', () {
    test('follows the transport', () async {
      final provider = build();
      await provider.openThread(otherParty);

      signalR.emitStatus(ChatConnectionStatus.reconnecting);
      await pumpEventQueue();
      expect(provider.connectionStatus, ChatConnectionStatus.reconnecting);

      signalR.emitStatus(ChatConnectionStatus.connected);
      await pumpEventQueue();
      expect(provider.connectionStatus, ChatConnectionStatus.connected);
    });

    test('a reconnect replays queued messages into the open thread', () async {
      signalR.throwOnSend = StateError('down');
      final provider = build();
      await provider.openThread(otherParty);
      await provider.sendMessage(otherParty, 'great set today');
      expect(provider.thread.single.status, ChatMessageStatus.pending);

      signalR.throwOnSend = null;
      signalR.fireReconnected();
      await pumpEventQueue();

      expect(provider.thread.single.status, ChatMessageStatus.sent);
    });
  });
}
