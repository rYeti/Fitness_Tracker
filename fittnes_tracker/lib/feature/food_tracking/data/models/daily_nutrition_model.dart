// lib/feature/food_tracking/data/models/daily_nutrition.dart
class DailyNutrition {
  DateTime date;
  int totalCalories;
  int totalProtein;
  int totalCarbs;
  int totalFat;
  Map<String, List<String>> meals; // Category -> List of serialized food items

  DailyNutrition({
    required this.date,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.meals,
  });

  factory DailyNutrition.empty(DateTime date) {
    return DailyNutrition(
      date: date,
      totalCalories: 0,
      totalProtein: 0,
      totalCarbs: 0,
      totalFat: 0,
      meals: {'Breakfast': [], 'Lunch': [], 'Dinner': [], 'Snacks': []},
    );
  }

  // Create a copy with updated values
  DailyNutrition copyWith({
    DateTime? date,
    int? totalCalories,
    int? totalProtein,
    int? totalCarbs,
    int? totalFat,
    Map<String, List<String>>? meals,
  }) {
    return DailyNutrition(
      date: date ?? this.date,
      totalCalories: totalCalories ?? this.totalCalories,
      totalProtein: totalProtein ?? this.totalProtein,
      totalCarbs: totalCarbs ?? this.totalCarbs,
      totalFat: totalFat ?? this.totalFat,
      meals: meals ?? this.meals,
    );
  }
}
