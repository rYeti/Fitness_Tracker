import 'package:ForgeForm/core/di/service_locator.dart';
import 'package:ForgeForm/core/network/api_client.dart';

/// Thin wrapper over `api/Chat` — matches `TrainerConsoleApi`'s pattern
/// (raw JSON in, no domain mapping). Backend contract, see
/// FitTracker.Api/Controllers/ChatController.cs:
///   GET  api/chat/{otherPartyId}/history?range={n} -> `List<ChatMessageDto>`
///   GET  api/chat/conversations                   -> `List<ChatConversationDto>`
///   POST api/chat/{otherPartyId}/read             -> 204
///
/// `otherPartyId` is whoever is on the far side of the thread: a client's id
/// when a trainer calls, the trainer's id when the client does. The controller
/// resolves which side the caller is on, so one set of routes serves both.
class ChatApi {
  final ApiClient _client;

  ChatApi({ApiClient? client})
    : _client = client ?? sl<ApiClient>(instanceName: backendApiClient);

  Future<List<Map<String, dynamic>>> fetchHistory(
    String otherPartyId, {
    int range = 50,
  }) async {
    final response = await _client.get(
      'api/chat/$otherPartyId/history',
      queryParameters: {'range': range},
    );
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchConversations() async {
    final response = await _client.get('api/chat/conversations');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<void> markRead(String otherPartyId) async {
    await _client.post('api/chat/$otherPartyId/read');
  }
}
