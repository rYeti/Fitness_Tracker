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
  late FakeChatCrypto crypto;

  setUp(() {
    db = newTestDatabase();
    signalR = FakeChatSignalRClient();
    crypto = FakeChatCrypto();
  });

  tearDown(() async {
    await signalR.dispose();
    await db.close();
  });

  ChatRepository build({
    FakeChatApi? api,
    int maxReplayAttempts = 3,
    FakeChatCrypto? cryptoOverride,
    FakeChatAttachmentSender? attachmentSender,
  }) {
    return ChatRepository(
      db: db,
      api: api ?? FakeChatApi(),
      signalR: signalR,
      crypto: cryptoOverride ?? crypto,
      attachmentSender: attachmentSender ?? FakeChatAttachmentSender(),
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

    test('reconnect replays every thread with a pending message, not just the open one', () async {
      // The bug this pins: a trainer messaging several clients queues rows
      // across several `otherPartyId`s. Only replaying `_activeThreadId` left
      // every other thread's message stuck at `pending` forever, because
      // nothing else ever revisited it.
      const otherClient = 'another-client';
      await seedOutboxRow(db,
          messageId: 'm1', otherPartyId: otherParty, body: 'first', createdAt: DateTime.utc(2026, 8, 1));
      await seedOutboxRow(db,
          messageId: 'm2', otherPartyId: otherClient, body: 'second', createdAt: DateTime.utc(2026, 8, 1));
      final repository = build();
      // Only otherParty's thread is open when the reconnect fires.
      await repository.openThread(otherParty);

      signalR.fireReconnected();
      await pumpEventQueue();

      expect(signalR.sent.map((s) => s.messageId).toSet(), {'m1', 'm2'});
      expect(await db.chatoutboxDao.getPendingMessages(otherParty), isEmpty);
      expect(await db.chatoutboxDao.getPendingMessages(otherClient), isEmpty);
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
    test('joins the thread\'s group when it opens and keeps it when it closes',
        () async {
      final repository = build();

      await repository.openThread(otherParty);
      expect(signalR.joined, [otherParty]);

      await repository.closeThread();
      expect(signalR.left, isEmpty);
      expect(repository.activeThreadId, isNull);
    });

    test('stays in the previous group when opening the next', () async {
      final repository = build();

      await repository.openThread(otherParty);
      await repository.openThread('another-client');

      // The original code left the old group here, reasoning that messages for
      // threads nobody is looking at would only have to be filtered out again.
      // True of the thread view, and fatal to the inbox: it made every unread
      // badge undeliverable rather than merely unnecessary.
      expect(signalR.left, isEmpty);
      expect(signalR.joined, [otherParty, 'another-client']);
    });

    test('watching conversations joins each group exactly once', () async {
      final repository = build();

      await repository.watchConversations([otherParty, 'another-client']);
      // Opening one of them must not re-join a group already held.
      await repository.openThread(otherParty);
      await repository.watchConversations([otherParty, 'a-third-client']);

      expect(signalR.joined, [otherParty, 'another-client', 'a-third-client']);
    });

    test('a failed watch drops that conversation rather than the whole inbox',
        () async {
      final repository = build();
      signalR.throwOnJoin = StateError('socket still opening');

      await repository.watchConversations([otherParty]);

      // No throw: a conversation that could not be watched costs a stale badge
      // until the next load, which is a far better trade than an inbox that
      // fails to load at all.
      expect(signalR.joined, isEmpty);
    });

    test('delivers messages for threads that are not open', () async {
      final repository = build();
      await repository.watchConversations([otherParty, 'another-client']);
      await repository.openThread(otherParty);

      final seen = <String>[];
      repository.allIncoming.listen((m) => seen.add(m.id));

      signalR.emitIncoming(signalR.ack(
        messageId: 'from-the-other-thread',
        otherPartyId: 'another-client',
        body: 'a message about a conversation you are not looking at',
        senderId: 'another-client',
      ));
      await pumpEventQueue();

      // incomingFor() would have dropped this — it is not the open thread. The
      // inbox has to hear about it anyway; that is what an unread badge is.
      expect(seen, ['from-the-other-thread']);
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

  group('encryption', () {
    test('the wire carries ciphertext, never the plaintext', () async {
      final repository = build();
      await repository.openThread(otherParty);

      await repository.sendMessage(
        otherPartyId: otherParty,
        body: 'great set today',
      );

      final wire = signalR.sent.single;
      expect(wire.body, isNot('great set today'));
      expect(wire.body, FakeChatCrypto.sealed('great set today'));
      expect(wire.iv, isNotNull);
      expect(wire.encryptionVersion, 1);
    });

    test('the bubble shows plaintext even though the ack carries ciphertext',
        () async {
      // The ack is a faithful copy of what the server stored, so its body is
      // the ciphertext that was just sent. Building the bubble from it rather
      // than from the plaintext already in hand puts base64 on screen — and
      // every assertion about sending still passes.
      final repository = build();
      await repository.openThread(otherParty);

      final sent = await repository.sendMessage(
        otherPartyId: otherParty,
        body: 'great set today',
      );

      expect(sent.body, 'great set today');
      expect(sent.status, ChatMessageStatus.sent);
    });

    test('history is decrypted before it reaches the thread', () async {
      final repository = build(
        api: FakeChatApi(history: {
          otherParty: [
            messageJson(
              id: 'server-1',
              body: 'enc:how did it go?',
              iv: 'iv-9',
              encryptionVersion: 1,
              senderId: otherParty,
              clientId: otherParty,
            ),
          ],
        }),
      );
      await repository.openThread(otherParty);

      final thread = await repository.loadThread(otherParty);

      expect(thread.single.body, 'how did it go?');
      expect(thread.single.isUndecryptable, isFalse);
    });

    test('a message this device cannot read does not fail the whole thread',
        () async {
      // The reinstall case. One unreadable message must cost one bubble, not
      // the conversation — a throw here would empty the screen.
      final repository = build(
        api: FakeChatApi(history: {
          otherParty: [
            messageJson(
              id: 'unreadable',
              body: 'not-our-ciphertext',
              iv: 'iv-1',
              encryptionVersion: 1,
              senderId: otherParty,
              clientId: otherParty,
              sentAt: DateTime.utc(2026, 8, 1, 9),
            ),
            messageJson(
              id: 'readable',
              body: 'enc:but this one is fine',
              iv: 'iv-2',
              encryptionVersion: 1,
              senderId: otherParty,
              clientId: otherParty,
              sentAt: DateTime.utc(2026, 8, 1, 10),
            ),
          ],
        }),
      );
      await repository.openThread(otherParty);

      final thread = await repository.loadThread(otherParty);

      expect(thread, hasLength(2));
      expect(thread.first.isUndecryptable, isTrue);
      expect(thread.first.body, isNull);
      expect(thread.last.body, 'but this one is fine');
    });

    test('a legacy plaintext row still renders', () async {
      // Written before encryption existed. There is no key for these and never
      // will be; version 0 says the body simply is the message.
      final repository = build(
        api: FakeChatApi(history: {
          otherParty: [
            messageJson(
              id: 'old',
              body: 'written in 2026',
              senderId: otherParty,
              clientId: otherParty,
            ),
          ],
        }),
      );
      await repository.openThread(otherParty);

      final thread = await repository.loadThread(otherParty);

      expect(thread.single.body, 'written in 2026');
      expect(thread.single.isUndecryptable, isFalse);
    });

    test('a live message is decrypted before it reaches the thread', () async {
      final repository = build();
      await repository.openThread(otherParty);

      final seen = <ThreadMessage>[];
      repository.incomingFor(otherParty).listen(seen.add);

      signalR.emitIncoming(signalR.ack(
        messageId: 'incoming-1',
        otherPartyId: otherParty,
        body: 'enc:nice work',
        senderId: otherParty,
        iv: 'iv-3',
        encryptionVersion: 1,
      ));
      await pumpEventQueue();

      expect(seen.single.body, 'nice work');
    });

    test('a replay re-encrypts with a fresh IV rather than reusing one',
        () async {
      // An IV must never be reused with the same key, and re-encrypting is also
      // what reaches a peer who reinstalled between the two attempts. The server
      // dedupes on messageId, so exactly one message still lands.
      signalR.failFirstNSends = 1;
      final repository = build();
      await repository.openThread(otherParty);

      await repository.sendMessage(
        otherPartyId: otherParty,
        body: 'see you thursday',
      );
      signalR.fireReconnected();
      await pumpEventQueue();

      expect(signalR.sent, hasLength(2));
      expect(signalR.sent.first.messageId, signalR.sent.last.messageId);
      expect(signalR.sent.first.iv, isNot(signalR.sent.last.iv));
    });

    test('a peer with no published key leaves the message pending', () async {
      // Refusing to send beats sending something nobody can read: the row stays
      // in the outbox and the next reconnect tries again.
      crypto.keylessPeers.add(otherParty);
      final repository = build();
      await repository.openThread(otherParty);

      final sent = await repository.sendMessage(
        otherPartyId: otherParty,
        body: 'anyone there?',
      );

      expect(sent.status, ChatMessageStatus.pending);
      expect(signalR.sent, isEmpty);
    });

    test('a peer who reinstalled is re-fetched once and the thread recovers',
        () async {
      // Their published key changed and this device is still holding the one it
      // cached, so everything they send fails against it. Nothing else would go
      // and look: the cache is wrong, not stale.
      crypto.undecryptablePeers.add(otherParty);
      final repository = build(
        api: FakeChatApi(history: {
          otherParty: [
            messageJson(
              id: 'after-their-reinstall',
              body: 'enc:new phone, who dis',
              iv: 'iv-7',
              encryptionVersion: 1,
              senderId: otherParty,
              clientId: otherParty,
            ),
          ],
        }),
      );
      await repository.openThread(otherParty);

      final thread = await repository.loadThread(otherParty);

      // FakeChatCrypto.forget clears the peer, so the retry succeeds — which is
      // exactly what a real re-fetch of their new public key does.
      expect(crypto.forgotten, [otherParty]);
      expect(thread.single.body, 'new phone, who dis');
    });

    test('a genuinely unreadable thread re-fetches once, not once per message',
        () async {
      // The common case: messages encrypted to a key that no longer exists
      // anywhere. Retrying per bubble would turn scrolling old history into one
      // key fetch per line.
      final repository = build(
        api: FakeChatApi(history: {
          otherParty: [
            for (var i = 0; i < 3; i++)
              messageJson(
                id: 'lost-$i',
                body: 'not-our-ciphertext',
                iv: 'iv-$i',
                encryptionVersion: 1,
                senderId: otherParty,
                clientId: otherParty,
                sentAt: DateTime.utc(2026, 8, 1, 9 + i),
              ),
          ],
        }),
      );
      await repository.openThread(otherParty);

      final thread = await repository.loadThread(otherParty);

      expect(crypto.forgotten, [otherParty]);
      expect(thread.every((m) => m.isUndecryptable), isTrue);
    });

    test('conversation previews are decrypted', () async {
      final repository = build(
        api: FakeChatApi(conversations: [
          {
            'otherPartyId': otherParty,
            'otherPartyName': 'Robert Meyer',
            'lastMessagePreview': 'enc:see you thursday',
            'lastMessageIv': 'iv-4',
            'lastMessageEncryptionVersion': 1,
            'lastMessageAt': DateTime.utc(2026, 8, 1, 9).toIso8601String(),
            'unreadCount': 1,
          },
        ]),
      );

      final only = (await repository.getConversations()).single;

      expect(only.lastMessagePreview, 'see you thursday');
    });

    test('an unreadable preview becomes null rather than base64', () async {
      final repository = build(
        api: FakeChatApi(conversations: [
          {
            'otherPartyId': otherParty,
            'otherPartyName': 'Robert Meyer',
            'lastMessagePreview': 'not-our-ciphertext',
            'lastMessageIv': 'iv-5',
            'lastMessageEncryptionVersion': 1,
            'lastMessageAt': DateTime.utc(2026, 8, 1, 9).toIso8601String(),
            'unreadCount': 1,
          },
        ]),
      );

      final only = (await repository.getConversations()).single;

      // Null, with a timestamp still set — which is how ConversationRow tells
      // "cannot read this" apart from "no messages yet".
      expect(only.lastMessagePreview, isNull);
      expect(only.lastMessageAt, isNotNull);
    });
  });
}
