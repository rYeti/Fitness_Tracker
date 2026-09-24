part of 'sync_service.dart';

/// Food items, meals and the foods in them, and meal templates.
extension NutritionSync on SyncService {
  Future<void> syncFoodItems() async {
    final unsynced = await _db.foodItemDao.getUnsyncedItems();
    if (unsynced.isEmpty) return;

    for (final item in unsynced) {
      try {
        switch (SyncStatus.fromDb(item.syncStatus)) {
          case SyncStatus.pending:
            await _syncNewFoodItem(item);
          case SyncStatus.pendingUpdate:
            await _syncUpdateFoodItem(item);
          case SyncStatus.pendingDelete:
            await _syncDeleteFoodItem(item);
          case SyncStatus.synced || SyncStatus.retired:
            break;
        }
      } catch (e) {
        _logger.w('Food item sync failed for local ${item.id}: $e');
      }
    }
  }

  Future<void> _syncNewFoodItem(FoodItemData item) async {
    final response = await _apiClient.post(
      'api/FoodItem',
      data: {
        'name': item.name,
        'calories': item.calories,
        'protein': item.protein,
        'carbs': item.carbs,
        'fat': item.fat,
        'gramm': item.gramm,
        'hiddenFromRecent': item.hiddenFromRecent,
        'extendedNutrientsJson': item.extendedNutrientsJson,
      },
    );
    final serverId = response.data['id'] as String;
    await _markSent(_db.foodItem, item.id, serverId, item.localRev);
    _logger.i('Synced new food item ${item.id} → server $serverId');
  }

  Future<void> _syncUpdateFoodItem(FoodItemData item) async {
    if (item.serverId == null) {
      await _syncNewFoodItem(item);
      return;
    }
    await _apiClient.put(
      'api/FoodItem/${item.serverId}',
      data: {
        'name': item.name,
        'calories': item.calories,
        'protein': item.protein,
        'carbs': item.carbs,
        'fat': item.fat,
        'gramm': item.gramm,
        'hiddenFromRecent': item.hiddenFromRecent,
        'extendedNutrientsJson': item.extendedNutrientsJson,
      },
    );
    await _markSent(_db.foodItem, item.id, item.serverId!, item.localRev);
    _logger.i('Updated food item ${item.id} on server ${item.serverId}');
  }

