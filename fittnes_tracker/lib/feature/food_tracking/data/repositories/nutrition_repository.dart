import 'dart:convert';
import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/utils/app_logger.dart';
import 'package:ForgeForm/feature/food_tracking/data/models/daily_nutrition_model.dart';
import 'package:ForgeForm/feature/food_tracking/data/models/meal_template.dart';
import 'package:drift/drift.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Lightweight cached entry for search results
class _CachedSearch {
  final DateTime ts;
  final List<Map<String, dynamic>> data;
  _CachedSearch(this.ts, this.data);
  bool isFresh(Duration ttl) => DateTime.now().difference(ts) < ttl;
}

class NutritionRepository {
  final AppDatabase db;
  final Dio _dio = Dio(
    BaseOptions(
      // connectTimeout is not reliable on Flutter Web (maps to XHR total timeout).
      // receiveTimeout covers the full round-trip on web, and receive-only on native.
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
  // In–memory search cache (query -> results)
  final Map<String, _CachedSearch> _searchCache = {};
  static const int _maxCacheEntries = 40;
  static const Duration _cacheTtl = Duration(minutes: 10);
  static const Duration _emptyResultTtl = Duration(minutes: 5);
  bool _persistentLoaded = false; // lazy load flag

  NutritionRepository(this.db);

  /// Fire-and-forget: establishes the TCP connection early so the first
  /// real search doesn't pay the connection cost.
  void prewarmConnection() {
    final url =
        kIsWeb
            ? 'https://world.openfoodfacts.org/'
            : 'https://search.openfoodfacts.org/';
    _dio.head(url).ignore();
  }

  Future<List<Map<String, dynamic>>> searchFoods(
    String query, {
    String? languageCode,
    CancelToken? cancelToken,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    // Lazy load persistent cache once
    if (!_persistentLoaded) {
      await _loadPersistent();
    }

    // 1. Exact cache hit & fresh
    final exact = _searchCache[q];
    if (exact != null) {
      final ttl = exact.data.isEmpty ? _emptyResultTtl : _cacheTtl;
      if (exact.isFresh(ttl)) {
        return List<Map<String, dynamic>>.from(exact.data);
      }
    }

    // 2. Network fetch
    try {
      AppLogger.i('searchFoods: requesting "$q"…');
      final List<Map<String, dynamic>> list;
      if (kIsWeb) {
        // Web: use the legacy CGI endpoint (CORS-safe)
        final resp = await _dio.get(
          'https://world.openfoodfacts.org/cgi/search.pl',
          cancelToken: cancelToken,
          queryParameters: {
            'action': 'process',
            'json': 1,
            'page_size': 25,
            'fields':
                'id,product_name,brands,nutriments,serving_size,serving_quantity,serving_quantity_unit',
            'tagtype_0': 'product_name',
            'tag_contains_0': 'contains',
            'tag_0': q,
            'sort_by': 'unique_scans_n',
            if (languageCode != null) 'lc': languageCode,
          },
        );
        final data = resp.data;
        final products = (data is Map) ? data['products'] : null;
        list =
            (products is List)
                ? products
                    .whereType<Map>()
                    .cast<Map<String, dynamic>>()
                    .toList()
                : <Map<String, dynamic>>[];
      } else {
        // Native (Android/iOS): use the fast Elasticsearch endpoint.
        // Do NOT pass sort_by — let Elasticsearch rank by relevance so that
        // short exact-match queries (e.g. "Ei") aren't buried by popular
        // longer-named products (e.g. "Eis").
        final resp = await _dio.get(
          'https://search.openfoodfacts.org/search',
          cancelToken: cancelToken,
          queryParameters: {
            'q': q,
            'page_size': 40,
            'fields':
                'id,product_name,brands,nutriments,serving_size,serving_quantity,serving_quantity_unit',
            if (languageCode != null) 'langs': languageCode,
          },
        );
        final data = resp.data;
        final hits = (data is Map) ? data['hits'] : null;
        list =
            (hits is List)
                ? hits.whereType<Map>().cast<Map<String, dynamic>>().toList()
                : <Map<String, dynamic>>[];
      }
      AppLogger.i('searchFoods: got ${list.length} results for "$q"');
      _cacheStore(q, list);
      return List<Map<String, dynamic>>.from(list);
    } catch (e) {
      // Request was cancelled by a newer search — return empty silently
      if (e is DioException && e.type == DioExceptionType.cancel) {
        return [];
      }
      AppLogger.e('searchFoods error: $e');
      // On failure, fallback to stale cache if exists
      if (exact != null) return List<Map<String, dynamic>>.from(exact.data);
      rethrow;
    }
  }

  void _cacheStore(String q, List<Map<String, dynamic>> data) {
    // Always store in memory (including empty results, to avoid re-fetching)
    _searchCache[q] = _CachedSearch(DateTime.now(), data);
    if (_searchCache.length > _maxCacheEntries) {
      // Evict oldest
      final oldestKey =
          _searchCache.entries
              .reduce((a, b) => a.value.ts.isBefore(b.value.ts) ? a : b)
              .key;
      _searchCache.remove(oldestKey);
      // Best-effort prune in persistent store (ignore errors)
      try {
        db.searchCacheDao.deleteByQuery(oldestKey);
      } catch (_) {}
    }
    // Only persist non-empty results to SQLite
    if (data.isEmpty) return;
    try {
      db.searchCacheDao.upsert(
        q,
        jsonEncode(data),
        DateTime.now().millisecondsSinceEpoch,
      );
      // Periodic pruning of stale rows
      db.searchCacheDao.deleteOlderThan(
        DateTime.now().subtract(_cacheTtl).millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  Future<void> _loadPersistent() async {
    _persistentLoaded = true; // set first to avoid re-entry on errors
    try {
      final cutoff = DateTime.now().subtract(_cacheTtl).millisecondsSinceEpoch;
      final rows = await db.searchCacheDao.getAll();
      for (final row in rows) {
        if (row.ts < cutoff) continue; // stale
        try {
          final decoded = jsonDecode(row.json);
          if (decoded is List) {
            final list =
                decoded.whereType<Map>().cast<Map<String, dynamic>>().toList();
            _searchCache[row.query] = _CachedSearch(
              DateTime.fromMillisecondsSinceEpoch(row.ts),
              list,
            );
          }
        } catch (_) {
          // ignore malformed rows
        }
      }
    } catch (_) {
      // ignore load errors
    }
  }

  Future<List<MealTableData>> getMealsForToday() async {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    return await db.mealDao.getMealsForDate(today); // fix
  }

  Future<void> addFoodToMeal(
    String category,
    FoodItemData foodItem, {
    DateTime? date,
  }) async {
    final day = _normalizeDate(date);
    final meals = await db.mealDao.getMealsForDate(day);
    MealTableData? meal;
    try {
      meal = meals.firstWhere((m) => m.category == category);
    } catch (_) {
      meal = null;
    }
    if (meal == null) {
      final mealId = await db.mealDao.insertMeal(
        MealTableCompanion(
          date: Value(day),
          category: Value(category),
          foodItemId: Value(foodItem.id),
        ),
      );
      meal = await db.mealDao.getMealById(mealId);
    }
    await db.mealDao.addFoodToMeal(foodItem.id, meal!.id);
  }

  DateTime _normalizeDate(DateTime? date) {
    final d = date ?? DateTime.now();
    return DateTime(d.year, d.month, d.day);
  }

  Future<List<FoodItemData>> getFoodItemsForCategory(
    String category, {
    DateTime? date,
  }) async {
    final day = _normalizeDate(date);
    final meals = await db.mealDao.getMealsForDate(day);
    MealTableData? meal;
    try {
      meal = meals.firstWhere((m) => m.category == category);
    } catch (_) {
      meal = null;
    }
    if (meal == null) return [];
    final mealFoodEntries = await db.mealDao.getFoodItemsForMeal(meal.id);
    if (mealFoodEntries.isEmpty) return [];
    final foodItems = <FoodItemData>[];
    for (final entry in mealFoodEntries) {
      final food = await db.foodItemDao.getFoodItemById(
        entry.foodEntryId,
      ); // fix
      if (food != null) foodItems.add(food);
    }
    return foodItems;
  }

  Future<UserSetting?> getUserSettings() async {
    return await db.userSettingsDao.getSettings();
  }

  Future<List<FoodItemData>> getNutritionHistory() async {
    return await db.foodItemDao.getAllFoodItems(); // fix
  }

  Future<List<DailyNutrition>> getNutritionHistoryForToday() async {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final meals = await db.mealDao.getMealsForDate(today); // fix
    if (meals.isEmpty) return [];
    final dailyNutrition = DailyNutrition.empty(today);
    for (final meal in meals) {
      final foodItems = await db.mealDao.getFoodItemsForMeal(meal.id); // fix
      for (final entry in foodItems) {
        final foodItem = await db.foodItemDao.getFoodItemById(
          entry.foodEntryId,
        ); // fix
        if (foodItem != null) {
          dailyNutrition.totalCalories += foodItem.calories;
          dailyNutrition.totalProtein += foodItem.protein;
          dailyNutrition.totalCarbs += foodItem.carbs;
          dailyNutrition.totalFat += foodItem.fat;
          dailyNutrition.meals[meal.category]?.add(foodItem.name);
        }
      }
    }
    return [dailyNutrition];
  }

  Future<int> removeFoodFromMeal(
    String category,
    FoodItemData foodItem, {
    DateTime? date,
  }) async {
    final day = _normalizeDate(date);
    final meals = await db.mealDao.getMealsForDate(day);
    final meal = meals.firstWhere(
      (m) => m.category == category,
      orElse: () => throw StateError('No meal found for category $category'),
    );
    return await db.mealDao.deleteFoodFromMeal(foodItem.id, meal.id);
  }

  Future<int> setCalorieGoal(int goal) async {
    return await db.userSettingsDao.setCalorieGoal(goal);
  }

  Future getTodayNutrition() async {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    return await db.mealDao.getMealsForDate(today); // fix
  }

  // Add a template to a specific meal category
  Future<void> applyTemplateToMeal(
    String category,
    List<MealTemplateItem> templateItems,
  ) async {
    for (final item in templateItems) {
      // First, make sure the food item is in the database
      FoodItemData? foodItem = await db.foodItemDao.getFoodItemById(
        item.foodId,
      );

      // If the food doesn't exist, create it first
      if (foodItem == null) {
        try {
          final foodId = await db.foodItemDao.insertFoodItem(
            FoodItemCompanion.insert(
              name: item.foodName,
              calories: item.calories.toInt(),
              protein: item.protein.toInt(),
              carbs: item.carbs.toInt(),
              fat: item.fat.toInt(),
              gramm: Value(item.quantity.toInt()),
            ),
          );

          foodItem = await db.foodItemDao.getFoodItemById(foodId);

          if (foodItem == null) {
            continue; // Skip if we couldn't create the food
          }
        } catch (e) {
          continue; // Skip if there was an error
        }
      } else {
        AppLogger.i(
          'Found existing food item: ${foodItem.name} (ID: ${foodItem.id})',
        );
      }

      // Add the food to the meal
      try {
        await addFoodToMeal(category, foodItem);
      } catch (e) {
        AppLogger.i('Error adding food to meal: $e');
      }
    }
  }
}
