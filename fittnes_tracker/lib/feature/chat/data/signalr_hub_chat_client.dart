import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:signalr_hub/signalr_client.dart';

import 'package:ForgeForm/core/network/secure_token_storage.dart';
import 'package:ForgeForm/feature/auth/presentation/providers/auth_provider.dart'
    show serverUrlDefault;
import 'package:ForgeForm/feature/chat/data/chat_signalr_client.dart';
import 'package:ForgeForm/feature/chat/domain/models/chat_message.dart';

/// [ChatSignalRClient] over the `signalr_hub` package.
///
/// The package choice is load-bearing and worth recording: the more popular
/// `signalr_netcore` imports `dart:io` unconditionally in its WebSocket
/// transport, so it cannot compile for web — and the Trainer Console is
/// delivered as a web app. `signalr_hub` conditional-imports its transport
/// (`dart.library.js_interop` vs `dart.library.io`), which is what makes one
/// codebase work in a browser and on a phone.
///
/// Everything below is protocol plumbing. The outbox, replay and dedup rules
/// live in ChatRepository — see chat-flutter-roadmap.md §3.
class SignalRHubChatClient implements ChatSignalRClient {
  final String baseUrl;

  /// Whether each connection joins the calling trainer's live-updates group
  /// (`JoinTrainerGroup`), so it hears `ClientDataChanged`. True only for the
  /// Trainer Console's socket: a trainer's own trainee-app connection must not
  /// receive every client's events just to ignore them.
  ///
  /// A group is joined per connection id, and every connect gets a new one —
  /// the first, SignalR's own automatic reconnect, and a fresh start after a
  /// close — so it is joined again after each. See
  /// `docs/sync-architecture.md`, part four.
  final bool joinTrainerGroup;

  final HubConnection Function(String url, AccessTokenFactory accessToken)
  _buildConnection;
  final Duration Function(int attempt) _restartDelay;
  final Logger _logger = Logger();

  HubConnection? _connection;

  /// The in-flight [connect] call, so the fire-and-forget call sites and the
  /// first `joinGroup`/`send` converge on one handshake instead of racing it.
  /// Cleared on failure so a later attempt can start a fresh one.
  Future<void>? _connecting;

  /// The next fresh start, while the connection is down and nobody has asked
  /// for it yet — see [_scheduleRestart].
  Timer? _restartTimer;
  int _restartAttempt = 0;

  /// Set when a connection closes or a start fails, so the next start that
  /// succeeds is reported as a reconnect: whatever was sent meanwhile went to
  /// nobody, and whoever listens has to catch up.
  bool _lostConnection = false;

  /// Bumped by [disconnect], so a start still in flight when it was called
  /// knows it has been let go of.
  int _generation = 0;

  /// Set by [disconnect] and cleared by [connect]: a connection closed on
  /// purpose is not started again behind the caller's back.
  bool _stopped = false;

  final _incoming = StreamController<ChatMessage>.broadcast();
  final _reconnected = StreamController<void>.broadcast();
  final _status = StreamController<ChatConnectionStatus>.broadcast();
  final _clientDataChanged =
      StreamController<Map<String, dynamic>>.broadcast();

  SignalRHubChatClient({
    String? baseUrl,
    this.joinTrainerGroup = false,
    @visibleForTesting
    HubConnection Function(String url, AccessTokenFactory accessToken)?
    buildConnection,
    @visibleForTesting Duration Function(int attempt)? restartDelay,
  }) : baseUrl = baseUrl ?? serverUrlDefault,
       _buildConnection = buildConnection ?? _buildHubConnection,
       _restartDelay = restartDelay ?? restartDelayFor;

  /// How long to wait before the [attempt]th fresh start (counted from 0)
  /// after the connection closed for good: 5 s, then doubling, capped at a
  /// minute.
  ///
  /// It starts where SignalR's own automatic reconnect leaves off — that one
  /// tries at 0, 2, 10 and 30 s and then closes — and the cap keeps a console
  /// left open through a long outage at one handshake a minute.
  static Duration restartDelayFor(int attempt) =>
      Duration(seconds: math.min(60, 5 * (1 << math.min(attempt, 4))));

  static HubConnection _buildHubConnection(
    String url,
    AccessTokenFactory accessToken,
  ) => HubConnectionBuilder()
      .withUrl(
        url,
        options: HttpConnectionOptions(accessTokenFactory: accessToken),
      )
      .withAutomaticReconnect()
      .build();

  /// `Program.cs` lifts the JWT off `?access_token=` for `/hubs/chat` because a
  /// browser WebSocket handshake cannot carry an Authorization header. The
  /// package calls this factory per connection *and* per reconnect, so a token
  /// refreshed in between is picked up without rebuilding anything.
  Future<String> _accessToken() async =>
      await SecureTokenStorage.getToken() ?? '';

