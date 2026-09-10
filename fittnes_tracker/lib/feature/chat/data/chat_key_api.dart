import 'package:dio/dio.dart';

import 'package:ForgeForm/core/di/service_locator.dart';
import 'package:ForgeForm/core/network/api_client.dart';

/// One device's published key, as `api/chat/keys` reports it inside a
/// `devices` list.
class ChatKeyDevice {
  final String deviceId;
  final String publicKeyJwk;

  const ChatKeyDevice({required this.deviceId, required this.publicKeyJwk});

  factory ChatKeyDevice.fromJson(Map<String, dynamic> json) => ChatKeyDevice(
    deviceId: json['deviceId'] as String,
    publicKeyJwk: json['publicKeyJwk'] as String,
  );

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'publicKeyJwk': publicKeyJwk,
  };
}

/// A user's full key response — the `userId`/`publicKeyJwk`/`devices` shape
/// both `me` and `{otherPartyId}` share. See docs/chat-multi-device-keys.md.
class ChatKeyResponse {
  final String userId;

  /// The most-recently-seen device's key. What this class carried before any
  /// device existed to distinguish — kept because `ChatKeyStore` still uses it
  /// for the "the server has lost every key" republish case, which needs no
  /// device-level detail.
  final String? publicKeyJwk;

  final List<ChatKeyDevice> devices;

  const ChatKeyResponse({
    required this.userId,
    required this.publicKeyJwk,
    required this.devices,
  });

  factory ChatKeyResponse.fromJson(Map<String, dynamic> json) {
    final devicesJson = json['devices'];
    return ChatKeyResponse(
      userId: json['userId'] as String,
      publicKeyJwk: json['publicKeyJwk'] as String?,
      devices:
          devicesJson is List
              ? [
                for (final entry in devicesJson)
                  if (entry is Map<String, dynamic>)
                    ChatKeyDevice.fromJson(entry),
              ]
              : const [],
    );
  }
}

/// Thin wrapper over `api/chat/keys` — same shape as `ChatApi`, raw JSON in and
/// out, no domain mapping.
///
/// Backend contract, see FitTracker.Api/Controllers/ChatKeyController.cs:
///   GET api/chat/keys/me                -> { userId, publicKeyJwk?, devices }
///   PUT api/chat/keys/me                -> { userId }
///   GET api/chat/keys/{otherPartyId}    -> { userId, publicKeyJwk, devices } | 404
///
/// The `me` GET exists because this client has no user id of its own — see
/// docs/chat-architecture.md §5. The key store needs one to tell "my key" from
/// "the key of whoever was signed in on this device last", and asking is the
/// only way to get it.
class ChatKeyApi {
  final ApiClient? _injected;

  ChatKeyApi({ApiClient? client}) : _injected = client;

  /// Resolved on use rather than in the constructor.
  ///
  /// `ChatKeyStore` is constructed eagerly by `ChatRepository`, including in
  /// tests that inject a fake `ChatCrypto` and never make a key request at all.
  /// Reaching for the service locator up front made merely *building* the
  /// repository depend on a registered `ApiClient`, which is a dependency none
  /// of those tests has or needs.
  ApiClient get _client =>
      _injected ?? sl<ApiClient>(instanceName: backendApiClient);

  /// The caller's own id, and every device it has currently published a key
  /// for.
  Future<ChatKeyResponse> fetchMe() async {
    final response = await _client.get('api/chat/keys/me');
    return ChatKeyResponse.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  /// Publishes [deviceId]'s public key, replacing that device's own previous
  /// key if it had one — never another device's. Returns the caller's id.
  Future<String> publish(String publicKeyJwk, {required String deviceId}) async {
    final response = await _client.put(
      'api/chat/keys/me',
      data: {'publicKeyJwk': publicKeyJwk, 'deviceId': deviceId},
    );
    return (response.data as Map)['userId'] as String;
  }

  /// The other party's published keys — one per device currently registered,
  /// or null if they have never published any, which is a real state, not an
  /// error: they have simply not opened the app since this shipped.
  Future<ChatKeyResponse?> fetchPeer(String otherPartyId) async {
    try {
      final response = await _client.get('api/chat/keys/$otherPartyId');
      final data = response.data;
      if (data is! Map) return null;
      return ChatKeyResponse.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      // Caught rather than propagated, because "they have no key" is the
      // ordinary state for anyone who has not opened the app since this
      // shipped -- not a failure the thread should show an error for. Every
      // other status still throws: a 401 is a real problem and hiding it here
      // would surface as messages that silently refuse to encrypt.
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
