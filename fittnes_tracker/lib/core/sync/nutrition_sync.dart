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
    final response = await _create(
      'api/FoodItem',
      {'id': item.serverId, ..._foodItemBody(item)},
      _db.foodItem,
      [item.id],
    );
    if (response == null) return;
    final serverId = response.data['id'] as String;
    await _markSent(_db.foodItem, item.id, serverId, item.localRev);
    _logger.i('Synced new food item ${item.id} → server $serverId');
  }

  Map<String, dynamic> _foodItemBody(FoodItemData item) => {
    'name': item.name,
    'calories': item.calories,
    'protein': item.protein,
    'carbs': item.carbs,
    'fat': item.fat,
    'gramm': item.gramm,
    'hiddenFromRecent': item.hiddenFromRecent,
    'extendedNutrientsJson': item.extendedNutrientsJson,
  };

  Future<void> _syncUpdateFoodItem(FoodItemData item) async {
    if (item.serverId == null) {
      await _syncNewFoodItem(item);
      return;
    }
    await _apiClient.put(
      'api/FoodItem/${item.serverId}',
      data: _foodItemBody(item),
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

  /// The server id of a food a meal refers to, if the server has that food.
  Future<String?> _foodServerId(int localFoodId) async {
    final food = await _db.foodItemDao.getFoodItemById(localFoodId);
    return food == null
        ? null
        : SyncService._serverIdIfPushed(food.serverId, food.syncStatus);
  }

  Future<Map<String, dynamic>> _mealBody(MealTableData meal) async => {
    'date': meal.date.toUtc().toIso8601String(),
    'category': meal.category,
    'foodItemId':
        await _foodServerId(meal.foodItemId) ??
        '00000000-0000-0000-0000-000000000000',
  };

  Future<void> _syncNewMeal(MealTableData meal) async {
    final response = await _create(
      'api/Meal',
      {'id': meal.serverId, ...await _mealBody(meal)},
      _db.mealTable,
      [meal.id],
    );
    if (response == null) return;
    final data = (response.data as Map).cast<String, dynamic>();
    final mealServerId = data['id'] as String;

    if (mealServerId != meal.serverId) {
      // The server keeps one meal per day and category, and already had this
      // one — another device's, or this device's before a reinstall — so it
      // answered with that meal. Its foods are part of it: sending this
      // device's list as the whole list would delete them.
      final merged = await _db.untracked(
        () => _mergeIntoServerMeal(meal, mealServerId, data),
      );
      if (!merged) return;
    }

    final complete = await _putMealFoods(meal.id, mealServerId);
    // Only once its foods are across: a meal marked synced first and then
    // failing on its foods left them behind a row that looked done.
    await _markSent(
      _db.mealTable,
      meal.id,
      mealServerId,
      complete ? meal.localRev : -1,
    );
    _logger.i('Synced new meal ${meal.id} → server $mealServerId');
  }

  /// Makes [meal] the server's meal [mealServerId], which its create was
  /// answered with, keeping the foods on both.
  ///
  /// If another row on this device is already that meal, this one's foods
  /// move to it and this row goes; that row is marked changed, so its push
  /// sends the combined list, and there is nothing left here to send (false).
  /// Otherwise this row takes the server's id and the foods the server's meal
  /// holds, and its push goes on to send the combined list (true).
  Future<bool> _mergeIntoServerMeal(
    MealTableData meal,
    String mealServerId,
    Map<String, dynamic> serverMeal,
  ) async {
    final twin = await _db.mealDao.getByServerId(mealServerId);
    if (twin != null && twin.id != meal.id) {
      await (_db.update(_db.mealFoodTable)
        ..where((t) => t.mealId.equals(meal.id))).write(
        MealFoodTableCompanion(mealId: Value(twin.id)),
      );
      await (_db.delete(_db.mealTable)..where((t) => t.id.equals(meal.id))).go();
      await _dirtyIfClean(_db.mealTable, twin.id);
      _logger.i(
        'Meal ${meal.id} is the server\'s $mealServerId, already here as '
        '${twin.id}; moved its foods there',
      );
      return false;
    }

    await (_db.update(_db.mealTable)..where((t) => t.id.equals(meal.id))).write(
      MealTableCompanion(serverId: Value(mealServerId)),
    );
    await _addServerFoodEntries(
      meal.id,
      (serverMeal['foodEntries'] as List? ?? []).cast<Map<String, dynamic>>(),
    );
    return true;
  }

  /// Adds the server's foods a meal on this device doesn't hold yet, under
  /// the server's ids.
  Future<void> _addServerFoodEntries(
    int localMealId,
    List<Map<String, dynamic>> serverEntries,
  ) async {
    for (final entry in serverEntries) {
      final entryServerId = entry['id'] as String;
      // An older build's removal of it, not yet sent.
      if (_deletedHere.contains(entryServerId)) continue;
      if (await _db.mealDao.getFoodEntryByServerId(entryServerId) != null) {
        continue;
      }
      final entryFood = await _db.foodItemDao.getByServerId(
        entry['foodItemId'] as String,
      );
      if (entryFood == null) continue;
      await _db.mealDao.addFoodToMeal(entryFood.id, localMealId, entryServerId);
    }
  }

  Future<void> _syncUpdateMeal(MealTableData meal) async {
    if (meal.serverId == null) {
      await _syncNewMeal(meal);
      return;
    }
    await _apiClient.put(
      'api/Meal/${meal.serverId}',
      data: await _mealBody(meal),
    );
    // A food added to or taken out of a meal the server has is what dirties
    // the meal (the database marks the owner), so this is the path that
    // sends it — as the whole list.
    final complete = await _putMealFoods(meal.id, meal.serverId!);
    await _markSent(
      _db.mealTable,
      meal.id,
      meal.serverId!,
      complete ? meal.localRev : -1,
    );
    _logger.i('Updated meal ${meal.id} on server ${meal.serverId}');
  }

  /// Sends a meal's whole list of foods, each under the id this device minted
  /// for it, which the server makes the meal's list.
  ///
  /// This replaced two things. Foods were added with a batch whose answer was
  /// paired with the request by position, and after a meal create that the
  /// server answered with an existing meal they were first matched by food
  /// against what it held (`_stampMealFoodEntriesFromServer`). And a removed
  /// food needed its own DELETE, addressed by meal and food item — which could
  /// not tell two portions of one food apart. The whole list under stable ids
  /// needs neither.
  ///
  /// Returns false when a food in the meal is not on the server yet: the list
  /// goes without it, and the meal is left dirty so it goes again next push,
  /// when the food has been created.
  Future<bool> _putMealFoods(int localMealId, String mealServerId) async {
    final entries = await _db.mealDao.getAllFoodEntriesForMeal(localMealId);
    final body = <Map<String, dynamic>>[];
    var complete = true;
    for (final entry in entries) {
      final food = await _db.foodItemDao.getFoodItemById(entry.foodEntryId);
      if (food == null) continue; // a dangling entry names nothing to send
      final foodServerId = SyncService._serverIdIfPushed(
        food.serverId,
        food.syncStatus,
      );
      if (foodServerId == null) {
        complete = false;
        continue;
      }
      body.add({'id': entry.serverId, 'foodItemId': foodServerId});
    }
    try {
      await _apiClient.put('api/Meal/$mealServerId/foods', data: body);
    } catch (e) {
      if (SyncService._isIdConflict(e)) {
        // The server refused one of the entries' ids (409). The list is
        // replaced whole, so every entry can take a new one at no cost: the
        // next PUT drops the rows stored under the old ids and keeps these.
        for (final entry in entries) {
          await _db.untracked(
            () => _db.mealDao.setFoodEntryServerId(entry.id, newSyncId()),
          );
        }
      }
      rethrow;
    }
    return complete;
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
    final localId = template['id'] as int;
    // A template made before this device minted ids has none yet.
    final minted = template['serverId'] as String?;
    final id =
        minted != null && minted.isNotEmpty
            ? minted
            : await _mealTemplateDao.assignServerId(localId);
    final Response response;
    try {
      response = await _apiClient.post(
        'api/MealTemplate',
        data: {'id': id, ..._mealTemplateBody(template)},
      );
    } catch (e) {
      if (SyncService._isIdConflict(e)) {
        await _mealTemplateDao.assignServerId(localId);
      }
      rethrow;
    }
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
          await (_db.select(_db.foodItem)..where(
                (t) =>
                    t.serverId.isNotNull() &
                    t.syncStatus.isNotValue(SyncStatus.pending.index),
              ))
              .get(),
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
          await (_db.select(_db.mealTable)..where(
                (t) =>
                    t.serverId.isNotNull() &
                    t.syncStatus.isNotValue(SyncStatus.pending.index),
              ))
              .get(),
      serverIdOf: (r) => r.serverId!,
      syncStatusOf: (r) => r.syncStatus,
      // Only ever reached for a clean meal, whose foods the server has all
      // seen: a food added here dirties its meal until the push sends it.
      delete: (r) async {
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

    // If not found by serverId, look for a meal this device made for the same
    // date and category that the server doesn't have yet. The server keeps
    // one meal per day and category, and would answer its create with this
    // one: adopt it rather than duplicating.
    var adopted = false;
    if (existing == null) {
      final serverDate = _toLocalMidnight(
        DateTime.parse(m['date'] as String),
      );
      final unpushed = await _db.mealDao.getMealByDateAndCategory(
        serverDate,
        m['category'] as String,
      );
      if (unpushed != null &&
          SyncStatus.fromDb(unpushed.syncStatus) == SyncStatus.pending) {
        // The server has this meal now, but not this device's foods: it stays
        // changed, and its push sends the combined list.
        await (_db.update(_db.mealTable)
          ..where((t) => t.id.equals(unpushed.id))).write(
          MealTableCompanion(
            serverId: Value(mealServerId),
            syncStatus: Value(SyncStatus.pendingUpdate.index),
          ),
        );
        existing = await _db.mealDao.getMealById(unpushed.id);
        adopted = true;
      }
    }

    final serverEntries =
        (m['foodEntries'] as List).cast<Map<String, dynamic>>();
    if (existing == null) {
      final serverDate = _toLocalMidnight(
        DateTime.parse(m['date'] as String),
      );
      final localMealId = await _db.mealDao.insertMeal(
        MealTableCompanion(
          date: Value(serverDate),
          category: Value(m['category'] as String),
          foodItemId: Value(localFoodId),
          serverId: Value(mealServerId),
          syncStatus: const Value(1),
        ),
      );
      await _addServerFoodEntries(localMealId, serverEntries);
      return;
    }

    final localMealId = existing.id;
    if (adopted) {
      await _addServerFoodEntries(localMealId, serverEntries);
      return;
    }
    // A meal with an unsent change holds this device's list, which its push
    // sends whole — a food taken out here must not come back from the server
    // before it goes.
    if (SyncStatus.fromDb(existing.syncStatus) != SyncStatus.synced) return;

    // A clean meal holds nothing the server hasn't seen, so its list is the
    // server's to set: add what it has, and take out what it no longer lists.
    // This used to only add, which was enough while the push only ever added
    // too. It now sends the whole list, so a food removed on another device
    // but left here would go back up with the next edit to this meal.
    await _addServerFoodEntries(localMealId, serverEntries);
    final listed = {for (final e in serverEntries) e['id'] as String};
    await (_db.delete(_db.mealFoodTable)..where(
          (t) => t.mealId.equals(localMealId) & t.serverId.isNotIn(listed),
        ))
        .go();
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
