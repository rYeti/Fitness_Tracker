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

  /// What a meal's create and update send, or null while the food it names
  /// is on this device but not on the server yet: the meal waits for it
  /// rather than going up without it (see [SyncService._serverIdIfPushed]).
  ///
  /// `foodItemId` is the meal's vestigial "primary" food — totals come from
  /// its entries. A food this device doesn't hold at all (the pull stores 0
  /// when nothing in a server meal resolved) goes as the server's own
  /// null-object id, which is what it held already.
  Future<Map<String, dynamic>?> _mealBody(MealTableData meal) async {
    var foodItemId = '00000000-0000-0000-0000-000000000000';
    final food = await _db.foodItemDao.getFoodItemById(meal.foodItemId);
    if (food != null) {
      final pushed = SyncService._serverIdIfPushed(
        food.serverId,
        food.syncStatus,
      );
      if (pushed == null) return null;
      foodItemId = pushed;
    }
    return {
      'date': meal.date.toUtc().toIso8601String(),
      'category': meal.category,
      'foodItemId': foodItemId,
    };
  }

  Future<void> _syncNewMeal(MealTableData meal) async {
    final body = await _mealBody(meal);
    if (body == null) return; // its food is not on the server yet
    final response = await _create(
      'api/Meal',
      {'id': meal.serverId, ...body},
      _db.mealTable,
      [meal.id],
    );
    if (response == null) return;
    final data = (response.data as Map).cast<String, dynamic>();
    final mealServerId = data['id'] as String;
    final serverEntries =
        (data['foodEntries'] as List? ?? []).cast<Map<String, dynamic>>();

    if (mealServerId != meal.serverId) {
      // The server keeps one meal per day and category, and already had this
      // one — another device's, or this device's before a reinstall — so it
      // answered with that meal.
      final merged = await _db.untracked(
        () => _mergeIntoServerMeal(meal, mealServerId, serverEntries),
      );
      if (!merged) return;
    } else {
      await _healBackfilledEntries(meal.id, serverEntries);
      // Out of `pending` the moment the server has it, before the foods: a
      // failure sending them must leave a meal that is on the server and
      // still dirty — never one that looks as if the server lacks it.
      await _markSent(_db.mealTable, meal.id, mealServerId, -1);
    }

    final complete = await _upsertMealFoods(meal.id, mealServerId);
    // A meal answered with another stays dirty whatever happened: the server
    // returned its own meal as it was, so this device's date, category and
    // food were never applied, and the next push PUTs them.
    if (complete && mealServerId == meal.serverId) {
      await _markSent(_db.mealTable, meal.id, mealServerId, meal.localRev);
    }
    _logger.i('Synced new meal ${meal.id} → server $mealServerId');
  }

  /// Makes [meal] the server's meal [mealServerId], which its create was
  /// answered with. Only this device's foods are then sent to it, each under
  /// its own id; the server's stay where they are, and come down with the
  /// first pull after this meal is clean again.
  ///
  /// If another row on this device is already that meal, this one's foods
  /// move to it and this row goes; that row is marked changed, so its push
  /// upserts them, and there is nothing left here to send (false). Otherwise
  /// this row takes the server's id and leaves `pending` in the same write —
  /// the server has it — as `pendingUpdate`, since the server has not seen
  /// its fields (true).
  ///
  /// This used to take the server meal's foods into the local one first, and
  /// then send the union as the meal's whole list. The union was only ever as
  /// complete as what this device could resolve: a food another device had
  /// just created, not yet pulled here, was left out, and the replace deleted
  /// it from the server.
  Future<bool> _mergeIntoServerMeal(
    MealTableData meal,
    String mealServerId,
    List<Map<String, dynamic>> serverEntries,
  ) async {
    // Before anything moves: an entry the migration gave an id may be one of
    // the server's already.
    await _healBackfilledEntries(meal.id, serverEntries);

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
      MealTableCompanion(
        serverId: Value(mealServerId),
        syncStatus: Value(SyncStatus.pendingUpdate.index),
      ),
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
      // Removed here, and the DELETE not sent yet.
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

  /// Gives each food of [localMealId] that the schema-42 migration minted an
  /// id for (`id_backfilled`) the id of the server's entry it already is, if
  /// the server has one, and clears the flag.
  ///
  /// This is legacy healing, and the one place a meal's foods are matched by
  /// content. It exists for one state an older build could leave behind: its
  /// foods batch committed on the server and the answer was lost, so the
  /// server's meal holds this device's entries under ids the device never
  /// heard, while the device's rows had none. The migration gave those rows
  /// fresh ids, and sent under them they would be stored a second time — a
  /// lunch of five foods became ten, which is the bug this rework began with.
  ///
  /// A flagged entry takes an unclaimed server entry of the same meal naming
  /// the same food item. The food item row is one logged portion (each add
  /// writes its own), so the same food item is the same food at the same
  /// quantity. Unclaimed means no row on this device holds that id already,
  /// no deletion of it is waiting to be sent, and no other flagged entry took
  /// it first — so two portions of one food each claim one server entry, and
  /// a server entry claims at most one local row.
  ///
  /// Why this doesn't break "a name, a position or a response index is not an
  /// identity": it never pairs two rows that each have an identity. A flagged
  /// row has none — its id was invented after the fact by the migration, and
  /// names nothing anywhere. The match adopts the only identity that row ever
  /// had, on the server, for rows the migration minted, once; the flag is
  /// cleared whether or not a match is found, so nothing logged since the
  /// migration, and nothing twice, is ever matched this way.
  Future<void> _healBackfilledEntries(
    int localMealId,
    List<Map<String, dynamic>> serverEntries,
  ) async {
    final flagged =
        (await _db.mealDao.getAllFoodEntriesForMeal(
          localMealId,
        )).where((e) => e.idBackfilled).toList();
    if (flagged.isEmpty) return;
    final deletedHere = {
      for (final d in await _db.select(_db.syncDeletionTable).get()) d.serverId,
    };
    final claimed = <String>{};
    await _db.untracked(() async {
      for (final entry in flagged) {
        final foodServerId = await _foodServerId(entry.foodEntryId);
        String? adopt;
        if (foodServerId != null) {
          for (final s in serverEntries) {
            final id = s['id'] as String;
            if (s['foodItemId'] != foodServerId ||
                claimed.contains(id) ||
                deletedHere.contains(id) ||
                await _db.mealDao.getFoodEntryByServerId(id) != null) {
              continue;
            }
            adopt = id;
            break;
          }
        }
        if (adopt != null) claimed.add(adopt);
        await (_db.update(_db.mealFoodTable)
          ..where((t) => t.id.equals(entry.id))).write(
          MealFoodTableCompanion(
            serverId: adopt == null ? const Value.absent() : Value(adopt),
            idBackfilled: const Value(false),
          ),
        );
      }
    });
    if (claimed.isNotEmpty) {
      _logger.i(
        'Meal $localMealId: ${claimed.length} food(s) the migration gave ids '
        'were already on the server; took the server\'s ids',
      );
    }
  }

  Future<void> _syncUpdateMeal(MealTableData meal) async {
    if (meal.serverId == null) {
      await _syncNewMeal(meal);
      return;
    }
    final body = await _mealBody(meal);
    if (body == null) return; // its food is not on the server yet
    // Only a meal the migration touched, and only once: its flagged foods are
    // matched against the server's before any of them is sent.
    if ((await _db.mealDao.getAllFoodEntriesForMeal(
      meal.id,
    )).any((e) => e.idBackfilled)) {
      final response = await _apiClient.get('api/Meal/${meal.serverId}');
      await _healBackfilledEntries(
        meal.id,
        ((response.data as Map)['foodEntries'] as List? ?? [])
            .cast<Map<String, dynamic>>(),
      );
    }
    await _apiClient.put('api/Meal/${meal.serverId}', data: body);
    // A food added to a meal the server has is what dirties the meal (the
    // database marks the owner), so this is the path that sends it.
    final complete = await _upsertMealFoods(meal.id, meal.serverId!);
    await _markSent(
      _db.mealTable,
      meal.id,
      meal.serverId!,
      complete ? meal.localRev : -1,
    );
    _logger.i('Updated meal ${meal.id} on server ${meal.serverId}');
  }

  /// Sends each food of a meal this device changed, under the id it was
  /// given when it was logged, for the server to store once in that meal.
  ///
  /// It is an upsert, one entry at a time: a food already stored under its id
  /// is that food again, and nothing the request doesn't name is touched. A
  /// food taken out of the meal is its own DELETE, which the database records
  /// when the row goes (`sync_triggers.dart`).
  ///
  /// For a while this sent the meal's whole list as a replace
  /// (`PUT api/Meal/{id}/foods`), which deleted whatever the list left out.
  /// A list this device builds can only name what this device holds — and it
  /// did not hold a food another device had added since its last pull, or one
  /// whose food item it couldn't resolve. Both were deleted from the server,
  /// and the next pull deleted them from the device that added them.
  ///
  /// A dangling entry — its food row gone from this device — is neither sent
  /// nor deleted: this device can't say what it is.
  ///
  /// Returns false when a food in the meal is not on the server yet: that
  /// one waits, and the meal is left dirty so it goes next push.
  Future<bool> _upsertMealFoods(int localMealId, String mealServerId) async {
    final entries = await _db.mealDao.getAllFoodEntriesForMeal(localMealId);
    final body = <Map<String, dynamic>>[];
    var complete = true;
    for (final entry in entries) {
      final food = await _db.foodItemDao.getFoodItemById(entry.foodEntryId);
      if (food == null) continue;
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
    if (body.isEmpty) return complete;
    try {
      await _apiClient.post('api/Meal/$mealServerId/foods/batch', data: body);
    } catch (e) {
      // One entry's id names a row that isn't this account's (409). That
      // entry, and only that one, takes a new id: the rest may be on the
      // server under theirs, and a new id would store them a second time.
      final refused = SyncService._refusedId(e);
      if (refused != null) {
        for (final entry in entries.where((x) => x.serverId == refused)) {
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

    final serverEntries =
        (m['foodEntries'] as List).cast<Map<String, dynamic>>();

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
          !SyncStatus.fromDb(unpushed.syncStatus).isOnServer) {
        // An entry the migration gave an id may be one of the server's.
        await _healBackfilledEntries(unpushed.id, serverEntries);
        // The server has this meal now, but not this device's foods or
        // fields: it stays changed, and its push sends them.
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
    // A meal with an unsent change may hold foods the server hasn't been sent
    // yet; taking out what the server doesn't list would take those too.
    if (SyncStatus.fromDb(existing.syncStatus) != SyncStatus.synced) return;

    // A clean meal holds nothing the server hasn't seen, so its list is the
    // server's to set: add what it has, and take out what it no longer lists.
    // This used to only add, which was enough while the push only ever sent
    // new foods. A dirty meal now sends every food it holds, so a food
    // removed on another device but left here would go back up with the next
    // edit to this meal.
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
