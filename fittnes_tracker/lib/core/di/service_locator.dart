import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/services/notification_service.dart';
import 'package:ForgeForm/core/services/push_service.dart';
import 'package:ForgeForm/feature/auth/presentation/providers/auth_provider.dart'
    show serverUrlDefault;
import 'package:get_it/get_it.dart';
import '../network/api_client.dart';
import '../../feature/food_tracking/data/data_sources/food_api.dart';
// Note: AppDatabase and scheduled workout provider registration removed to
// preserve previous runtime behaviour. Add back when DB migration is verified.

final sl = GetIt.instance;

/// Instance name for the [ApiClient] pointed at ForgeForm's own backend.
///
/// The *unnamed* [ApiClient] registration is the OpenFoodFacts food database,
/// not our API — resolving `sl<ApiClient>()` for a ForgeForm endpoint sends
/// the request to openfoodfacts.org. Always resolve this one for anything
/// under `api/`.
const backendApiClient = 'backendApiClient';

void setupLocator() {
  sl.registerLazySingleton(
    () => ApiClient(
      baseUrl: 'https://world.openfoodfacts.org/api/v2/',
      headers: const {
        'User-Agent': 'ForgeForm - Android - 1.0 - yetitime69@gmail.com',
      },
    ),
  );
  // main.dart writes serverUrlDefault back into prefs on every launch ("Always
  // apply the compile-time default so changing the IP in code takes effect
  // immediately"), so the compile-time constant is the effective base URL.
  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(baseUrl: serverUrlDefault),
    instanceName: backendApiClient,
  );
  sl.registerLazySingleton(() => FoodApi());
  sl.registerLazySingleton(() => NotificationService());
  sl.registerLazySingleton(() => PushService());
  // Database will be registered after creation in main.dart
}

void registerDatabase(AppDatabase database) {
  sl.registerSingleton<AppDatabase>(database);
}
