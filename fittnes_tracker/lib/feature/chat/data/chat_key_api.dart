import 'package:dio/dio.dart';

import 'package:ForgeForm/core/di/service_locator.dart';
import 'package:ForgeForm/core/network/api_client.dart';

/// One device's published public key, exactly as the server holds it.
typedef DeviceKeyEntry = ({String deviceId, String publicKeyJwk});

/// Thin wrapper over `api/chat/keys` — same shape as `ChatApi`, raw JSON in and
/// out, no domain mapping.
///
/// Backend contract, see FitTracker.Api/Controllers/ChatKeyController.cs:
///   GET api/chat/keys/me                -> { userId, devices: [{deviceId, publicKeyJwk}] }
///   PUT api/chat/keys/me                -> { userId }
///   GET api/chat/keys/{otherPartyId}    -> { userId, devices: [...] } | 404
///
/// The `me` GET exists because this client has no user id of its own — see
/// docs/chat-architecture.md §5. The key store needs one to tell "my key" from
/// "the key of whoever was signed in on this device last", and asking is the
/// only way to get it.
///
/// One row per device rather than per user — see docs/chat-encryption.md for
/// why a second device used to silently destroy a user's own message history,
/// and why registering one is additive now.
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

  /// The caller's own id, and every device they have published a key from.
  Future<Map<String, dynamic>> fetchMe() async {
    final response = await _client.get('api/chat/keys/me');
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Publishes this device's public key. Additive: another device's row is
  /// never touched. Returns the caller's id.
  Future<String> publish(String deviceId, String publicKeyJwk) async {
    final response = await _client.put(
      'api/chat/keys/me',
      data: {'deviceId': deviceId, 'publicKeyJwk': publicKeyJwk},
    );
    return (response.data as Map)['userId'] as String;
  }

  /// The other party's registered devices, or null if they have none — which is
  /// a real state, not an error: they have simply not opened the app since
  /// this shipped.
  Future<List<DeviceKeyEntry>?> fetchPeer(String otherPartyId) async {
    try {
      final response = await _client.get('api/chat/keys/$otherPartyId');
      return devicesOf(response.data);
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

  /// Parses the `devices` array out of an `me` or peer response. Shared with
  /// [ChatKeyStore], which reads it off `fetchMe()`'s raw json to fan out to
  /// this account's own other devices.
  static List<DeviceKeyEntry> devicesOf(Object? data) {
    if (data is! Map) return const [];
    final devices = data['devices'];
    if (devices is! List) return const [];
    return devices
        .whereType<Map>()
        .map(
          (d) => (
            deviceId: d['deviceId'] as String,
            publicKeyJwk: d['publicKeyJwk'] as String,
          ),
        )
        .toList();
  }
}
