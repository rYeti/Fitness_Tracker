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

  final _incoming = StreamController<ChatMessage>.broadcast();
  final _reconnected = StreamController<void>.broadcast();
  final _status = StreamController<ChatConnectionStatus>.broadcast();

  SignalRHubChatClient({String? baseUrl}) : baseUrl = baseUrl ?? serverUrlDefault;

  /// `Program.cs` lifts the JWT off `?access_token=` for `/hubs/chat` because a
  /// browser WebSocket handshake cannot carry an Authorization header. The
  /// package calls this factory per connection *and* per reconnect, so a token
  /// refreshed in between is picked up without rebuilding anything.
  Future<String> _accessToken() async =>
      await SecureTokenStorage.getToken() ?? '';

  @override
  Future<void> connect() async {
    if (_connection != null) return;

    final connection = HubConnectionBuilder()
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

    _connection = connection;
    await connection.start();
    _status.add(ChatConnectionStatus.connected);
  }

  @override
  Future<void> disconnect() async {
    final connection = _connection;
    _connection = null;
    if (connection == null) return;
    await connection.stop();
    _status.add(ChatConnectionStatus.disconnected);
  }

  @override
  Future<void> joinGroup(String otherPartyId) async {
    await _require().invoke('JoinClientGroup', args: [otherPartyId]);
  }

  @override
  Future<void> leaveGroup(String otherPartyId) async {
    await _require().invoke('LeaveClientChat', args: [otherPartyId]);
  }

  @override
  Future<ChatMessage> send({
    required String otherPartyId,
    required String messageId,
    required String body,
  }) async {
    // Positional order is the hub's, not this method's:
    // SendMessage(Guid clientId, string body, Guid messageId).
    final ack = await _require().invoke(
      'SendMessage',
      args: [otherPartyId, body, messageId],
    );

    if (ack == null) {
      throw StateError('SendMessage returned no acknowledgement.');
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

  HubConnection _require() {
    final connection = _connection;
    if (connection == null) {
      throw StateError('connect() must be called before using the chat hub.');
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
