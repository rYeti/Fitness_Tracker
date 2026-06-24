import 'package:dio/dio.dart';
import '../models/extended_nutrients.dart';
import '../models/food_item_model.dart';
import '../models/portion_option.dart';

class BarcodeResult {
  final FoodItemModel food;
  final List<PortionOption> portionOptions;
  const BarcodeResult(this.food, this.portionOptions);
}

class FoodApi {
  final Dio _dio = Dio(
    BaseOptions(
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        // OpenFoodFacts rejects requests without an identifying User-Agent (403).
        // Do NOT use ApiClient here — its auth interceptor would attach a Bearer
        // token which also causes OpenFoodFacts to return 403.
        'User-Agent': 'ForgeForm - Android - 1.0 - yetitime69@gmail.com',
      },
    ),
  );

  Future<BarcodeResult> fetchFoodByBarcode(String barcode) async {
    const maxAttempts = 3;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await _dio.get(
          'https://world.openfoodfacts.org/api/v0/product/$barcode.json',
        );

        if (response.statusCode != 200) {
          throw Exception('Failed to fetch food item');
        }

        final product = response.data['product'] as Map<String, dynamic>? ?? {};

        int parseInt(dynamic value) {
          if (value == null) return 0;
          if (value is int) return value;
          if (value is double) return value.round();
          if (value is String) {
            return int.tryParse(value) ?? double.tryParse(value)?.round() ?? 0;
          }
          return 0;
        }

        final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};
        final extended = ExtendedNutrients.fromNutriments(nutriments);
        final food = FoodItemModel(
          id: parseInt(product['id']),
          openFoodFactsId: barcode,
          name: product['product_name'] ?? product['brands'] ?? 'Unknown',
          calories: parseInt(nutriments['energy-kcal']),
          protein: parseInt(nutriments['proteins_100g']),
          carbs: parseInt(nutriments['carbohydrates_100g']),
          fat: parseInt(nutriments['fat_100g']),
          gramm: 100,
          extendedNutrients: extended.hasAnyData ? extended : null,
        );

        // Pass the raw product map so PortionOption can extract serving sizes.
        final portions = PortionOption.fromProductData(product);

        return BarcodeResult(food, portions);
      } on DioException catch (e) {
        if (e.response?.statusCode == 429 && attempt < maxAttempts) {
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }
        rethrow;
      }
    }

    throw Exception('Failed to fetch food item after $maxAttempts attempts');
  }
}
