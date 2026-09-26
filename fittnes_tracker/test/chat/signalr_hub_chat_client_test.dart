import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/feature/chat/data/chat_signalr_client.dart';
import 'package:ForgeForm/feature/chat/data/signalr_hub_chat_client.dart';

import 'fakes.dart';

/// The connection's own lifecycle: which groups it joins on every connect,
/// that chat never waits for them, that a join that fails is tried again,
/// and starting afresh after SignalR's automatic reconnect gives up. See
/// `docs/sync-architecture.md`, part four.
///
/// Each test was run with the rule it pins taken out, and failed there.

/// Lets timers of zero delay and the microtasks after them run.
Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeHubServer server;
  late List<ChatConnectionStatus> statuses;
  late int reconnects;
  late int rejoins;

  SignalRHubChatClient client({
    bool joinTrainerGroup = true,
    Duration Function(int attempt)? restartDelay,
  }) {
    final built = SignalRHubChatClient(
      baseUrl: 'https://api.test',
      joinTrainerGroup: joinTrainerGroup,
      buildConnection: server.build,
      restartDelay: restartDelay ?? (_) => Duration.zero,
    );
    built.connectionStatus.listen(statuses.add);
    built.onReconnected.listen((_) => reconnects++);
    built.trainerGroupRejoined.listen((_) => rejoins++);
    addTearDown(built.dispose);
    return built;
  }

  setUp(() {
    server = FakeHubServer();
    statuses = [];
    reconnects = 0;
    rejoins = 0;
  });

  group('the trainer group', () {
    test('is joined once the connection is up', () async {
      await client().connect();

      expect(server.hubs.single.invoked, ['JoinTrainerGroup']);
      await _settle();
      expect(statuses, [ChatConnectionStatus.connected]);
    });

    test('is joined again after SignalR reconnects', () async {
      await client().connect();
      final hub = server.hubs.single;

      // A reconnect is a new connection id, which is in no group at all.
      hub.reconnect();
      await _settle();

      expect(hub.invoked, ['JoinTrainerGroup', 'JoinTrainerGroup']);
      expect(statuses.last, ChatConnectionStatus.connected);
      expect(reconnects, 1);
    });

    test('is joined on the fresh connection after a close', () async {
      await client().connect();

      server.hubs.single.giveUp();
      await _settle();

      expect(server.hubs, hasLength(2));
      expect(server.hubs.last.invoked, ['JoinTrainerGroup']);
    });

    test('is never joined by a connection that is not the console\'s', () async {
      final trainee = client(joinTrainerGroup: false);
      await trainee.connect();
      server.hubs.single.reconnect();
      server.hubs.single.giveUp();
      await _settle();

      expect(server.hubs, hasLength(2));
      for (final hub in server.hubs) {
        expect(hub.invoked, isEmpty);
      }
    });

    test('is announced as rejoined after a gap, not on the first connect', () async {
      await client().connect();
      await _settle();
      expect(rejoins, 0, reason: 'the first join: the console reads anyway');

      server.hubs.single.reconnect();
      await _settle();
      expect(rejoins, 1, reason: 'SignalR\'s own reconnect');

      server.hubs.single.giveUp();
      await _settle();
      expect(rejoins, 2, reason: 'a fresh start after a close');
    });

    test('is announced as rejoined only once the join has succeeded', () async {
      await client().connect();
      final join = Completer<void>();
      server.hold['JoinTrainerGroup'] = join;

      server.hubs.single.reconnect();
      await _settle();
      // Anyone reading again because of this must read with the events
      // already flowing, so nobody hears of it while the join is in flight.
      expect(rejoins, 0);

      join.complete();
      await _settle();
      expect(rejoins, 1);
    });
  });

  group('chat', () {
    test('does not wait for the trainer group to be joined', () async {
      final join = Completer<void>();
      server.hold['JoinTrainerGroup'] = join;
      final chat = client();

      var connected = false;
      unawaited(chat.connect().then((_) => connected = true));
      await _settle();

      expect(server.hubs.single.invoked, ['JoinTrainerGroup']);
      expect(connected, isTrue, reason: 'connect() waits only for the handshake');
      expect(statuses, [ChatConnectionStatus.connected]);
      // And so a chat call waiting on the connection goes ahead.
      await chat.joinGroup('client-1');
      expect(server.hubs.single.invoked, contains('JoinClientGroup(client-1)'));

      join.complete();
    });

    test('says it is back after a reconnect without waiting for the join', () async {
      await client().connect();
      server.hold['JoinTrainerGroup'] = Completer<void>();

      server.hubs.single.reconnect();
      await _settle();

      expect(statuses.last, ChatConnectionStatus.connected);
      expect(reconnects, 1, reason: 'the outbox replays at once');
    });
  });

  group('a conversation group', () {
    test('is joined again after SignalR reconnects', () async {
      final chat = client(joinTrainerGroup: false);
      await chat.joinGroup('client-1');
      final hub = server.hubs.single;

      hub.reconnect();
      await _settle();

      // Without it the new connection id is in no chat group, and every
      // message the client sends from now on reaches nobody here.
      expect(hub.invoked, [
        'JoinClientGroup(client-1)',
        'JoinClientGroup(client-1)',
      ]);
    });

    test('is joined on the fresh connection after a close', () async {
      final chat = client();
      await chat.joinGroup('client-1');
      await chat.joinGroup('client-2');

      server.hubs.single.giveUp();
      await _settle();

      expect(server.hubs, hasLength(2));
      expect(
        server.hubs.last.invoked,
        unorderedEquals([
          'JoinTrainerGroup',
          'JoinClientGroup(client-1)',
          'JoinClientGroup(client-2)',
        ]),
      );
    });

    test('that was left, or never joined, is not joined again', () async {
      server.failNext['JoinClientGroup'] = 1;
      final chat = client(joinTrainerGroup: false);
      await expectLater(chat.joinGroup('client-1'), throwsException);
      await chat.joinGroup('client-2');
      await chat.leaveGroup('client-2');

      server.hubs.single.giveUp();
      await _settle();

      // The caller retries a join that failed itself, and a group left on
      // purpose stays left.
      expect(server.hubs.last.invoked, isEmpty);
    });
  });

  group('a join that fails', () {
    test('is tried again until it succeeds, and then announced', () async {
      final asked = <int>[];
      server.failNext['JoinTrainerGroup'] = 3;
      final chat = client(
        restartDelay: (attempt) {
          asked.add(attempt);
          return Duration.zero;
        },
      );

      await chat.connect();
      await _settle();

      expect(server.hubs.single.invoked, List.filled(4, 'JoinTrainerGroup'));
      expect(asked, [0, 1, 2], reason: 'the fresh start\'s backoff');
      // The first join came late, so whatever was sent meanwhile is read now.
      expect(rejoins, 1);
    });

    test('is tried again for a conversation too', () async {
      final chat = client(joinTrainerGroup: false);
      await chat.joinGroup('client-1');
      server.failNext['JoinClientGroup'] = 1;

      server.hubs.single.reconnect();
      await _settle();

      expect(server.hubs.single.invoked, List.filled(3, 'JoinClientGroup(client-1)'));
    });

    test('is not tried again once its connection has closed', () async {
      server.failNext['JoinTrainerGroup'] = 1;
      await client(
        restartDelay: (_) => const Duration(milliseconds: 20),
      ).connect();
      await _settle();
      expect(server.hubs.single.invoked, ['JoinTrainerGroup']);
      // The join has failed, and its retry is waiting.

      server.hubs.single.giveUp();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      // The new connection makes its own join; the old one is not asked.
      expect(server.hubs, hasLength(2));
      expect(server.hubs.first.invoked, ['JoinTrainerGroup']);
      expect(server.hubs.last.invoked, ['JoinTrainerGroup']);
    });

    test('is not tried again after a disconnect', () async {
      server.failNext['JoinTrainerGroup'] = 1;
      final chat = client(
        restartDelay: (_) => const Duration(milliseconds: 20),
      );
      await chat.connect();
      await _settle();

      await chat.disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(server.hubs.single.invoked, ['JoinTrainerGroup']);
    });
  });

  group('after automatic reconnect gives up', () {
    test('a fresh connection is started, and counts as a reconnect', () async {
      await client().connect();

      server.hubs.single.giveUp();
      await _settle();

      expect(server.hubs, hasLength(2), reason: 'a fresh start after the close');
      expect(statuses, [
        ChatConnectionStatus.connected,
        ChatConnectionStatus.disconnected,
        ChatConnectionStatus.connected,
      ]);
      // Chat replays its outbox on this; the console reads again once the
      // trainer group is joined.
      expect(reconnects, 1);
    });

    test('a failing fresh start backs off and tries again', () async {
      final asked = <int>[];
      final chat = client(
        restartDelay: (attempt) {
          asked.add(attempt);
          return Duration.zero;
        },
      );
      await chat.connect();

      server.failNextStarts = 3;
      server.hubs.single.giveUp();
      await _settle();

      expect(server.hubs, hasLength(5), reason: 'three failures, then up');
      expect(asked, [0, 1, 2, 3]);
      expect(statuses.last, ChatConnectionStatus.connected);
      expect(reconnects, 1);

      // Up again, so the next outage starts the backoff from the beginning.
      server.hubs.last.giveUp();
      await _settle();
      expect(asked, [0, 1, 2, 3, 0]);
    });

    test('the backoff starts at five seconds and is capped at a minute', () {
      expect(
        [for (var i = 0; i < 7; i++) SignalRHubChatClient.restartDelayFor(i)],
        const [
          Duration(seconds: 5),
          Duration(seconds: 10),
          Duration(seconds: 20),
          Duration(seconds: 40),
          Duration(seconds: 60),
          Duration(seconds: 60),
          Duration(seconds: 60),
        ],
      );
    });

    test('dispose stops the retries', () async {
      final chat = SignalRHubChatClient(
        baseUrl: 'https://api.test',
        joinTrainerGroup: true,
        buildConnection: server.build,
        restartDelay: (_) => const Duration(milliseconds: 20),
      );
      await chat.connect();

      server.hubs.single.giveUp();
      await chat.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(server.hubs, hasLength(1));
    });

    test('a disconnect is not undone behind the caller\'s back', () async {
      final chat = client(
        restartDelay: (_) => const Duration(milliseconds: 20),
      );
      await chat.connect();

      await chat.disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(server.hubs, hasLength(1));
      expect(server.hubs.single.stopped, isTrue);
    });
  });
}
