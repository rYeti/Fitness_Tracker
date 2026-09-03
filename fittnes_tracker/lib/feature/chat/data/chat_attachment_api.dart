import 'package:ForgeForm/core/di/service_locator.dart';
import 'package:ForgeForm/core/network/api_client.dart';
import 'package:ForgeForm/core/providers/enums.dart';

/// Mints presigned URLs for attachment blobs — matches
/// `FitTracker.Api/Controllers/ChatAttachmentController.cs`:
///   GET  api/chat/attachments/capabilities            -> capabilities
///   POST api/chat/{otherPartyId}/attachments           -> mint upload
///   GET  api/chat/attachments/{attachmentId}/url       -> mint download
///
/// Deliberately thin, like `ChatApi` — raw JSON in, no domain mapping.
/// **Never used for the PUT/GET of the ciphertext itself** — the mint
/// responses hand back absolute URLs to R2 (or the local dev store), and
/// those calls go through a bare `Dio`, not this class or the shared
/// `ApiClient`. See `ChatAttachmentTransfer`'s own doc comment for why.
class ChatAttachmentApi {
  final ApiClient _client;

  ChatAttachmentApi({ApiClient? client})
    : _client = client ?? sl<ApiClient>(instanceName: backendApiClient);

  Future<Map<String, dynamic>> fetchCapabilities() async {
    final response = await _client.get('api/chat/attachments/capabilities');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> mintUpload({
    required String otherPartyId,
    required String attachmentId,
    required int byteLength,
    required MediaType kind,
  }) async {
    final response = await _client.post(
      'api/chat/$otherPartyId/attachments',
      data: {
        'attachmentId': attachmentId,
        'byteLength': byteLength,
        'kind': kind.index,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> mintDownload(String attachmentId) async {
    final response = await _client.get('api/chat/attachments/$attachmentId/url');
    return response.data as Map<String, dynamic>;
  }
}
