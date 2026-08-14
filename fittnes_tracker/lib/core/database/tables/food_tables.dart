import 'package:drift/drift.dart';

/// Sync state for a locally-stored food item.
enum FoodItemSyncStatus { pending, synced, pendingUpdate, pendingDelete }

class FoodItem extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get calories => integer()();
  IntColumn get protein => integer()();
  IntColumn get carbs => integer()();
  IntColumn get fat => integer()();
  IntColumn get gramm => integer().withDefault(const Constant(100))();
  BoolColumn get hiddenFromRecent =>
      boolean().withDefault(const Constant(false))();

  /// JSON-encoded [ExtendedNutrients]. Null for custom foods and any entry
  /// added before this column was introduced.
  TextColumn get extendedNutrientsJson => text().nullable()();

  /// Maps to [FoodItemSyncStatus] by index.
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  /// UUID assigned by the remote API after first successful sync.
  TextColumn get serverId => text().nullable()();

  /// OpenFoodFacts product code (barcode) — stored when a food is added from
  /// the online database so serving sizes can be re-fetched on edit.
  TextColumn get openFoodFactsId => text().nullable()();
}

class UserSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get dailyCalorieGoal =>
      integer().withDefault(const Constant(2000))();
  TextColumn get themeMode => text().withDefault(const Constant('light'))();
  // Profile fields
  TextColumn get name => text().withDefault(const Constant(''))();
  IntColumn get age => integer().withDefault(const Constant(30))();
  IntColumn get heightCm => integer().withDefault(const Constant(170))();
  TextColumn get sex => text().withDefault(const Constant('male'))();
  IntColumn get activityLevel => integer().withDefault(const Constant(1))();
  IntColumn get goalType => integer().withDefault(const Constant(1))();
  // Weight tracking fields
  RealColumn get startingWeight => real().withDefault(const Constant(80.0))();
  RealColumn get goalWeight => real().withDefault(const Constant(70.0))();
}

/// Sync state for a locally-stored meal.
enum MealSyncStatus { pending, synced, pendingUpdate, pendingDelete }

class MealTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get category => text()();
  IntColumn get foodItemId => integer()();

  /// Maps to [MealSyncStatus] by index.
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  /// UUID assigned by the remote API after first successful sync.
  TextColumn get serverId => text().nullable()();
}

class MealFoodTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get mealId => integer().references(MealTable, #id)();
  IntColumn get foodEntryId => integer().references(FoodItem, #id)();

  /// UUID of the MealFoodEntry on the server, used to delete specific entries.
  TextColumn get serverId => text().nullable()();
}

/// Curated verified foods (per-100g values) shown above crowdsourced search
/// results. Seeded from a bundled JSON asset; designed so a BLS 4.0 export
/// (blsdb.de) can be dropped in as the seed source without code changes.
/// Deliberately separate from [FoodItem]: never synced to the server, never
/// in the recent-foods list, and survives logout wipes.
class VerifiedFoodTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get nameDe => text().nullable()();
  IntColumn get calories => integer()();
  RealColumn get protein => real()();
  RealColumn get carbs => real()();
  RealColumn get fat => real()();

  /// Source key, e.g. the BLS SBLS code — kept for attribution/versioning.
  TextColumn get sourceCode => text().nullable()();
}

// Persistent search cache table
class SearchCacheTable extends Table {
  TextColumn get query => text()();
  TextColumn get json => text()(); // raw json array of products
  IntColumn get ts => integer()(); // epoch millis
  @override
  Set<Column> get primaryKey => {query};
}

class UserTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get username => text().unique()();
  TextColumn get email => text().unique()();
  TextColumn get passwordHash => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get profileImageUrl => text().nullable()();
  TextColumn get firstName => text().withDefault(const Constant(''))();
  TextColumn get lastName => text().withDefault(const Constant(''))();

  /// Stored as milliseconds since epoch (nullable — not required at registration time).
  DateTimeColumn get dateOfBirth => dateTime().nullable()();
}