  /// Opens the connection, or joins the one already being opened.
  ///
  /// Callers may fire this and forget it — both surfaces do, so the console can
  /// paint its roster while the socket comes up. That is only safe because every
  /// method that needs the connection awaits [_ready] first, so "connect hasn't
  /// finished yet" is a wait rather than a failure.
  ///
  /// A call made while a fresh start is waiting out its backoff starts it now:
  /// someone needs the connection, and the wait was only there so a server
  /// that is down isn't asked every second.
  @override
  Future<void> connect() {
    _stopped = false;
    if (_connection != null) return Future<void>.value();
    _restartTimer?.cancel();
    _restartTimer = null;
    // The cached future is the `whenComplete` chain, not `_openConnection()`'s
    // own: clearing the field from inside that method's `finally` would run
    // before `??=` had stored it if it ever threw ahead of its first await,
    // leaving a permanently-failed future cached in its place.
    return _connecting ??= _openConnection().whenComplete(
      () => _connecting = null,
    );
  }

  Future<void> _openConnection() async {
    final generation = _generation;
    final connection = _buildConnection(
      '${baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'}hubs/chat',
      _accessToken,
    );

    connection.on('ReceiveMessage', _onReceiveMessage);
    connection.on('ClientDataChanged', _onClientDataChanged);

    connection.onreconnecting(({Object? error}) {
      _emitStatus(ChatConnectionStatus.reconnecting);
    });

    // SignalR's own reconnect: the same object, but a new connection id, and
    // so none of the groups the old one was in.
    connection.onreconnected(({String? connectionId}) {
      unawaited(_cameBack(connection));
    });

    connection.onclose(({Object? error}) => _onClosed(connection));

    try {
      // Assigned only once the handshake has actually succeeded. Setting it
      // first left a failed start() behind a non-null field that connect()'s
      // own guard then refused to rebuild, so one bad token or CORS response
      // killed chat for the lifetime of the widget with nothing on screen to
      // say why.
      await connection.start();
    } catch (_) {
      if (generation == _generation) {
        _lostConnection = true;
        _emitStatus(ChatConnectionStatus.disconnected);
        _scheduleRestart();
      }
      rethrow;
    }

