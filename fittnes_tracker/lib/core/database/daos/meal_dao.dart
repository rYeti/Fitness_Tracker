import 'package:drift/drift.dart';
import '../../app_database.dart';

part 'meal_dao.g.dart';

/// One day's logged nutrition, totalled across every food in every meal.
class DailyIntake {
  final DateTime date;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;

  const DailyIntake({
    required this.date,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}

@DriftAccessor(tables: [MealTable, MealFoodTable, MealFoodDeletionTable, FoodItem])
class MealDao extends DatabaseAccessor<AppDatabase> with _$MealDaoMixin {
  MealDao(super.db);

  /// Daily intake totals between [start] and [end] (both inclusive, by day),
  /// with days that have no logged food omitted rather than returned as zero.
  ///
  /// The single source of truth for "what did this user eat". It exists
  /// because there were four separate implementations and they disagreed —
  /// most damagingly AdaptiveTdeeService, which joined `MealTable.foodItemId`
  /// and so counted only the *first* food of each meal, since that column is
  /// set once at meal creation while every later food goes to
  /// [MealFoodTable]. A three-item breakfast counted as one item.
  ///
  /// A meal contributes through its [MealFoodTable] rows only; `foodItemId` is
  /// vestigial for totalling and must not be summed.
  ///
  /// Duplicate meal rows for the same (date, category) would double-count
  /// here. The progress screen calls [deduplicateMeals] before reading; any
  /// new caller that cares about exactness should do the same.
  Future<List<DailyIntake>> getDailyIntake(DateTime start, DateTime end) async {
    final from = DateTime(start.year, start.month, start.day);
    final to = DateTime(end.year, end.month, end.day).add(const Duration(days: 1));

    final rows = await (select(mealTable).join([
      innerJoin(mealFoodTable, mealFoodTable.mealId.equalsExp(mealTable.id)),
      innerJoin(foodItem, foodItem.id.equalsExp(mealFoodTable.foodEntryId)),
    ])..where(
        mealTable.date.isBiggerOrEqualValue(from) &
            mealTable.date.isSmallerThanValue(to),
      )).get();

    final byDay = <DateTime, DailyIntake>{};
    for (final row in rows) {
      final meal = row.readTable(mealTable);
      final food = row.readTable(foodItem);
      final day = DateTime(meal.date.year, meal.date.month, meal.date.day);
      final running = byDay[day];
      byDay[day] = DailyIntake(
        date: day,
        calories: (running?.calories ?? 0) + food.calories,
        protein: (running?.protein ?? 0) + food.protein,
        carbs: (running?.carbs ?? 0) + food.carbs,
        fat: (running?.fat ?? 0) + food.fat,
      );
    }

    final days = byDay.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return days;
  }

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

  // ── Removals waiting to reach the server ────────────────────────────────────

  /// Records that a pushed food entry was removed from a meal, so the deletion
  /// survives the local row being gone. See [MealFoodDeletionTable].
  Future<int> queueFoodEntryDeletion({
    required String mealServerId,
    required String foodItemServerId,
  }) => into(mealFoodDeletionTable).insert(
    MealFoodDeletionTableCompanion.insert(
      mealServerId: mealServerId,
      foodItemServerId: foodItemServerId,
      createdAt: DateTime.now(),
    ),
  );

  /// Oldest first: a remove-then-re-add of the same food has to be pushed in
  /// the order the user did it, or the re-add is what gets deleted.
  Future<List<MealFoodDeletionTableData>> getPendingFoodEntryDeletions() =>
      (select(mealFoodDeletionTable)
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();

  /// The food ids still waiting to be deleted from [mealServerId], repeated once
  /// per queued deletion — the pull skips that many of the server's entries so
  /// it doesn't re-add a food the user has already removed.
  Future<List<String>> pendingFoodEntryDeletionsForMeal(String mealServerId) =>
      (select(mealFoodDeletionTable)
            ..where((t) => t.mealServerId.equals(mealServerId)))
          .get()
          .then((rows) => rows.map((r) => r.foodItemServerId).toList());

  Future<void> clearFoodEntryDeletion(int id) =>
      (delete(mealFoodDeletionTable)..where((t) => t.id.equals(id))).go();

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
