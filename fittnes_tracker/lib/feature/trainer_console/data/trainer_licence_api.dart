import 'package:ForgeForm/core/di/service_locator.dart';
import 'package:ForgeForm/core/network/api_client.dart';

/// Thin wrapper over `api/TrainerLicence` and the invite endpoints on
/// `api/TrainerClient` — raw JSON in, no domain mapping (that's
/// [TrainerLicenceRepository]'s job).
class TrainerLicenceApi {
  final ApiClient _client;

  // The unnamed ApiClient registration points at OpenFoodFacts. Every backend
  // call must use the named one.
  TrainerLicenceApi({ApiClient? client})
    : _client = client ?? sl<ApiClient>(instanceName: backendApiClient);

  /// The caller's plan. Provisioning a Free licence on first call is what turns
  /// a user into a trainer, so this doubles as "become a trainer".
  Future<Map<String, dynamic>> fetchMine() async {
    final response = await _client.get('api/TrainerLicence/me');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> becomeTrainer() async {
    final response = await _client.post('api/TrainerLicence/me', data: const {});
    return response.data as Map<String, dynamic>;
  }

  /// Returns the Stripe Checkout URL to send the trainer to.
  Future<String> createCheckoutSession(String tier) async {
    final response = await _client.post(
      'api/TrainerLicence/checkout-session',
      data: {'tier': tier},
    );
    return (response.data as Map<String, dynamic>)['url'] as String;
  }

  /// Returns the Stripe billing-portal URL.
  Future<String> createPortalSession() async {
    final response = await _client.post(
      'api/TrainerLicence/portal-session',
      data: const {},
    );
    return (response.data as Map<String, dynamic>)['url'] as String;
  }

  Future<Map<String, dynamic>> createInvite() async {
    final response = await _client.post('api/TrainerClient/invite', data: const {});
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchPendingInvites() async {
    final response = await _client.get('api/TrainerClient/invites');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<void> revokeInvite(String inviteId) =>
      _client.delete('api/TrainerClient/invite/$inviteId');

  Future<Map<String, dynamic>> joinTrainer(String inviteCode) async {
    final response = await _client.post(
      'api/TrainerClient/join/$inviteCode',
      data: const {},
    );
    return response.data as Map<String, dynamic>;
  }
}
