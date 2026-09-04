import 'package:drift/drift.dart';
import '../../app_database.dart';

part 'food_item_dao.g.dart';

@DriftAccessor(tables: [FoodItem])
class FoodItemDao extends DatabaseAccessor<AppDatabase>
    with _$FoodItemDaoMixin {
  FoodItemDao(super.db);

  /// Stream the most recent food items, ordered by id descending, limited by [limit].
  Stream<List<FoodItemData>> watchRecentFoodItems(int limit) {
    return (select(foodItem)
          ..orderBy([
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .watch();
  }

  Future<List<FoodItemData>> getAllFoodItems() => select(foodItem).get();

  Stream<List<FoodItemData>> watchAllFoodItems() => select(foodItem).watch();

  /// Stream only items not hidden from the recently-added list.
  Stream<List<FoodItemData>> watchVisibleFoodItems() =>
      (select(foodItem)
        ..where((t) => t.hiddenFromRecent.equals(false))).watch();

  /// Mark all food items with [name] as hidden from the recently-added list.
  Future<void> hideFromRecent(String name) async {
    await (update(foodItem)..where(
      (t) => t.name.lower().equals(name.toLowerCase().trim()),
    )).write(const FoodItemCompanion(hiddenFromRecent: Value(true)));
  }

  Future<int> insertFoodItem(Insertable<FoodItemData> item) =>
      into(foodItem).insert(item);

  Future<int> deleteFoodItem(Insertable<FoodItemData> item) =>
      delete(foodItem).delete(item);

  Future<FoodItemData?> getFoodItemById(int id) async {
    return (select(foodItem)
      ..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// [extendedNutrientsJson] defaults to leaving the column untouched
  /// (`Value.absent()`) — most callers only ever touch macros/weight and
  /// have no micronutrient data to say anything about. A caller that *does*
  /// have a rescaled blob for the new weight must pass it explicitly: an
  /// edit that changes [gramm] but leaves this absent silently leaves the
  /// food's micronutrients scaled to its old weight. See
  /// `docs/trainer-console-micronutrients.md`.
  Future<void> updateFoodItem(
    int id, {
    required int calories,
    required int protein,
    required int carbs,
    required int fat,
    required int gramm,
    Value<String?> extendedNutrientsJson = const Value.absent(),
  }) async {
    await (update(foodItem)..where((t) => t.id.equals(id))).write(
      FoodItemCompanion(
        calories: Value(calories),
        protein: Value(protein),
        carbs: Value(carbs),
        fat: Value(fat),
        gramm: Value(gramm),
        extendedNutrientsJson: extendedNutrientsJson,
        syncStatus: const Value(2), // pendingUpdate
      ),
    );
  }

  // ── Sync helpers ────────────────────────────────────────────────────────────

  Future<int> countCustomFoodItems() async {
    final items =
        await (select(foodItem)..where(
          (t) => t.serverId.isNull() & t.extendedNutrientsJson.isNull(),
        )).get();
    return items.length;
  }

  Future<List<FoodItemData>> getUnsyncedItems() =>
      (select(foodItem)
        ..where((t) => t.syncStatus.isNotValue(1))).get(); // not synced

  Future<void> markSynced({required int localId, required String serverId}) =>
      (update(foodItem)..where((t) => t.id.equals(localId))).write(
        FoodItemCompanion(
          syncStatus: const Value(1), // synced
          serverId: Value(serverId),
        ),
      );

  Future<void> markPendingDelete(int id) =>
      (update(foodItem)..where((t) => t.id.equals(id))).write(
        const FoodItemCompanion(syncStatus: Value(3)), // pendingDelete
      );

  Future<void> deleteById(int id) =>
      (delete(foodItem)..where((t) => t.id.equals(id))).go();

  Future<FoodItemData?> getByServerId(String serverId) =>
      (select(foodItem)
            ..where((f) => f.serverId.equals(serverId))
            ..limit(1))
          .getSingleOrNull();
}
