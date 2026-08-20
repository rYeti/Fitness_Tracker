import 'package:ForgeForm/core/di/service_locator.dart';
import 'package:ForgeForm/core/network/api_client.dart';

/// Thin wrapper over `api/Chat` — matches `TrainerConsoleApi`'s pattern
/// (raw JSON in, no domain mapping). Backend contract (already shipped, see
/// FitTracker.Api/Controllers/ChatController.cs):
///   GET api/chat/{clientId}/history?range={n} -> List<ChatMessageDto>
/// `clientId` here is always the client side of the pair; the controller
/// resolves whether the caller is the trainer or the client itself.
class ChatApi {
  final ApiClient _client;

  ChatApi({ApiClient? client}) : _client = client ?? sl<ApiClient>();

  Future<List<Map<String, dynamic>>> fetchHistory(String clientId, {int range = 50}) async {
    final response = await _client.get(
      'api/chat/$clientId/history',
      queryParameters: {'range': range},
    );
    return (response.data as List).cast<Map<String, dynamic>>();
  }
}
