import 'package:ForgeForm/core/app_database.dart';
import 'package:get_it/get_it.dart';
import '../network/api_client.dart';
import '../../feature/food_tracking/data/data_sources/food_api.dart';
// Note: AppDatabase and scheduled workout provider registration removed to
// preserve previous runtime behaviour. Add back when DB migration is verified.

final sl = GetIt.instance;

void setupLocator() {
  sl.registerLazySingleton(
    () => ApiClient(baseUrl: 'https://world.openfoodfacts.org/api/v2/'),
  );
  sl.registerLazySingleton(() => FoodApi(sl<ApiClient>()));
  // Database will be registered after creation in main.dart
}

void registerDatabase(AppDatabase database) {
  sl.registerSingleton<AppDatabase>(database);
}
