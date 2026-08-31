import 'package:dio/dio.dart';

import 'package:ForgeForm/core/di/service_locator.dart';
import 'package:ForgeForm/core/network/api_client.dart';

/// Thin wrapper over `api/chat/keys` — same shape as `ChatApi`, raw JSON in and
/// out, no domain mapping.
///
/// Backend contract, see FitTracker.Api/Controllers/ChatKeyController.cs:
///   GET api/chat/keys/me                -> { userId, publicKeyJwk? }
///   PUT api/chat/keys/me                -> { userId }
///   GET api/chat/keys/{otherPartyId}    -> { userId, publicKeyJwk } | 404
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

  /// The caller's own id, and their currently published key if they have one.
  Future<Map<String, dynamic>> fetchMe() async {
    final response = await _client.get('api/chat/keys/me');
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Publishes this device's public key, replacing any previous one. Returns
  /// the caller's id.
  Future<String> publish(String publicKeyJwk) async {
    final response = await _client.put(
      'api/chat/keys/me',
      data: {'publicKeyJwk': publicKeyJwk},
    );
    return (response.data as Map)['userId'] as String;
  }

  /// The other party's published key, or null if they have never registered
  /// one — which is a real state, not an error: they have simply not opened the
  /// app since this shipped.
  Future<String?> fetchPeer(String otherPartyId) async {
    try {
      final response = await _client.get('api/chat/keys/$otherPartyId');
      final data = response.data;
      if (data is! Map) return null;
      return data['publicKeyJwk'] as String?;
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
