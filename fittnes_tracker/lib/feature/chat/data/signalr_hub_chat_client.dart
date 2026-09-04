import 'dart:async';

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

  HubConnection? _connection;

  /// The in-flight [connect] call, so the fire-and-forget call sites and the
  /// first `joinGroup`/`send` converge on one handshake instead of racing it.
  /// Cleared on failure so a later attempt can start a fresh one.
  Future<void>? _connecting;

  final _incoming = StreamController<ChatMessage>.broadcast();
  final _reconnected = StreamController<void>.broadcast();
  final _status = StreamController<ChatConnectionStatus>.broadcast();

  SignalRHubChatClient({String? baseUrl})
    : baseUrl = baseUrl ?? serverUrlDefault;

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
  @override
  Future<void> connect() {
    if (_connection != null) return Future<void>.value();
    // The cached future is the `whenComplete` chain, not `_openConnection()`'s
    // own: clearing the field from inside that method's `finally` would run
    // before `??=` had stored it if it ever threw ahead of its first await,
    // leaving a permanently-failed future cached in its place.
    return _connecting ??= _openConnection().whenComplete(
      () => _connecting = null,
    );
  }

  Future<void> _openConnection() async {
    final connection =
        HubConnectionBuilder()
            .withUrl(
              '${baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'}hubs/chat',
              options: HttpConnectionOptions(accessTokenFactory: _accessToken),
            )
            .withAutomaticReconnect()
            .build();

    connection.on('ReceiveMessage', _onReceiveMessage);

    connection.onreconnecting(({Object? error}) {
      _status.add(ChatConnectionStatus.reconnecting);
    });

    connection.onreconnected(({String? connectionId}) {
      _status.add(ChatConnectionStatus.connected);
      // The signal ChatRepository replays the outbox on. Emitted after the
      // status so a listener that reacts to both sees a live connection first.
      _reconnected.add(null);
    });

    connection.onclose(({Object? error}) {
      _status.add(ChatConnectionStatus.disconnected);
    });

    try {
      // Assigned only once the handshake has actually succeeded. Setting it
      // first left a failed start() behind a non-null field that connect()'s
      // own guard then refused to rebuild, so one bad token or CORS response
      // killed chat for the lifetime of the widget with nothing on screen to
      // say why.
      await connection.start();
      _connection = connection;
      _status.add(ChatConnectionStatus.connected);
    } catch (_) {
      _status.add(ChatConnectionStatus.disconnected);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    final connection = _connection;
    _connection = null;
    _connecting = null;
    if (connection == null) return;
    await connection.stop();
    _status.add(ChatConnectionStatus.disconnected);
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

  void _onReceiveMessage(List<Object?>? arguments) {
    final payload = arguments?.isNotEmpty == true ? arguments!.first : null;
    if (payload == null) return;
    _incoming.add(ChatMessage.fromJson(_asJson(payload)));
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
  }
}
