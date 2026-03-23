import 'package:ForgeForm/core/app_database.dart';
import 'package:drift/drift.dart';

class FoodItemModel {
  final int? id;
  final String name;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final int gramm; // If you use gramm in your table

  FoodItemModel({
    this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.gramm,
  });

  // Convert from Drift's FoodItemData
  factory FoodItemModel.fromData(FoodItemData data) {
    return FoodItemModel(
      id: data.id,
      name: data.name,
      calories: data.calories,
      protein: data.protein,
      carbs: data.carbs,
      fat: data.fat,
      gramm: data.gramm,
    );
  }

  // Convert to Drift's FoodItemCompanion for inserts/updates
  FoodItemCompanion toCompanion() {
    return FoodItemCompanion(
      name: Value(name),
      calories: Value(calories),
      protein: Value(protein),
      carbs: Value(carbs),
      fat: Value(fat),
      gramm: Value(gramm),
    );
  }
}