    // Let go of by disconnect() while it was starting.
    if (generation != _generation) {
      unawaited(connection.stop());
      return;
    }
    _connection = connection;
    _restartAttempt = 0;
    if (_lostConnection) {
      _lostConnection = false;
      await _cameBack(connection);
    } else {
      await _joinGroups(connection);
      if (identical(_connection, connection)) {
        _emitStatus(ChatConnectionStatus.connected);
      }
    }
  }

  /// A connection up again after a gap in which events were sent to nobody —
  /// SignalR's own reconnect, or a fresh start after a close.
  ///
  /// The groups are joined before anyone hears it is back, so whatever reads
  /// again *because* it came back reads with the events already flowing.
  Future<void> _cameBack(HubConnection connection) async {
    await _joinGroups(connection);
    if (!identical(_connection, connection)) return;
    _emitStatus(ChatConnectionStatus.connected);
    // The signal ChatRepository replays the outbox on. Emitted after the
    // status so a listener that reacts to both sees a live connection first.
    if (!_reconnected.isClosed) _reconnected.add(null);
  }

  Future<void> _joinGroups(HubConnection connection) async {
    if (!joinTrainerGroup) return;
    try {
      await connection.invoke('JoinTrainerGroup');
    } catch (e, stackTrace) {
      // Chat works without it, and the console still reads again on focus and
      // on reconnect, so a failed join costs live updates, not the socket.
      _logger.w(
        'JoinTrainerGroup failed; live updates wait for the next reconnect',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// SignalR's automatic reconnect gave up, or the connection closed under us.
  ///
  /// This used to leave the dead connection in [_connection], so [connect]
  /// returned early for the rest of the session and nothing — no chat send,
  /// no `ClientDataChanged` — reached this device again. A close asked for by
  /// [disconnect] has already let go of the connection, and is ignored here.
  void _onClosed(HubConnection connection) {
    if (!identical(_connection, connection)) return;
    _connection = null;
    _lostConnection = true;
    _emitStatus(ChatConnectionStatus.disconnected);
    _scheduleRestart();
  }

  /// Starts afresh after [restartDelayFor], unless something asks sooner.
  void _scheduleRestart() {
    if (_stopped || _restartTimer != null || _status.isClosed) return;
    _restartTimer = Timer(_restartDelay(_restartAttempt++), () {
      _restartTimer = null;
      // A failure schedules the next attempt itself.
      unawaited(connect().catchError((Object _) {}));
    });
  }

  void _emitStatus(ChatConnectionStatus status) {
    if (!_status.isClosed) _status.add(status);
  }

  /// Closes the connection and stops any fresh start from being scheduled,
  /// until the next [connect].
  @override
  Future<void> disconnect() async {
    _stopped = true;
    _generation++;
    _restartTimer?.cancel();
    _restartTimer = null;
    final connection = _connection;
    _connection = null;
    _connecting = null;
    if (connection == null) return;
    await connection.stop();
    _emitStatus(ChatConnectionStatus.disconnected);
  }

  @override
  Future<void> joinGroup(String otherPartyId) async {
    await (await _ready()).invoke('JoinClientGroup', args: [otherPartyId]);
  }

  @override
  Future<void> leaveGroup(String otherPartyId) async {
    await (await _ready()).invoke('LeaveClientChat', args: [otherPartyId]);
  }

  @override
  Future<ChatMessage> send({
    required String otherPartyId,
    required String messageId,
    required String body,
    required String? iv,
    required int encryptionVersion,
    List<String>? attachmentIds,
  }) async {
    // Positional order is the hub's, not this method's:
    // SendMessageV2(Guid clientId, string body, Guid messageId, string? iv,
    //               int encryptionVersion, IReadOnlyList<Guid>? attachmentIds).
    //
    // SignalR matches these by position and nothing checks the names, so a
    // reordering here is a runtime type error at best and a message stored with
    // its IV in the body at worst. Always SendMessageV2, never the original
    // 5-argument SendMessage — that method still exists only so an
    // already-shipped build with no knowledge of attachments keeps working;
    // this client always knows, so it always uses the current RPC.
    final ack = await (await _ready()).invoke(
      'SendMessageV2',
      args: [
        otherPartyId,
        body,
        messageId,
        iv,
        encryptionVersion,
        attachmentIds,
      ],
    );

    if (ack == null) {
      throw StateError('SendMessageV2 returned no acknowledgement.');
    }
    return ChatMessage.fromJson(_asJson(ack));
  }

  @override
  Stream<ChatMessage> get incomingMessages => _incoming.stream;

  @override
  Stream<void> get onReconnected => _reconnected.stream;

  @override
  Stream<ChatConnectionStatus> get connectionStatus => _status.stream;

  /// The hub's `ClientDataChanged` events, as sent: `{clientId, areas}`.
  ///
  /// Not chat, and so not on [ChatSignalRClient]. It rides this connection
  /// because the Trainer Console already holds it open for as long as the
  /// console is open, and a second socket for a few bytes an hour would double
  /// what the console keeps open against the API. Left as JSON: the console
  /// owns what the event means (`ClientDataChange`), and this layer only
  /// carries it. Only a connection made with [joinTrainerGroup] receives any.
  /// See `docs/sync-architecture.md`, part four.
  Stream<Map<String, dynamic>> get clientDataChanges =>
      _clientDataChanged.stream;

  void _onReceiveMessage(List<Object?>? arguments) {
    final payload = arguments?.isNotEmpty == true ? arguments!.first : null;
    if (payload == null) return;
    _incoming.add(ChatMessage.fromJson(_asJson(payload)));
  }

  void _onClientDataChanged(List<Object?>? arguments) {
    final payload = arguments?.isNotEmpty == true ? arguments!.first : null;
    if (payload is! Map) return;
    _clientDataChanged.add(_asJson(payload));
  }

  /// The JSON hub protocol hands back plain decoded JSON, which arrives as a
  /// `Map` of uncertain generic type depending on how it was decoded — copying
  /// it into a `Map<String, dynamic>` avoids a cast error at the call site.
  static Map<String, dynamic> _asJson(Object value) =>
      Map<String, dynamic>.from(value as Map);

  /// The connection, opening one or waiting for one already opening.
  ///
  /// Both call sites start the socket with `unawaited(connect())` so the rest of
  /// the screen can render, which used to mean the first tap on a conversation
  /// raced the handshake and threw. Awaiting it here turns that race into a short
  /// wait.
  ///
  /// It doubles as the reconnect path: a failed attempt leaves both fields null,
  /// so the retry action in the thread's error state opens a fresh socket rather
  /// than hitting the same dead object again. A connect that fails throws its own
  /// error, not a generic "call connect() first" that says nothing about why.
  Future<HubConnection> _ready() async {
    await connect();

    final connection = _connection;
    if (connection == null) {
      throw StateError('The chat connection is not available.');
    }
    return connection;
  }

  Future<void> dispose() async {
    await disconnect();
    await _incoming.close();
    await _reconnected.close();
    await _status.close();
    await _clientDataChanged.close();
  }
}
