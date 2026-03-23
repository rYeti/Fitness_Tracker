import '../../../../core/network/api_client.dart';
import '../models/food_item_model.dart';

class FoodApi {
  final ApiClient apiClient;

  FoodApi(this.apiClient);

  Future<FoodItemModel> fetchFoodByBarcode(String barcode) async {
    final response = await apiClient.get(
      'https://world.openfoodfacts.org/api/v0/product/$barcode.json',
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch food item');
    }
    final product = response.data['product'];
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.round();
      if (value is String) {
        return int.tryParse(value) ?? double.tryParse(value)?.round() ?? 0;
      }
      return 0;
    }

    final nutriments = product['nutriments'] ?? {};
    return FoodItemModel(
      id: parseInt(product['id']),
      name: product['product_name'] ?? product['brands'] ?? 'Unknown',
      calories: parseInt(nutriments['energy-kcal']),
      protein: parseInt(nutriments['proteins_100g']),
      carbs: parseInt(nutriments['carbohydrates_100g']),
      fat: parseInt(nutriments['fat_100g']),
      gramm: 100, // Default to 100g if not present
    );
  }
}