  Future<void> _syncDeleteFoodItem(FoodItemData item) async {
    if (item.serverId != null) {
      try {
        await _apiClient.delete('api/FoodItem/${item.serverId}');
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) rethrow;
      }
    }
    await _db.untracked(() => _db.foodItemDao.deleteById(item.id));
    if (item.serverId == null) return;
    _logger.i('Deleted food item ${item.id} from server ${item.serverId}');
  }

  Future<void> syncMeals() async {
    final unsynced = await _db.mealDao.getUnsyncedMeals();
    if (unsynced.isEmpty) return;

    for (final meal in unsynced) {
      try {
        switch (SyncStatus.fromDb(meal.syncStatus)) {
          case SyncStatus.pending:
            await _syncNewMeal(meal);
          case SyncStatus.pendingUpdate:
            await _syncUpdateMeal(meal);
          case SyncStatus.pendingDelete:
            await _syncDeleteMeal(meal);
          case SyncStatus.synced || SyncStatus.retired:
            break;
        }
      } catch (e) {
        _logger.w('Meal sync failed for local ${meal.id}: $e');
      }
    }
  }

  Future<void> _syncNewMeal(MealTableData meal) async {
    // Resolve the primary food item's server ID.
    final primaryFood = await _db.foodItemDao.getFoodItemById(meal.foodItemId);
    final primaryServerId = primaryFood?.serverId;

    final response = await _apiClient.post(
      'api/Meal',
      data: {
        'date': meal.date.toUtc().toIso8601String(),
        'category': meal.category,
        'foodItemId': primaryServerId ?? '00000000-0000-0000-0000-000000000000',
      },
    );
    final data = (response.data as Map).cast<String, dynamic>();
    final mealServerId = data['id'] as String;

    // Creating a meal is idempotent per day and category server-side, so this POST
    // may well have returned a meal that was already there — with the food entries
    // it already holds. Posting ours on top of those is how a lunch of five foods
    // became a lunch of ten in the Trainer Console, and doubled the day's calories
    // with it: the trainee app reads one row per category and merges its entries by
    // food item, so it renders that meal correctly and its user never sees the
    // second copy, let alone gets a way to delete it.
    final entries = await _db.mealDao.getAllFoodEntriesForMeal(meal.id);
    final unstamped = entries.where((e) => e.serverId == null).toList();
    final stillMissing = await _stampMealFoodEntriesFromServer(
      unstamped,
      (data['foodEntries'] as List? ?? []).cast<Map<String, dynamic>>(),
    );
    await _syncMealFoodEntriesBatch(stillMissing, mealServerId);
    // Only once its entries are across: a meal marked synced first and then
    // failing on its entries left them behind a row that looked done.
    await _markSent(_db.mealTable, meal.id, mealServerId, meal.localRev);
    _logger.i('Synced new meal ${meal.id} → server $mealServerId');
  }

  /// Links local food entries to the ones the meal already holds server-side and
  /// returns those that genuinely still need creating.
  ///
  /// Same shape as [_stampWorkoutExercisesFromServer], and for the same reason: a
  /// row the server already has is not a row to create again, and a duplicate here
  /// is not something the user can undo. Each server entry is claimed at most once,
  /// so a client that logged two portions of one food still gets its second entry
  /// created — repeats within a meal are real (`LoggedMealDto.Foods` says so), and
  /// collapsing them would under-report what somebody ate.
  Future<List<dynamic>> _stampMealFoodEntriesFromServer(
    List<dynamic> unstamped,
    List<Map<String, dynamic>> serverEntries,
  ) async {
    if (serverEntries.isEmpty || unstamped.isEmpty) return unstamped;

    final claimed = <String>{};
    final stillMissing = <dynamic>[];
    for (final entry in unstamped) {
      final food = await _db.foodItemDao.getFoodItemById(entry.foodEntryId);
      final foodServerId = food?.serverId;
      if (foodServerId == null) {
        stillMissing.add(entry);
        continue;
      }

      Map<String, dynamic>? match;
      for (final s in serverEntries) {
        if (claimed.contains(s['id'] as String)) continue;
        if (s['foodItemId'] == foodServerId) {
          match = s;
          break;
        }
      }
      if (match == null) {
        stillMissing.add(entry);
        continue;
      }

      final matchedServerId = match['id'] as String;
      claimed.add(matchedServerId);
      await _db.mealDao.setFoodEntryServerId(entry.id, matchedServerId);
      _logger.i(
        'Re-linked meal food entry ${entry.id} to existing server '
        '$matchedServerId (was about to be created a second time)',
      );
    }
    return stillMissing;
  }

  Future<void> _syncUpdateMeal(MealTableData meal) async {
    if (meal.serverId == null) {
      await _syncNewMeal(meal);
      return;
    }
    final primaryFood = await _db.foodItemDao.getFoodItemById(meal.foodItemId);
    await _apiClient.put(
      'api/Meal/${meal.serverId}',
      data: {
        'date': meal.date.toUtc().toIso8601String(),
        'category': meal.category,
        'foodItemId':
            primaryFood?.serverId ?? '00000000-0000-0000-0000-000000000000',
      },
    );
    // Push any food entries that haven't been synced yet (batch). A food added
    // to a meal that had already synced is what dirties the meal (the
    // database marks the owner), so this is the path that sends it.
    final entries = await _db.mealDao.getAllFoodEntriesForMeal(meal.id);
    await _syncMealFoodEntriesBatch(
      entries.where((e) => e.serverId == null).toList(),
      meal.serverId!,
    );
    await _markSent(_db.mealTable, meal.id, meal.serverId!, meal.localRev);
    _logger.i('Updated meal ${meal.id} on server ${meal.serverId}');
  }

  Future<void> _syncMealFoodEntriesBatch(
    List<dynamic> entries,
    String mealServerId,
  ) async {
    final foodServerIds = <String>[];
    final valid = <dynamic>[];
    for (final entry in entries) {
      final food = await _db.foodItemDao.getFoodItemById(entry.foodEntryId);
      if (food?.serverId == null) continue;
      foodServerIds.add(food!.serverId!);
      valid.add(entry);
    }
    if (foodServerIds.isEmpty) return;

    final response = await _apiClient.post(
      'api/Meal/$mealServerId/foods/batch',
      data: foodServerIds,
    );
    final serverList = (response.data as List).cast<Map<String, dynamic>>();
    for (var i = 0; i < valid.length && i < serverList.length; i++) {
      await _db.mealDao.setFoodEntryServerId(
        valid[i].id,
        serverList[i]['id'] as String,
      );
    }
  }

  Future<void> _syncDeleteMeal(MealTableData meal) async {
    if (meal.serverId != null) {
      try {
        await _apiClient.delete('api/Meal/${meal.serverId}');
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) rethrow;
      }
    }
    // Its entries by hand: foreign keys aren't enforced on this database.
    await _db.untracked(() async {
      await (_db.delete(_db.mealFoodTable)
        ..where((t) => t.mealId.equals(meal.id))).go();
      await (_db.delete(_db.mealTable)
        ..where((t) => t.id.equals(meal.id))).go();
    });
    if (meal.serverId == null) return;
    _logger.i('Deleted meal ${meal.id} from server ${meal.serverId}');
  }

  /// Meal templates live in SharedPreferences, not the database, so the sync
  /// triggers can't see them; [MealTemplateDao] keeps the same facts by hand.
  /// Only creates were ever pushed — an edited template was re-created on the
  /// server as a copy (its server id was dropped on save), and a deleted one
  /// came back on the next pull.
  Future<void> syncMealTemplates() async {
    for (final serverId in await _mealTemplateDao.getDeletedServerIds()) {
      try {
        try {
          await _apiClient.delete('api/MealTemplate/$serverId');
        } on DioException catch (e) {
          final code = e.response?.statusCode;
          if (code != 403 && code != 404 && code != 410) rethrow;
        }
        await _mealTemplateDao.clearDeleted(serverId);
      } catch (e) {
        _logger.w('Meal template delete failed for $serverId: $e');
      }
    }

    for (final template in await _mealTemplateDao.getUnsyncedTemplates()) {
      try {
        await _syncNewMealTemplate(template);
      } catch (e) {
        _logger.w('Meal template sync failed for local ${template['id']}: $e');
      }
    }

    for (final template in await _mealTemplateDao.getEditedTemplates()) {
      try {
        final serverId = template['serverId'] as String;
        await _apiClient.put(
          'api/MealTemplate/$serverId',
          data: _mealTemplateBody(template),
        );
        await _mealTemplateDao.markTemplateSynced(
          template['id'] as int,
          serverId,
          sentRev: template['rev'] as int?,
        );
      } catch (e) {
        _logger.w('Meal template update failed for local ${template['id']}: $e');
      }
    }
  }

  Future<void> _syncNewMealTemplate(Map<String, dynamic> template) async {
    final response = await _apiClient.post(
      'api/MealTemplate',
      data: _mealTemplateBody(template),
    );
    final serverId = response.data['id'] as String;
    await _mealTemplateDao.markTemplateSynced(
      template['id'] as int,
      serverId,
      sentRev: template['rev'] as int?,
    );
    _logger.i('Synced meal template ${template['id']} → server $serverId');
  }

  Map<String, dynamic> _mealTemplateBody(Map<String, dynamic> template) {
    final items =
        (template['items'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
    return {
      'name': template['name'],
      'description': template['description'] ?? '',
      'category': template['category'],
      'totalWeightGrams': (template['total_weight_grams'] as num?)?.toDouble(),
      'items':
          items
              .map(
                (i) => {
                  'foodId':
                      '00000000-0000-0000-0000-000000000000', // no FK enforced
                  'foodName': i['foodName'] ?? i['food_name'] ?? '',
                  'quantity': (i['quantity'] as num?)?.toDouble() ?? 0.0,
                  'unit': i['unit'] ?? 'g',
                  'calories': (i['calories'] as num?)?.toDouble() ?? 0.0,
                  'protein': (i['protein'] as num?)?.toDouble() ?? 0.0,
                  'carbs': (i['carbs'] as num?)?.toDouble() ?? 0.0,
                  'fat': (i['fat'] as num?)?.toDouble() ?? 0.0,
                  // Opaque to the server, which stores and returns the
                  // string without parsing it — the gram-based meaning
                  // lives in `ExtendedNutrients` on this side. Without
                  // this the blob survived only until a reinstall.
                  'extendedNutrientsJson':
                      i['extendedNutrientsJson'] ??
                      i['extended_nutrients_json'],
                },
              )
              .toList(),
    };
  }

  Future<void> _pullFoodItems() async {
    final response = await _apiClient.get('api/FoodItem');
    final list = (response.data as List).cast<Map<String, dynamic>>();
    await _applyEach('food items', list, (f) async {
      final serverId = f['id'] as String;
      if (await _db.foodItemDao.getByServerId(serverId) != null) return;
      await _db.foodItemDao.insertFoodItem(
        FoodItemCompanion(
          name: Value(f['name'] as String),
          calories: Value(f['calories'] as int),
          protein: Value(f['protein'] as int),
          carbs: Value(f['carbs'] as int),
          fat: Value(f['fat'] as int),
          gramm: Value(f['gramm'] as int? ?? 100),
          hiddenFromRecent: Value(f['hiddenFromRecent'] as bool? ?? false),
          extendedNutrientsJson: Value(f['extendedNutrientsJson'] as String?),
          serverId: Value(serverId),
          syncStatus: const Value(1),
        ),
      );
    });

    await _removeDeletedElsewhere<FoodItemData>(
      what: 'food items',
      serverIds: {for (final f in list) f['id'] as String},
      locals:
          await (_db.select(_db.foodItem)
            ..where((t) => t.serverId.isNotNull())).get(),
      serverIdOf: (r) => r.serverId!,
      syncStatusOf: (r) => r.syncStatus,
      // A meal logged with it still reads its name and macros from this row;
      // deleting it would change a day that already happened.
      delete: (r) async {
        final inMeal =
            await (_db.select(_db.mealFoodTable)
                  ..where((m) => m.foodEntryId.equals(r.id))
                  ..limit(1))
                .getSingleOrNull();
        if (inMeal != null) return false;
        await _db.foodItemDao.deleteById(r.id);
        return true;
      },
    );
    _logger.i('Pulled ${list.length} food items');
  }

  Future<void> _pullMeals() async {
    final response = await _apiClient.get('api/Meal/all');
    final list = (response.data as List).cast<Map<String, dynamic>>();
    await _applyEach('meals', list, _applyServerMeal);

    await _removeDeletedElsewhere<MealTableData>(
      what: 'meals',
      serverIds: {for (final m in list) m['id'] as String},
      locals:
          await (_db.select(_db.mealTable)
            ..where((t) => t.serverId.isNotNull())).get(),
      serverIdOf: (r) => r.serverId!,
      syncStatusOf: (r) => r.syncStatus,
      delete: (r) async {
        final entries = await _db.mealDao.getAllFoodEntriesForMeal(r.id);
        // An entry never sent is food this device logged that nothing else
        // knows about.
        if (entries.any((e) => e.serverId == null)) return false;
        await (_db.delete(_db.mealFoodTable)
          ..where((t) => t.mealId.equals(r.id))).go();
        await (_db.delete(_db.mealTable)..where((t) => t.id.equals(r.id))).go();
        return true;
      },
    );
    _logger.i('Pulled ${list.length} meals');
  }

  Future<void> _applyServerMeal(Map<String, dynamic> m) async {
    final mealServerId = m['id'] as String;
    // `foodItemId` is the meal's vestigial "primary" food (MealDao's doc
    // comment — real totals only ever come from foodEntries below). It is
    // never nulled out server-side when that food item is deleted, so a
    // food deleted after the meal was created leaves this pointing at
    // nothing. Losing the whole meal — and every entry still resolvable —
    // over one dangling reference used only cosmetically is the same shape
    // of bug fixed for retired workout exercises: don't let a `continue`
    // on unrelated content skip the row that resolvable content needs.
    // Fall back to the first food entry that does resolve, and only to the
    // server's own null-object id (`_syncNewMeal` uses the same sentinel
    // pushing the other way) if nothing in the meal resolves at all.
    var localFoodId =
        (await _db.foodItemDao.getByServerId(m['foodItemId'] as String))
            ?.id;
    if (localFoodId == null) {
      for (final entry
          in (m['foodEntries'] as List).cast<Map<String, dynamic>>()) {
        final entryFood = await _db.foodItemDao.getByServerId(
          entry['foodItemId'] as String,
        );
        if (entryFood != null) {
          localFoodId = entryFood.id;
          break;
        }
      }
    }
    localFoodId ??= 0;

    // Check by serverId first (already synced).
    var existing = await _db.mealDao.getByServerId(mealServerId);

    // If not found by serverId, look for a locally-created meal with same date+category
    // that hasn't been linked to the server yet — adopt it rather than duplicating.
    if (existing == null) {
      final serverDate = _toLocalMidnight(
        DateTime.parse(m['date'] as String),
      );
      final unlinked = await _db.mealDao.getMealByDateAndCategory(
        serverDate,
        m['category'] as String,
      );
      if (unlinked != null && unlinked.serverId == null) {
        await _db.mealDao.markMealSynced(
          localId: unlinked.id,
          serverId: mealServerId,
        );
        existing = await _db.mealDao.getMealById(unlinked.id);
      }
    }

    final int localMealId;
    if (existing == null) {
      final serverDate = _toLocalMidnight(
        DateTime.parse(m['date'] as String),
      );
      localMealId = await _db.mealDao.insertMeal(
        MealTableCompanion(
          date: Value(serverDate),
          category: Value(m['category'] as String),
          foodItemId: Value(localFoodId),
          serverId: Value(mealServerId),
          syncStatus: const Value(1),
        ),
      );
    } else {
      localMealId = existing.id;
    }

    for (final entry
        in (m['foodEntries'] as List).cast<Map<String, dynamic>>()) {
      final entryServerId = entry['id'] as String;
      if (_deletedHere.contains(entryServerId)) continue;
      if (await _db.mealDao.getFoodEntryByServerId(entryServerId) != null) {
        continue;
      }
      final entryFood = await _db.foodItemDao.getByServerId(
        entry['foodItemId'] as String,
      );
      if (entryFood == null) continue;
      // An entry for this food added here and not sent yet is this one:
      // stamp it rather than adding a second. Only an unstamped one — an entry
      // that already has an id is a separate portion of the same food, and
      // overwriting its id lost it.
      final unstamped =
          (await _db.mealDao.getFoodItemsForMeal(localMealId))
              .where((e) => e.foodEntryId == entryFood.id && e.serverId == null)
              .firstOrNull;
      if (unstamped != null) {
        await _db.mealDao.setFoodEntryServerId(unstamped.id, entryServerId);
        continue;
      }
      await _db.mealDao.addFoodToMeal(
        entryFood.id,
        localMealId,
        entryServerId,
      );
    }
  }

  Future<void> _pullMealTemplates() async {
    final response = await _apiClient.get('api/MealTemplate');
    final list = (response.data as List).cast<Map<String, dynamic>>();
    final existing = await _mealTemplateDao.getAllTemplates();
    final existingServerIds =
        existing
            .map((t) => t['serverId'] as String?)
            .whereType<String>()
            .toSet();

    final deletedHere = (await _mealTemplateDao.getDeletedServerIds()).toSet();

    for (final t in list) {
      final serverId = t['id'] as String;
      if (existingServerIds.contains(serverId)) continue;
      if (deletedHere.contains(serverId)) continue;

      final items =
          (t['items'] as List? ?? [])
              .cast<Map<String, dynamic>>()
              .map(
                (i) => {
                  'foodId': 0, // items aren't tied to a live food-catalog row
                  'foodName': i['foodName'] ?? '',
                  'quantity': (i['quantity'] as num?)?.toDouble() ?? 0.0,
                  'unit': i['unit'] ?? 'g',
                  'calories': (i['calories'] as num?)?.toDouble() ?? 0.0,
                  'protein': (i['protein'] as num?)?.toDouble() ?? 0.0,
                  'carbs': (i['carbs'] as num?)?.toDouble() ?? 0.0,
                  'fat': (i['fat'] as num?)?.toDouble() ?? 0.0,
                  'extendedNutrientsJson': i['extendedNutrientsJson'],
                },
              )
              .toList();

      final localId = await _mealTemplateDao.insertTemplate({
        'name': t['name'],
        'description': t['description'] ?? '',
        'category': t['category'] ?? '',
        if (t['totalWeightGrams'] != null)
          'total_weight_grams': (t['totalWeightGrams'] as num).toDouble(),
        'items': items,
        'serverId': serverId,
      });
      _logger.i('Pulled meal template $serverId → local $localId');
    }
  }

  DateTime _toLocalMidnight(DateTime dt) {
    final local = dt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
