import 'package:ForgeForm/core/di/service_locator.dart';
import 'package:ForgeForm/core/network/api_client.dart';

/// The nutrient keys the caller's trainer has pinned for them to track,
/// read-only — the trainee side of the Trainer Console's "Tracked nutrients"
/// picker. See docs/trainer-console-micronutrients.md.
class NutrientPinsApi {
  final ApiClient _client;

  NutrientPinsApi({ApiClient? client})
    : _client = client ?? sl<ApiClient>(instanceName: backendApiClient);

  /// Defaults (fibre/sugar/sodium) for a caller with no active trainer, or
  /// whose trainer never chose — the server applies that default, not this
  /// client.
  Future<List<String>> fetchMyPins() async {
    final response = await _client.get('api/TrainerClient/my-nutrient-pins');
    return (response.data as List).cast<String>();
  }
}
