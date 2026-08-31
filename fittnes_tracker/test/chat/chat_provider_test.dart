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
        crypto: FakeChatCrypto(),
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

    test('raises an unread badge for a message in a thread that is not open',
        () async {
      final provider = build(
        api: FakeChatApi(conversations: [
          conversationJson(otherParty, 'Robert Meyer'),
        ]),
      );
      await provider.loadConversations();
      expect(provider.conversations.single.unreadCount, 0);

      signalR.emitIncoming(signalR.ack(
        messageId: 'unseen',
        otherPartyId: otherParty,
        body: 'quick question about thursday',
        senderId: otherParty,
      ));
      await pumpEventQueue();

      final row = provider.conversations.single;
      expect(row.unreadCount, 1);
      expect(row.lastMessagePreview, 'quick question about thursday');
      expect(row.hasUnread, isTrue);
    });

    test('does not raise a badge for the thread the user is looking at',
        () async {
      final provider = build(
        api: FakeChatApi(conversations: [
          conversationJson(otherParty, 'Robert Meyer'),
        ]),
      );
      await provider.loadConversations();
      await provider.openThread(otherParty);

      signalR.emitIncoming(signalR.ack(
        messageId: 'while-watching',
        otherPartyId: otherParty,
        body: 'and one more thing',
        senderId: otherParty,
      ));
      await pumpEventQueue();

      expect(provider.conversations.single.unreadCount, 0);
      // The read has to reach the server too, or the badge returns on reload.
      expect(provider.conversations.single.lastMessagePreview,
          'and one more thing');
    });

    test('does not count this user\'s own message as unread', () async {
      final provider = build(
        api: FakeChatApi(conversations: [
          conversationJson(otherParty, 'Robert Meyer'),
        ]),
      );
      await provider.loadConversations();

      // The hub broadcasts to the whole group including the sender, so a
      // message this device sent comes back here as well. Counting it would
      // badge the trainer for their own reply.
      signalR.emitIncoming(signalR.ack(
        messageId: 'my-own',
        otherPartyId: otherParty,
        body: 'nice work today',
        senderId: FakeChatSignalRClient.trainerId,
      ));
      await pumpEventQueue();

      expect(provider.conversations.single.unreadCount, 0);
      expect(provider.conversations.single.lastMessagePreview, 'nice work today');
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

    test('switching client joins the new group and stays in the old one', () async {
      final provider = build();

      await provider.openThread(otherParty);
      await provider.openThread('another-client');

      // Deliberately reversed from the original behaviour. Leaving the previous
      // group made the inbox blind to it, and an unread badge is by definition
      // about a conversation you do not have open.
      expect(signalR.left, isEmpty);
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

    test('a failed group join surfaces an error instead of loading forever',
        () async {
      // The regression this pins: joining the hub group was awaited *outside*
      // openThread's try/finally, so a throw escaped past the `finally` and left
      // isThreadLoading true for good. Both thread views check that flag first,
      // so every message sent afterwards repainted the loading skeleton instead
      // of itself — chat looked slow rather than broken, with no error, no retry
      // and no way back.
      signalR.throwOnJoin = StateError('socket still opening');
      final provider = build();

      await provider.openThread(otherParty);

      expect(provider.isThreadLoading, isFalse);
      expect(provider.threadError, isNotNull);
    });

    test('a thread that failed to open recovers on retry', () async {
      signalR.throwOnJoin = StateError('socket still opening');
      final provider = build();
      await provider.openThread(otherParty);

      signalR.throwOnJoin = null;
      await provider.openThread(otherParty);

      expect(provider.threadError, isNull);
      expect(provider.isThreadLoading, isFalse);
      expect(signalR.joined, [otherParty]);
    });

    test('closing a thread clears the messages but keeps the group', () async {
      final provider = build();
      await provider.openThread(otherParty);

      await provider.closeThread();

      // Membership outlives the thread view: the conversation list still wants
      // this thread's messages for its preview and unread count.
      expect(signalR.left, isEmpty);
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

    test('reports a send that broke before the outbox instead of going silent',
        () async {
      final provider = build();
      await provider.openThread(otherParty);
      // Stands in for the outbox table not existing — which is exactly what a
      // missed schemaVersion bump produced on every upgraded install. The write
      // threw before onQueued fired, so there was no bubble, nothing reached the
      // hub, and the provider let the error escape unhandled: the composer
      // cleared and absolutely nothing else happened.
      await db.close();

      await provider.sendMessage(otherParty, 'great set today');

      expect(provider.sendError, isNotNull);
      expect(provider.thread, isEmpty);
    });

    test('a later successful send clears the send error', () async {
      final provider = build();
      await provider.openThread(otherParty);
      provider.clearSendError();

      await provider.sendMessage(otherParty, 'great set today');

      expect(provider.sendError, isNull);
      expect(provider.thread.single.status, ChatMessageStatus.sent);
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
