import 'package:ForgeForm/core/nutrition/extended_nutrients.dart';

class MealTemplate {
  final int? id;
  final String name;
  final String? description;
  final String category; // Breakfast, Lunch, Dinner, Snack, etc.
  final List<MealTemplateItem> items;
  final double? totalWeightGrams;

  MealTemplate({
    this.id,
    required this.name,
    this.description = '',
    required this.category,
    required this.items,
    this.totalWeightGrams,
  });

  double get totalCalories => items.fold(0, (sum, item) => sum + item.calories);
  double get totalProtein => items.fold(0, (sum, item) => sum + item.protein);
  double get totalCarbs => items.fold(0, (sum, item) => sum + item.carbs);
  double get totalFat => items.fold(0, (sum, item) => sum + item.fat);

  /// The template's micronutrients: a null-preserving sum across its items,
  /// exactly like the macro totals above. An item nobody has micronutrients
  /// for contributes [ExtendedNutrients.empty], so a template of such items
  /// totals to all-null — "no data", never a reported zero. See
  /// `docs/trainer-console-micronutrients.md`.
  ExtendedNutrients get totalMicronutrients => ExtendedNutrients.sum(
        items.map((item) => item.extendedNutrients ?? ExtendedNutrients.empty),
      );

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description ?? '',
      'category': category,
      if (totalWeightGrams != null) 'total_weight_grams': totalWeightGrams,
    };
  }

  factory MealTemplate.fromMap(
    Map<String, dynamic> map,
    List<MealTemplateItem> items,
  ) {
    return MealTemplate(
      id: map['id'],
      name: map['name'],
      description: map['description'] ?? '',
      category: map['category'],
      items: items,
      totalWeightGrams: (map['total_weight_grams'] as num?)?.toDouble(),
    );
  }
}

class MealTemplateItem {
  final int? id;
  final int templateId;
  final int foodId;
  final String foodName;
  final double quantity;
  final String unit;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  /// This item's micronutrients, already scaled to [quantity] — the same
  /// basis its macros are stored on. Null when the food carried none, which
  /// stays distinct from "measured as zero" through every fold.
  final ExtendedNutrients? extendedNutrients;

  MealTemplateItem({
    this.id,
    required this.templateId,
    required this.foodId,
    required this.foodName,
    required this.quantity,
    required this.unit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.extendedNutrients,
  });

  // Backwards compatibility
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'template_id': templateId,
      'food_id': foodId,
      'food_name': foodName,
      'quantity': quantity,
      'unit': unit,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'extendedNutrientsJson': extendedNutrients?.toJsonString(),
    };
  }

  factory MealTemplateItem.fromMap(Map<String, dynamic> map) {
    return MealTemplateItem(
      id: map['id'],
      templateId: map['template_id'],
      foodId: map['food_id'],
      foodName: map['food_name'],
      quantity: map['quantity'],
      unit: map['unit'],
      calories: map['calories'],
      protein: map['protein'],
      carbs: map['carbs'],
      fat: map['fat'],
      extendedNutrients: parseTemplateItemNutrients(map),
    );
  }
}

/// Reads an item map's micronutrient blob, tolerating both key spellings.
///
/// Item maps reach this from three writers that never agreed on a
/// convention: `MealTemplateRepository` writes camelCase, the legacy
/// [MealTemplateItem.toMap] writes snake_case for its macros, and
/// `SyncService._pullMealTemplates` writes whatever the API returned. A blob
/// that fails to parse is treated as absent rather than thrown, so one bad
/// template item costs its micronutrients and not the whole template.
ExtendedNutrients? parseTemplateItemNutrients(Map<String, dynamic> map) {
  final json = (map['extendedNutrientsJson'] ?? map['extended_nutrients_json'])
      as String?;
  if (json == null || json.isEmpty) return null;
  try {
    return ExtendedNutrients.fromJsonString(json);
  } catch (_) {
    return null;
  }
}
