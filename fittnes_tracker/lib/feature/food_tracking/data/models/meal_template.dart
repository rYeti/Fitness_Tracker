class MealTemplate {
  final int? id;
  final String name;
  final String? description;
  final String category; // Breakfast, Lunch, Dinner, Snack, etc.
  final List<MealTemplateItem> items;

  MealTemplate({
    this.id,
    required this.name,
    this.description = '',
    required this.category,
    required this.items,
  });

  // Add methods for calculating total calories, macros, etc.
  double get totalCalories => items.fold(0, (sum, item) => sum + item.calories);

  // Backwards compatibility
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description ?? '',
      'category': category,
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
    );
  }
}
