import 'package:dio/dio.dart';

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

  /// The caller's plan, or null when the account isn't a trainer account.
  ///
  /// A pure read. It used to provision a Free licence on first call, which meant
  /// that merely opening the plan screen made the user a permanent trainer;
  /// licences are now created only when an account is registered as a trainer.
  Future<Map<String, dynamic>?> fetchMine() async {
    try {
      final response = await _client.get('api/TrainerLicence/me');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (_isNotATrainer(e)) return null;
      rethrow;
    }
  }

  /// True for the server's "this account isn't a trainer account" refusal, as
  /// opposed to a network failure or a genuine authorization problem.
  bool _isNotATrainer(DioException e) {
    if (e.response?.statusCode != 403) return false;
    final data = e.response?.data;
    return data is Map<String, dynamic> && data['error'] == 'not_a_trainer';
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
