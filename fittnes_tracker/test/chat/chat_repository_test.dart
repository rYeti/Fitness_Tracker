import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/feature/chat/data/chat_repository.dart';
import 'package:ForgeForm/feature/chat/domain/models/thread_message.dart';

import 'fakes.dart';

/// The other side of every thread in these tests. On the Trainer Console this is
/// the client's id; the repository never needs to know which role it is serving.
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

  ChatRepository build({FakeChatApi? api, int maxReplayAttempts = 3}) {
    return ChatRepository(
      db: db,
      api: api ?? FakeChatApi(),
      signalR: signalR,
      maxReplayAttempts: maxReplayAttempts,
    );
  }

  group('sending', () {
    test('writes a pending outbox row before the message reaches the wire', () async {
      final hold = Completer<void>();
      signalR.holdSend = hold;
      final repository = build();

      // Deliberately not awaited: we want to inspect the world while the send is
      // still in flight, which is the state a dropped connection freezes forever.
      unawaited(repository.sendMessage(otherPartyId: otherParty, body: 'great set today'));
      await pumpEventQueue();

      final pending = await db.chatoutboxDao.getPendingMessages(otherParty);
      expect(pending, hasLength(1));
      expect(pending.single.body, 'great set today');
      expect(pending.single.chatMessageStatus, ChatMessageStatus.pending.index);

      hold.complete();
    });

    test('marks the row sent once the ack arrives', () async {
      final repository = build();

      await repository.sendMessage(otherPartyId: otherParty, body: 'great set today');

      expect(await db.chatoutboxDao.getPendingMessages(otherParty), isEmpty);
      final rows = await db.chatoutboxDao.getUnsentMessages(otherParty);
      expect(rows, isEmpty, reason: 'an acked message is no longer unsent');
    });

    test('sends the id it wrote to the outbox, not a fresh one', () async {
      final repository = build();

      final sent = await repository.sendMessage(otherPartyId: otherParty, body: 'hello');

      expect(signalR.sent.single.messageId, sent.messageId);
      expect(signalR.sent.single.otherPartyId, otherParty);
    });

    test('leaves the row pending when the send fails, and does not retry inline', () async {
      signalR.throwOnSend = StateError('connection lost');
      final repository = build();

      final message = await repository.sendMessage(otherPartyId: otherParty, body: 'great set today');

      // Still pending, not failed: one lost ack says nothing about whether the
      // server stored it, so the message stays queued for the next reconnect.
      expect(message.status, ChatMessageStatus.pending);
      expect(await db.chatoutboxDao.getPendingMessages(otherParty), hasLength(1));
      // Exactly one attempt — retrying here would fight the reconnect handler.
      expect(signalR.sent, hasLength(1));
    });
  });

  group('replay on reconnect', () {
    test('resends pending messages in the order they were typed', () async {
      final base = DateTime.utc(2026, 8, 1, 9);
      await seedOutboxRow(db,
          messageId: 'm2', otherPartyId: otherParty, body: 'second', createdAt: base.add(const Duration(seconds: 2)));
      await seedOutboxRow(db,
          messageId: 'm1', otherPartyId: otherParty, body: 'first', createdAt: base);
      await seedOutboxRow(db,
          messageId: 'm3', otherPartyId: otherParty, body: 'third', createdAt: base.add(const Duration(seconds: 4)));
      final repository = build();

      await repository.replayPending(otherParty);

      // SignalR guarantees ordering within one invocation, not across concurrent
      // ones, so replay is sequential and ordered by when the user pressed send.
      expect(signalR.sent.map((s) => s.messageId), ['m1', 'm2', 'm3']);
      expect(await db.chatoutboxDao.getPendingMessages(otherParty), isEmpty);
    });

    test('reuses the original message id so the server can dedupe the replay', () async {
      await seedOutboxRow(db,
          messageId: 'm1', otherPartyId: otherParty, body: 'first', createdAt: DateTime.utc(2026, 8, 1));
      final repository = build();

      await repository.replayPending(otherParty);

      expect(signalR.sent.single.messageId, 'm1');
    });

    test('is triggered by the reconnect signal rather than by a timer', () async {
      await seedOutboxRow(db,
          messageId: 'm1', otherPartyId: otherParty, body: 'first', createdAt: DateTime.utc(2026, 8, 1));
      final repository = build();
      await repository.openThread(otherParty);
      expect(signalR.sent, isEmpty);

      signalR.fireReconnected();
      await pumpEventQueue();

      expect(signalR.sent.single.messageId, 'm1');
    });

    test('leaves later messages queued when an earlier one fails again', () async {
      signalR.failFirstNSends = 1;
      final base = DateTime.utc(2026, 8, 1, 9);
      await seedOutboxRow(db, messageId: 'm1', otherPartyId: otherParty, body: 'first', createdAt: base);
      await seedOutboxRow(db,
          messageId: 'm2', otherPartyId: otherParty, body: 'second', createdAt: base.add(const Duration(seconds: 1)));
      final repository = build();

      await repository.replayPending(otherParty);

      // Stopping on the first failure keeps the thread in order: sending 'second'
      // while 'first' is still unsent would land them the wrong way round.
      expect(signalR.sent.map((s) => s.messageId), ['m1']);
      expect(await db.chatoutboxDao.getPendingMessages(otherParty), hasLength(2));
    });

    test('marks a message failed once the retry budget is spent', () async {
      signalR.throwOnSend = StateError('still down');
      await seedOutboxRow(db,
          messageId: 'm1', otherPartyId: otherParty, body: 'first', createdAt: DateTime.utc(2026, 8, 1));
      final repository = build(maxReplayAttempts: 3);

      for (var attempt = 0; attempt < 3; attempt++) {
        await repository.replayPending(otherParty);
      }

      // `failed` exists only on the client — the server never saw anything to
      // fail — so this is the one state needing a manual retry affordance.
      expect(await db.chatoutboxDao.getPendingMessages(otherParty), isEmpty);
      final unsent = await db.chatoutboxDao.getUnsentMessages(otherParty);
      expect(unsent.single.chatMessageStatus, ChatMessageStatus.failed.index);
    });

    test('a manual retry puts a failed message back in the queue with its id intact', () async {
      await seedOutboxRow(db,
          messageId: 'm1',
          otherPartyId: otherParty,
          body: 'first',
          createdAt: DateTime.utc(2026, 8, 1),
          status: ChatMessageStatus.failed);
      final repository = build();

      await repository.retryMessage('m1');

      expect(signalR.sent.single.messageId, 'm1');
      expect(await db.chatoutboxDao.getUnsentMessages(otherParty), isEmpty);
    });
  });

  group('loading a thread', () {
    test('merges server history with messages that have not been acked yet', () async {
      final api = FakeChatApi(history: {
        otherParty: [
          messageJson(
            id: 'server-1',
            body: 'how did it go?',
            senderId: otherParty,
            clientId: otherParty,
            sentAt: DateTime.utc(2026, 8, 1, 9),
          ),
        ],
      });
      await seedOutboxRow(db,
          messageId: 'local-1',
          otherPartyId: otherParty,
          body: 'still sending',
          createdAt: DateTime.utc(2026, 8, 1, 10));
      final repository = build(api: api);

      final thread = await repository.loadThread(otherParty);

      // A message the user just sent must stay on screen while it is in flight,
      // marked as sending — dropping it until the ack lands looks like data loss.
      expect(thread.map((m) => m.messageId), ['server-1', 'local-1']);
      expect(thread.first.status, ChatMessageStatus.sent);
      expect(thread.last.status, ChatMessageStatus.pending);
    });

    test('marks a message mine when the sender is not the other party', () async {
      final api = FakeChatApi(history: {
        otherParty: [
          messageJson(
            id: 'theirs',
            body: 'how did it go?',
            senderId: otherParty,
            clientId: otherParty,
            sentAt: DateTime.utc(2026, 8, 1, 9),
          ),
          messageJson(
            id: 'mine',
            body: 'strong session',
            senderId: FakeChatSignalRClient.trainerId,
            clientId: otherParty,
            sentAt: DateTime.utc(2026, 8, 1, 10),
          ),
        ],
      });
      final repository = build(api: api);

      final thread = await repository.loadThread(otherParty);

      // There are only ever two parties in a thread, so "not them" means "me" —
      // which is how this works without the client knowing its own user id.
      expect(thread.firstWhere((m) => m.messageId == 'theirs').isMine, isFalse);
      expect(thread.firstWhere((m) => m.messageId == 'mine').isMine, isTrue);
    });

    test('shows unsent messages from a previous launch, including failed ones', () async {
      await seedOutboxRow(db,
          messageId: 'gave-up',
          otherPartyId: otherParty,
          body: 'never made it',
          createdAt: DateTime.utc(2026, 8, 1),
          status: ChatMessageStatus.failed);
      final repository = build();

      final thread = await repository.loadThread(otherParty);

      expect(thread.single.status, ChatMessageStatus.failed);
      expect(thread.single.isMine, isTrue);
    });

    test('does not show another thread\'s unsent messages', () async {
      await seedOutboxRow(db,
          messageId: 'other-thread',
          otherPartyId: 'someone-else',
          body: 'not here',
          createdAt: DateTime.utc(2026, 8, 1));
      final repository = build();

      expect(await repository.loadThread(otherParty), isEmpty);
    });

    test('shows a message once when it is in both history and the outbox',
        () async {
      // Not a contrived overlap — it is the case the outbox exists for. The
      // server stored the message and the ack was lost coming back, so the local
      // row stays pending on purpose (guessing either way loses messages), and
      // both lists legitimately contain it. Concatenating them showed the user
      // one message twice: once sent, and once as a failure inviting them to
      // send it again.
      await seedOutboxRow(db,
          messageId: 'acked-but-unconfirmed',
          otherPartyId: otherParty,
          body: 'did you see my form?',
          createdAt: DateTime.utc(2026, 8, 1, 9));
      final repository = build(
        api: FakeChatApi(history: {
          otherParty: [
            messageJson(
              id: 'acked-but-unconfirmed',
              body: 'did you see my form?',
              senderId: FakeChatSignalRClient.trainerId,
              clientId: otherParty,
              sentAt: DateTime.utc(2026, 8, 1, 9),
            ),
          ],
        }),
      );

      final thread = await repository.loadThread(otherParty);

      // The server's copy wins: it is the authoritative one, and it is the only
      // one of the two that can say the message actually arrived.
      expect(thread, hasLength(1));
      expect(thread.single.status, ChatMessageStatus.sent);
    });

    test('surfaces a history failure instead of showing an empty thread', () async {
      final repository = build(api: FakeChatApi(throwOnHistory: true));

      expect(() => repository.loadThread(otherParty), throwsA(isA<Exception>()));
    });
  });

  group('incoming messages', () {
    test('delivers messages from the other party', () async {
      final repository = build();
      await repository.openThread(otherParty);
      final received = <ThreadMessage>[];
      repository.incomingFor(otherParty).listen(received.add);

      signalR.emitIncoming(signalR.ack(
        messageId: 'theirs',
        otherPartyId: otherParty,
        body: 'thanks!',
        senderId: otherParty,
      ));
      await pumpEventQueue();

      expect(received.single.messageId, 'theirs');
      expect(received.single.isMine, isFalse);
    });

    test('does not deliver a message twice when the ack and the broadcast both arrive', () async {
      final repository = build();
      await repository.openThread(otherParty);
      final received = <ThreadMessage>[];
      repository.incomingFor(otherParty).listen(received.add);

      final sent = await repository.sendMessage(otherPartyId: otherParty, body: 'great set today');
      // The hub broadcasts to the whole group, sender included, so the message
      // the ack already returned comes back a second time.
      signalR.emitIncoming(signalR.ack(
        messageId: sent.messageId,
        otherPartyId: otherParty,
        body: 'great set today',
      ));
      await pumpEventQueue();

      expect(received, isEmpty, reason: 'the sender already has this message from the ack');
    });

    test('ignores messages belonging to a different thread', () async {
      final repository = build();
      await repository.openThread(otherParty);
      final received = <ThreadMessage>[];
      repository.incomingFor(otherParty).listen(received.add);

      signalR.emitIncoming(signalR.ack(
        messageId: 'elsewhere',
        otherPartyId: 'someone-else',
        body: 'not for this thread',
        senderId: 'someone-else',
      ));
      await pumpEventQueue();

      expect(received, isEmpty);
    });
  });

  group('groups and conversations', () {
    test('joins the thread\'s group when it opens and leaves it when it closes', () async {
      final repository = build();

      await repository.openThread(otherParty);
      expect(signalR.joined, [otherParty]);

      await repository.closeThread();
      expect(signalR.left, [otherParty]);
    });

    test('leaves the previous group before joining the next', () async {
      final repository = build();

      await repository.openThread(otherParty);
      await repository.openThread('another-client');

      // Staying joined to every client's group would deliver messages for threads
      // that are not on screen.
      expect(signalR.left, [otherParty]);
      expect(signalR.joined, [otherParty, 'another-client']);
    });

    test('maps conversation rows from the API', () async {
      final repository = build(
        api: FakeChatApi(conversations: [
          {
            'otherPartyId': otherParty,
            'otherPartyName': 'Robert Meyer',
            'lastMessagePreview': 'see you thursday',
            'lastMessageAt': DateTime.utc(2026, 8, 1, 9).toIso8601String(),
            'unreadCount': 2,
          },
        ]),
      );

      final conversations = await repository.getConversations();

      final only = conversations.single;
      expect(only.clientId, otherParty);
      expect(only.clientName, 'Robert Meyer');
      expect(only.initials, 'RM');
      expect(only.lastMessagePreview, 'see you thursday');
      expect(only.unreadCount, 2);
    });

    test('handles a conversation that has no messages yet', () async {
      final repository = build(
        api: FakeChatApi(conversations: [
          {
            'otherPartyId': otherParty,
            'otherPartyName': 'Robert Meyer',
            'lastMessagePreview': null,
            'lastMessageAt': null,
            'unreadCount': 0,
          },
        ]),
      );

      final only = (await repository.getConversations()).single;

      expect(only.lastMessagePreview, isNull);
      expect(only.lastMessageAt, isNull);
    });

    test('tells the server the thread was read when it opens', () async {
      final api = FakeChatApi();
      final repository = build(api: api);

      await repository.openThread(otherParty);
      await repository.loadThread(otherParty);

      expect(api.markedRead, [otherParty]);
    });
  });
}
