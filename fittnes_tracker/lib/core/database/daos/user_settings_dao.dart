import 'package:drift/drift.dart';
import '../../app_database.dart';

part 'user_settings_dao.g.dart';

@DriftAccessor(tables: [UserSettings])
class UserSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$UserSettingsDaoMixin {
  UserSettingsDao(super.db);

  Future<UserSetting?> getSettings() async {
    final rows = await (select(userSettings)..limit(1)).get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> setCalorieGoal(int goal) async {
    final settings = await getSettings();
    if (settings == null) {
      return into(
        userSettings,
      ).insert(UserSettingsCompanion.insert(dailyCalorieGoal: Value(goal)));
    } else {
      final success = await update(
        userSettings,
      ).replace(settings.copyWith(dailyCalorieGoal: goal));
      return success ? 1 : 0;
    }
  }

  // Update profile fields (name, age, heightCm, sex, activityLevel, goalType)
  Future<int> updateProfile({
    String? name,
    int? age,
    int? heightCm,
    String? sex,
    int? activityLevel,
    int? goalType,
    double? startingWeight,
    double? goalWeight,
  }) async {
    final settings = await getSettings();
    if (settings == null) {
      return into(userSettings).insert(
        UserSettingsCompanion.insert(
          dailyCalorieGoal: const Value(2000),
          name: Value(name ?? ''),
          age: Value(age ?? 30),
          heightCm: Value(heightCm ?? 170),
          sex: Value(sex ?? 'male'),
          activityLevel: Value(activityLevel ?? 1),
          goalType: Value(goalType ?? 1),
          startingWeight: Value(startingWeight ?? 80.0),
          goalWeight: Value(goalWeight ?? 70.0),
        ),
      );
    } else {
      final updated = settings.copyWith(
        name: name ?? settings.name,
        age: age ?? settings.age,
        heightCm: heightCm ?? settings.heightCm,
        sex: sex ?? settings.sex,
        activityLevel: activityLevel ?? settings.activityLevel,
        goalType: goalType ?? settings.goalType,
        startingWeight: startingWeight ?? settings.startingWeight,
        goalWeight: goalWeight ?? settings.goalWeight,
      );
      final success = await update(userSettings).replace(updated);
      return success ? 1 : 0;
    }
  }

  // Update weight goals specifically
  Future<int> updateWeightGoals({
    required double startingWeight,
    required double goalWeight,
  }) async {
    final settings = await getSettings();
    if (settings == null) {
      return into(userSettings).insert(
        UserSettingsCompanion.insert(
          dailyCalorieGoal: const Value(2000),
          startingWeight: Value(startingWeight),
          goalWeight: Value(goalWeight),
        ),
      );
    } else {
      await (update(userSettings)
        ..where((t) => t.id.equals(settings.id))).write(
        UserSettingsCompanion(
          startingWeight: Value(startingWeight),
          goalWeight: Value(goalWeight),
        ),
      );
      return 1;
    }
  }

  Future<void> updateThemeMode(String mode) async {
    final settings = await getSettings();
    if (settings == null) {
      await into(
        userSettings,
      ).insert(UserSettingsCompanion.insert(themeMode: Value(mode)));
    } else {
      await (update(userSettings)..where(
        (tbl) => tbl.id.equals(settings.id),
      )).write(settings.copyWith(themeMode: mode));
    }
  }
}
