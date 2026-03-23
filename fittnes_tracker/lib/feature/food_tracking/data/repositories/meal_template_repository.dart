import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/dao/meal_template_dao.dart';
import '../models/meal_template.dart';

class MealTemplateRepository {
  final AppDatabase db;
  late final MealTemplateDao _mealTemplateDao;

  MealTemplateRepository(this.db) {
    _mealTemplateDao = MealTemplateDao(db);
  }

  // Create a new meal template
  Future<int> createMealTemplate(MealTemplate template) async {
    // Convert MealTemplate to Map
    final templateMap = {
      'name': template.name,
      'description': template.description ?? '',
      'category': template.category,
      'items': [],
    };

    // Insert the template and get the ID
    final templateId = await _mealTemplateDao.insertTemplate(templateMap);

    // Insert each item with the template ID
    for (var item in template.items) {
      final itemMap = {
        'templateId': templateId,
        'foodId': item.foodId,
        'foodName': item.foodName,
        'quantity': item.quantity,
        'unit': item.unit,
        'calories': item.calories,
        'protein': item.protein,
        'carbs': item.carbs,
        'fat': item.fat,
      };

      await _mealTemplateDao.insertTemplateItem(itemMap);
    }

    return templateId;
  }

  // Get all meal templates
  Future<List<MealTemplate>> getAllTemplates() async {
    final templateMaps = await _mealTemplateDao.getAllTemplates();
    return _convertToTemplates(templateMaps);
  }

  // Get templates by category
  Future<List<MealTemplate>> getTemplatesByCategory(String category) async {
    final templateMaps = await _mealTemplateDao.getTemplatesByCategory(
      category,
    );
    return _convertToTemplates(templateMaps);
  }

  // Get all items for a template
  Future<List<MealTemplateItem>> getTemplateItems(int templateId) async {
    final itemMaps = await _mealTemplateDao.getTemplateItems(templateId);
    return itemMaps
        .map(
          (map) => MealTemplateItem(
            id: map['id'],
            templateId: map['templateId'],
            foodId: map['foodId'],
            foodName: map['foodName'],
            quantity: map['quantity'],
            unit: map['unit'],
            calories: map['calories'],
            protein: map['protein'],
            carbs: map['carbs'],
            fat: map['fat'],
          ),
        )
        .toList();
  }

  // Helper to convert template maps to MealTemplate objects
  List<MealTemplate> _convertToTemplates(
    List<Map<String, dynamic>> templateMaps,
  ) {
    return templateMaps.map((map) {
      final items =
          (map['items'] as List<dynamic>)
              .map(
                (item) => MealTemplateItem(
                  id: item['id'],
                  templateId: map['id'],
                  foodId: item['foodId'],
                  foodName: item['foodName'],
                  quantity: item['quantity'],
                  unit: item['unit'],
                  calories: item['calories'],
                  protein: item['protein'],
                  carbs: item['carbs'],
                  fat: item['fat'],
                ),
              )
              .toList();

      return MealTemplate(
        id: map['id'],
        name: map['name'],
        description: map['description'],
        category: map['category'],
        items: items,
      );
    }).toList();
  }

  // Update an existing template
  Future<void> updateMealTemplate(MealTemplate template) async {
    if (template.id == null) {
      throw Exception('Cannot update template without an ID');
    }

    // First delete all existing items for this template
    await _mealTemplateDao.deleteTemplateItems(template.id!);

    // Create template map with base data (without items)
    final templateMap = {
      'id': template.id,
      'name': template.name,
      'description': template.description ?? '',
      'category': template.category,
      'items': [], // Start with empty items array, we'll add them after update
    };

    // Update the template
    final success = await _mealTemplateDao.updateTemplate(
      templateMap,
      template.id!,
    );

    if (success) {
      // Add all items one by one
      for (var item in template.items) {
        final itemMap = {
          'templateId': template.id,
          'foodId': item.foodId,
          'foodName': item.foodName,
          'quantity': item.quantity,
          'unit': item.unit,
          'calories': item.calories,
          'protein': item.protein,
          'carbs': item.carbs,
          'fat': item.fat,
        };

        await _mealTemplateDao.insertTemplateItem(itemMap);
      }

    } else {
      throw Exception('Template not found or could not be updated');
    }
  }

  // Delete a template
  Future<void> deleteMealTemplate(int templateId) async {
    await _mealTemplateDao.deleteTemplate(templateId);
  }
}
