import 'dart:convert';
import 'package:ForgeForm/core/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as dev;

// An implementation that uses SharedPreferences for persistent storage
class MealTemplateDao {
  final AppDatabase db;
  static const String _storageKey = 'meal_templates';
  static int _nextId = 1;

  MealTemplateDao(this.db) {
    _initNextId();
  }

  // Initialize the next ID based on stored templates
  Future<void> _initNextId() async {
    try {
      final templates = await getAllTemplates();
      if (templates.isNotEmpty) {
        final maxId = templates
            .map((t) => t['id'] as int)
            .reduce((value, element) => value > element ? value : element);
        _nextId = maxId + 1;
      }
    } catch (e) {
      dev.log('Error initializing next ID: $e', name: 'MealTemplateDao');
    }
  }

  // Load templates from SharedPreferences
  Future<List<Map<String, dynamic>>> _loadTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e, stackTrace) {
      dev.log('Error loading templates: $e', name: 'MealTemplateDao');
      dev.log('Stack trace: $stackTrace', name: 'MealTemplateDao');
      return [];
    }
  }

  // Save templates to SharedPreferences
  Future<void> _saveTemplates(List<Map<String, dynamic>> templates) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(templates);
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      dev.log('Error saving templates: $e', name: 'MealTemplateDao');
    }
  }

  // Get all templates
  Future<List<Map<String, dynamic>>> getAllTemplates() async {
    try {
      return await _loadTemplates();
    } catch (e) {
      dev.log('Error getting all templates: $e', name: 'MealTemplateDao');
      return [];
    }
  }

  // Get templates by category
  Future<List<Map<String, dynamic>>> getTemplatesByCategory(
    String category,
  ) async {
    try {
      final templates = await _loadTemplates();
      return templates.where((t) => t['category'] == category).toList();
    } catch (e) {
      dev.log(
        'Error getting templates by category: $e',
        name: 'MealTemplateDao',
      );
      return [];
    }
  }

  // Get items for a template
  Future<List<Map<String, dynamic>>> getTemplateItems(int templateId) async {
    try {
      final templates = await _loadTemplates();
      final template = templates.firstWhere(
        (t) => t['id'] == templateId,
        orElse: () => {'items': []},
      );
      return List<Map<String, dynamic>>.from(template['items'] ?? []);
    } catch (e) {
      dev.log('Error getting template items: $e', name: 'MealTemplateDao');
      return [];
    }
  }

  // Insert a new template
  Future<int> insertTemplate(Map<String, dynamic> template) async {
    try {
      final templates = await _loadTemplates();

      // Create a new template with ID
      final id = _nextId++;
      template['id'] = id;
      if (!template.containsKey('items')) {
        template['items'] = [];
      }

      templates.add(template);
      await _saveTemplates(templates);

      dev.log('Template inserted with ID: $id', name: 'MealTemplateDao');
      return id;
    } catch (e) {
      dev.log('Error inserting template: $e', name: 'MealTemplateDao');
      return -1;
    }
  }

  // Insert a template item
  Future<int> insertTemplateItem(Map<String, dynamic> item) async {
    try {
      final templates = await _loadTemplates();
      final templateId = item['templateId'];
      final index = templates.indexWhere((t) => t['id'] == templateId);

      if (index >= 0) {
        final template = templates[index];
        final items = List<Map<String, dynamic>>.from(template['items'] ?? []);

        // Generate a new ID for this item
        final itemId =
            items.isEmpty
                ? 1
                : (items
                        .map((i) => i['id'] as int)
                        .reduce((a, b) => a > b ? a : b) +
                    1);

        // Set the ID and add the item
        item['id'] = itemId;
        items.add(Map<String, dynamic>.from(item));

        // Update the template
        template['items'] = items;
        templates[index] = template;

        await _saveTemplates(templates);
        return itemId;
      }

      return -1;
    } catch (e) {
      dev.log('Error inserting template item: $e', name: 'MealTemplateDao');
      return -1;
    }
  }

  // Update a template
  Future<bool> updateTemplate(Map<String, dynamic> template, int id) async {
    try {
      final templates = await _loadTemplates();
      final index = templates.indexWhere((t) => t['id'] == id);

      if (index >= 0) {
        // Preserve the original template id
        template['id'] = id;

        // Preserve the items if not provided in the update
        if (!template.containsKey('items')) {
          template['items'] = templates[index]['items'];
        }

        // Update the template in the list
        templates[index] = template;
        dev.log(
          'Updating template with ID: $id, data: ${jsonEncode(template)}',
          name: 'MealTemplateDao',
        );
        await _saveTemplates(templates);
        return true;
      }
      dev.log(
        'Template with ID: $id not found for update',
        name: 'MealTemplateDao',
      );
      return false;
    } catch (e, stackTrace) {
      dev.log('Error updating template: $e', name: 'MealTemplateDao');
      dev.log('Stack trace: $stackTrace', name: 'MealTemplateDao');
      return false;
    }
  }

  // Delete all items for a template
  Future<int> deleteTemplateItems(int templateId) async {
    try {
      final templates = await _loadTemplates();
      final index = templates.indexWhere((t) => t['id'] == templateId);

      if (index >= 0) {
        final itemCount = (templates[index]['items'] as List).length;
        templates[index]['items'] = [];
        await _saveTemplates(templates);
        return itemCount;
      }
      return 0;
    } catch (e) {
      dev.log('Error deleting template items: $e', name: 'MealTemplateDao');
      return 0;
    }
  }

  // Delete a template
  Future<int> deleteTemplate(int templateId) async {
    try {
      final templates = await _loadTemplates();
      final index = templates.indexWhere((t) => t['id'] == templateId);

      if (index >= 0) {
        templates.removeAt(index);
        await _saveTemplates(templates);
        return 1;
      }
      return 0;
    } catch (e) {
      dev.log('Error deleting template: $e', name: 'MealTemplateDao');
      return 0;
    }
  }
}
