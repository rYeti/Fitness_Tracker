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
  final ApiClient? _injected;

  ChatAttachmentApi({ApiClient? client}) : _injected = client;

  /// Resolved on use rather than in the constructor — the same seam
  /// `ChatKeyApi` already carries, for the same reason.
  ///
  /// `ChatAttachmentProvider` and `ChatAttachmentSender` both build one of
  /// these eagerly, and both are themselves built while a widget tree is
  /// coming up (`TrainerConsoleHome.initState`, `ChatRepository`'s factory).
  /// Reaching for the service locator here made merely *constructing* the
  /// console depend on a registered `ApiClient`, so a test that injects its
  /// own chat repository — and therefore needs no network at all — threw
  /// `Bad state: GetIt: ... ApiClient is not registered` before the first
  /// frame. Every call site already tolerates the lookup failing at call
  /// time: `ChatAttachmentSender.capabilities` collapses it to
  /// `ChatAttachmentCapabilities.disabled`, and `ChatAttachmentProvider.fetch`
  /// to a failed fetch.
  ApiClient get _client =>
      _injected ?? sl<ApiClient>(instanceName: backendApiClient);

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
    final response = await _client.get(
      'api/chat/attachments/$attachmentId/url',
    );
    return response.data as Map<String, dynamic>;
  }
}
