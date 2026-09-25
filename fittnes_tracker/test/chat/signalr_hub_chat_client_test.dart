import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:signalr_hub/signalr_client.dart';

import 'package:ForgeForm/feature/chat/data/chat_signalr_client.dart';
import 'package:ForgeForm/feature/chat/data/signalr_hub_chat_client.dart';

/// The connection's own lifecycle: joining the trainer's live-updates group on
/// every connect, and starting afresh after SignalR's automatic reconnect gives
/// up. See `docs/sync-architecture.md`, part four.
///
/// Each test was run with the rule it pins taken out, and failed there.

/// Stands in for one `HubConnection`: a test can say "SignalR reconnected" or
/// "SignalR gave up" in one line, and hold a hub call open.
class _FakeHub implements HubConnection {
  _FakeHub({this.startError});

  final Object? startError;
  final invoked = <String>[];
  bool stopped = false;

  /// Holds every `invoke` open until completed, when set.
  Completer<void>? holdInvoke;

  final _closed = <ClosedCallback>[];
  final _reconnecting = <ReconnectingCallback>[];
  final _reconnected = <ReconnectedCallback>[];

  @override
  Future<void> start() async {
    if (startError != null) throw startError!;
  }

  @override
  Future<void> stop() async {
    stopped = true;
    for (final callback in _closed) {
      callback();
    }
  }

  @override
  Future<Object?> invoke(String methodName, {List<Object?>? args}) async {
    invoked.add(methodName);
    await holdInvoke?.future;
    return null;
  }

  @override
  void on(String methodName, MethodInvocationFunc newMethod) {}

  @override
  void onclose(ClosedCallback callback) => _closed.add(callback);

  @override
  void onreconnecting(ReconnectingCallback callback) =>
      _reconnecting.add(callback);

  @override
  void onreconnected(ReconnectedCallback callback) =>
      _reconnected.add(callback);

  /// SignalR's own reconnect, which gives the connection a new id.
  void reconnect() {
    for (final callback in _reconnecting) {
      callback();
    }
    for (final callback in _reconnected) {
      callback(connectionId: 'a-new-id');
    }
  }

  /// SignalR's automatic reconnect ran out of attempts and closed.
  void giveUp() {
    for (final callback in _closed) {
      callback(error: Exception('reconnect gave up'));
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Builds the hubs, and fails the starts a test asks it to.
class _Server {
  final hubs = <_FakeHub>[];
  int failNextStarts = 0;

  HubConnection build(String url, AccessTokenFactory accessToken) {
    final fail = failNextStarts > 0;
    if (fail) failNextStarts--;
    final hub = _FakeHub(startError: fail ? Exception('no route') : null);
    hubs.add(hub);
    return hub;
  }
}

/// Lets timers of zero delay and the microtasks after them run.
Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _Server server;
  late List<ChatConnectionStatus> statuses;
  late int reconnects;

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
    addTearDown(built.dispose);
    return built;
  }

  setUp(() {
    server = _Server();
    statuses = [];
    reconnects = 0;
  });

  group('the trainer group', () {
    test('is joined once the connection is up', () async {
      await client().connect();

      expect(server.hubs.single.invoked, ['JoinTrainerGroup']);
      await _settle();
      expect(statuses, [ChatConnectionStatus.connected]);
    });

    test('is joined again after SignalR reconnects, before it says so', () async {
      await client().connect();
      final hub = server.hubs.single;

      // A reconnect is a new connection id, which is in no group at all.
      final held = Completer<void>();
      hub.holdInvoke = held;
      hub.reconnect();
      await _settle();
      expect(hub.invoked, ['JoinTrainerGroup', 'JoinTrainerGroup']);
      // Whatever reads again because it came back must read with the events
      // already flowing, so nobody hears about it until the join is done.
      expect(statuses.last, ChatConnectionStatus.reconnecting);
      expect(reconnects, 0);

      held.complete();
      await _settle();
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
      // Chat replays its outbox on this; the console reads again on the
      // status coming back.
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
