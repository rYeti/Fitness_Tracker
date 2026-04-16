import 'package:ForgeForm/core/app_database.dart';
import 'package:drift/drift.dart';
import 'extended_nutrients.dart';

class FoodItemModel {
  final int? id;
  final String name;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final int gramm;
  final ExtendedNutrients? extendedNutrients;

  FoodItemModel({
    this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.gramm,
    this.extendedNutrients,
  });

  factory FoodItemModel.fromData(FoodItemData data) {
    return FoodItemModel(
      id: data.id,
      name: data.name,
      calories: data.calories,
      protein: data.protein,
      carbs: data.carbs,
      fat: data.fat,
      gramm: data.gramm,
      extendedNutrients: data.extendedNutrientsJson != null
          ? ExtendedNutrients.fromJsonString(data.extendedNutrientsJson!)
          : null,
    );
  }

  FoodItemCompanion toCompanion() {
    return FoodItemCompanion(
      name: Value(name),
      calories: Value(calories),
      protein: Value(protein),
      carbs: Value(carbs),
      fat: Value(fat),
      gramm: Value(gramm),
      extendedNutrientsJson: Value(extendedNutrients?.toJsonString()),
    );
  }
}
