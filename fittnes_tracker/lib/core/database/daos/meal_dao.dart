import 'package:drift/drift.dart';
import '../../app_database.dart';

part 'meal_dao.g.dart';

@DriftAccessor(tables: [MealTable, MealFoodTable, FoodItem])
class MealDao extends DatabaseAccessor<AppDatabase> with _$MealDaoMixin {
  MealDao(super.db);

  Future<List<MealTableData>> getMealsForDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(mealTable)..where(
      (tbl) =>
          tbl.date.isBiggerOrEqualValue(start) &
          tbl.date.isSmallerThanValue(end),
    )).get();
  }

  Future<MealTableData?> getMealById(int id) {
    return (select(mealTable)
      ..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertMeal(Insertable<MealTableData> meal) {
    return into(mealTable).insert(meal);
  }

  Future<int> deleteMeal(Insertable<MealTableData> meal) {
    return delete(mealTable).delete(meal);
  }

  Future<int> addFoodToMeal(int foodId, int mealId, [String? serverId]) {
    return into(mealFoodTable).insert(
      MealFoodTableCompanion(
        mealId: Value(mealId),
        foodEntryId: Value(foodId),
        serverId: serverId != null ? Value(serverId) : const Value.absent(),
      ),
    );
  }

  Future<List<MealFoodTableData>> getFoodItemsForMeal(int mealId) {
    return (select(mealFoodTable)
      ..where((tbl) => tbl.mealId.equals(mealId))).get();
  }

  Future<int> deleteFoodFromMeal(int foodId, int mealId) {
    return (delete(mealFoodTable)..where(
      (tbl) => tbl.mealId.equals(mealId) & tbl.foodEntryId.equals(foodId),
    )).go();
  }

  // ── Sync helpers ────────────────────────────────────────────────────────────

  Future<List<MealTableData>> getUnsyncedMeals() =>
      (select(mealTable)..where((t) => t.syncStatus.isNotValue(1))).get();

  Future<void> markMealSynced({
    required int localId,
    required String serverId,
  }) => (update(mealTable)..where((t) => t.id.equals(localId))).write(
    MealTableCompanion(syncStatus: const Value(1), serverId: Value(serverId)),
  );

  Future<void> markMealPendingUpdate(int id) => (update(mealTable)..where(
    (t) => t.id.equals(id),
  )).write(const MealTableCompanion(syncStatus: Value(2)));

  Future<void> markMealPendingDelete(int id) => (update(mealTable)..where(
    (t) => t.id.equals(id),
  )).write(const MealTableCompanion(syncStatus: Value(3)));

  Future<List<MealFoodTableData>> getAllFoodEntriesForMeal(int mealId) =>
      (select(mealFoodTable)..where((t) => t.mealId.equals(mealId))).get();

  Future<void> setFoodEntryServerId(int entryId, String serverId) =>
      (update(mealFoodTable)..where(
        (t) => t.id.equals(entryId),
      )).write(MealFoodTableCompanion(serverId: Value(serverId)));

  Future<MealTableData?> getByServerId(String serverId) =>
      (select(mealTable)
            ..where((m) => m.serverId.equals(serverId))
            ..limit(1))
          .getSingleOrNull();

  Future<MealTableData?> getMealByDateAndCategory(
    DateTime date,
    String category,
  ) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(mealTable)
          ..where(
            (t) =>
                t.date.isBiggerOrEqualValue(start) &
                t.date.isSmallerThanValue(end) &
                t.category.equals(category),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<MealFoodTableData?> getFoodEntryByServerId(String serverId) =>
      (select(mealFoodTable)
            ..where((f) => f.serverId.equals(serverId))
            ..limit(1))
          .getSingleOrNull();

  /// Removes duplicate meal rows for the same date+category, keeping the one
  /// with a serverId (or lowest id). Re-parents food entries before deleting.
  Future<void> deduplicateMeals() async {
    final all =
        await (select(mealTable)
          ..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

    final Map<String, List<MealTableData>> groups = {};
    for (final meal in all) {
      final d = meal.date;
      final key = '${d.year}-${d.month}-${d.day}|${meal.category}';
      groups.putIfAbsent(key, () => []).add(meal);
    }

    for (final group in groups.values) {
      if (group.length <= 1) continue;
      final keeper = group.firstWhere(
        (m) => m.serverId != null,
        orElse: () => group.first,
      );
      for (final dupe in group) {
        if (dupe.id == keeper.id) continue;
        final dupeEntries = await getFoodItemsForMeal(dupe.id);
        final keeperEntries = await getFoodItemsForMeal(keeper.id);
        final keeperFoodIds = keeperEntries.map((e) => e.foodEntryId).toSet();
        for (final entry in dupeEntries) {
          if (!keeperFoodIds.contains(entry.foodEntryId)) {
            await (update(mealFoodTable)..where(
              (t) => t.id.equals(entry.id),
            )).write(MealFoodTableCompanion(mealId: Value(keeper.id)));
            keeperFoodIds.add(entry.foodEntryId);
          }
        }
        await (delete(mealTable)..where((t) => t.id.equals(dupe.id))).go();
      }
    }
  }
}
