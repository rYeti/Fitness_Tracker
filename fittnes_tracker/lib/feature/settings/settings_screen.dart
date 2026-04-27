import 'package:ForgeForm/feature/auth/data/repositories/auth_repository.dart';
import 'package:ForgeForm/feature/auth/presentation/view/login_screen.dart' as auth_login;
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/dao/meal_template_dao.dart';
import 'package:ForgeForm/core/di/service_locator.dart';
import 'package:ForgeForm/core/network/api_client.dart';
import 'package:ForgeForm/core/network/services/sync_service.dart';
import 'package:ForgeForm/core/providers/access_provider.dart';
import 'package:ForgeForm/core/providers/enums.dart';
import 'package:ForgeForm/core/providers/theme_provider.dart';
import 'package:ForgeForm/core/providers/locale_provider.dart';
import 'package:ForgeForm/core/providers/user_goals_provider.dart';
import 'package:ForgeForm/feature/auth/presentation/providers/auth_provider.dart';
import 'package:ForgeForm/feature/auth/presentation/view/user_settings_screen.dart';
import 'package:ForgeForm/feature/food_tracking/presentation/view/food_tracking_screen.dart';
import 'package:ForgeForm/feature/gym_tracking/presentation/view/exercises/exercise_management_screen.dart';
import 'package:ForgeForm/feature/weight_tracking/presentation/providers/weight_provider.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart' hide Consumer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

extension SexLocalizations on Sex {
  String localized(BuildContext ctx) {
    final loc = AppLocalizations.of(ctx)!;
    switch (this) {
      case Sex.male:
        return loc.male;
      case Sex.female:
        return loc.female;
      case Sex.other:
        return loc.other;
    }
  }
}

extension ActivityLevelLocalizations on ActivityLevel {
  String localized(BuildContext ctx) {
    final loc = AppLocalizations.of(ctx)!;
    switch (this) {
      case ActivityLevel.sedentary:
        return loc.sedentary;
      case ActivityLevel.lightlyActive:
        return loc.lightlyActive;
      case ActivityLevel.moderatelyActive:
        return loc.moderatelyActive;
      case ActivityLevel.veryActive:
        return loc.veryActive;
      case ActivityLevel.extremelyActive:
        return loc.extremelyActive;
    }
  }
}

extension GoalTypeLocalizations on GoalType {
  String localized(BuildContext ctx) {
    final loc = AppLocalizations.of(ctx)!;
    switch (this) {
      case GoalType.weightLoss:
        return loc.weightLoss;
      case GoalType.muscleGain:
        return loc.muscleGain;
      case GoalType.maintenance:
        return loc.maintenance;
    }
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _calorieGoalController = TextEditingController();
  bool _initialized = false;
  bool _isSaving = false;
  bool _restTimerEnabled = true;
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  Sex _sex = Sex.male;
  ActivityLevel _activity = ActivityLevel.sedentary;
  GoalType _goalType = GoalType.maintenance;

  @override
  void dispose() {
    _nameController.dispose();
    _calorieGoalController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfileFromDb());
    _loadRestTimerPreference();
  }

  bool _isSyncing = false;
  bool _isPulling = false;

  Future<void> _runSync() async {
    setState(() => _isSyncing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverUrl = prefs.getString(serverUrlPrefsKey) ?? serverUrlDefault;
      final db = sl<AppDatabase>();
      final syncService = SyncService(
        db: db,
        apiClient: ApiClient(baseUrl: serverUrl),
        mealTemplateDao: MealTemplateDao(db),
      );
      await syncService.syncAll();
      await prefs.setInt('last_sync_timestamp', DateTime.now().millisecondsSinceEpoch);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync complete')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _runPull() async {
    setState(() => _isPulling = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverUrl = prefs.getString(serverUrlPrefsKey) ?? serverUrlDefault;
      final db = sl<AppDatabase>();
      final syncService = SyncService(
        db: db,
        apiClient: ApiClient(baseUrl: serverUrl),
        mealTemplateDao: MealTemplateDao(db),
      );
      await syncService.pullAll();
      if (mounted) {
        globalFoodTrackingKey.currentState?.loadNutritionData();
        Provider.of<WeightProvider>(context, listen: false).reload();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restore complete')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPulling = false);
    }
  }

  Future<void> _loadRestTimerPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _restTimerEnabled = prefs.getBool('rest_timer_enabled') ?? true;
      });
    }
  }

  Future<void> _saveRestTimerPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rest_timer_enabled', value);
  }

  Future<void> _loadProfileFromDb() async {
    try {
      final provider = Provider.of<UserGoalsProvider>(context, listen: false);
      final settings = await provider.db.userSettingsDao.getSettings();
      if (settings != null) {
        setState(() {
          _nameController.text = settings.name;
          _ageController.text = settings.age.toString();
          _heightController.text = settings.heightCm.toString();
          final dbSex = settings.sex.toLowerCase();
          if (dbSex == 'male') {
            _sex = Sex.male;
          } else if (dbSex == 'female')
            _sex = Sex.female;
          else
            _sex = Sex.other;
          final activityIndex = settings.activityLevel;
          if (activityIndex >= 0 && activityIndex < ActivityLevel.values.length)
            _activity = ActivityLevel.values[activityIndex];
          final goalIndex = settings.goalType;
          if (goalIndex >= 0 && goalIndex < GoalType.values.length)
            _goalType = GoalType.values[goalIndex];
          if (provider.isLoaded) {
            _calorieGoalController.text = provider.calorieGoal.toString();
            _initialized = true;
          }
        });
      }
    } catch (_) {}
  }

  InputDecoration _fieldDecoration(String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: colorScheme.onSurface.withValues(alpha: 0.07),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(
          color: colorScheme.onSurface.withValues(alpha: 0.10),
          width: 0.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(
          color: colorScheme.onSurface.withValues(alpha: 0.10),
          width: 0.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: colorScheme.primary, width: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final calorieGoalProvider = Provider.of<UserGoalsProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;
    final localeProvider = Provider.of<LocaleProvider>(context);

    if (!calorieGoalProvider.isLoaded) {
      return SafeArea(
        child: Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: AppBar(
            title: Text(
              l10n.settings,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: Colors.white,
              ),
            ),
          ),
          body: Center(
            child: CircularProgressIndicator(color: colorScheme.primary),
          ),
        ),
      );
    }

    if (!_initialized) {
      _calorieGoalController.text = calorieGoalProvider.calorieGoal.toString();
      _initialized = true;
    }

    return SafeArea(
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          title: Text(
            l10n.settings,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: Colors.white,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Account ───────────────────────────────────────────────
                _SectionLabel(l10n.accountSettings),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(
                        Icons.person_outline,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(l10n.accountSettings),
                    subtitle: Text('${l10n.profile} · ${l10n.security}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const UserSettingsScreen(),
                          ),
                        ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Training ──────────────────────────────────────────────
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(
                        Icons.fitness_center,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(l10n.exercises),
                    subtitle: Text(l10n.exercisesSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ExerciseManagementScreen(),
                          ),
                        ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Fitness Profile ───────────────────────────────────────
                _SectionLabel(l10n.profile),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: _fieldDecoration(l10n.nameLabel),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _fieldDecoration(l10n.age),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return l10n.pleaseEnterValidAgeAndHeight;
                    if ((int.tryParse(v.trim()) ?? 0) <= 0)
                      return l10n.pleaseEnterValidAgeAndHeight;
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _fieldDecoration(l10n.heightCm),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return l10n.pleaseEnterValidAgeAndHeight;
                    if ((int.tryParse(v.trim()) ?? 0) <= 0)
                      return l10n.pleaseEnterValidAgeAndHeight;
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<Sex>(
                  value: _sex,
                  decoration: _fieldDecoration(l10n.sex),
                  items:
                      Sex.values
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.localized(context)),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _sex = v ?? Sex.male),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<ActivityLevel>(
                  value: _activity,
                  decoration: _fieldDecoration(l10n.activity),
                  items:
                      ActivityLevel.values
                          .map(
                            (a) => DropdownMenuItem(
                              value: a,
                              child: Text(a.localized(context)),
                            ),
                          )
                          .toList(),
                  onChanged:
                      (v) => setState(
                        () => _activity = v ?? ActivityLevel.sedentary,
                      ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<GoalType>(
                  value: _goalType,
                  decoration: _fieldDecoration(l10n.goal),
                  items:
                      GoalType.values
                          .map(
                            (g) => DropdownMenuItem(
                              value: g,
                              child: Text(g.localized(context)),
                            ),
                          )
                          .toList(),
                  onChanged:
                      (v) =>
                          setState(() => _goalType = v ?? GoalType.maintenance),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _calorieGoalController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _fieldDecoration(l10n.dailyCalorieGoal),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return l10n.pleaseEnterValidNumber;
                    if (int.tryParse(v.trim()) == null)
                      return l10n.pleaseEnterValidNumber;
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _saveButton(
                  label: l10n.calculateAndSave,
                  onPressed: () async {
                    final age = int.tryParse(_ageController.text.trim());
                    final height = int.tryParse(_heightController.text.trim());
                    if (age == null || height == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.pleaseEnterValidAgeAndHeight),
                        ),
                      );
                      return;
                    }
                    setState(() => _isSaving = true);
                    final provider = Provider.of<UserGoalsProvider>(
                      context,
                      listen: false,
                    );
                    final weightKg = provider.currentWeight;
                    final kcal = provider.calculateCalorieTarget(
                      sex: _sex,
                      age: age,
                      heightCm: height.toDouble(),
                      weightKg: weightKg,
                      activity: _activity,
                      goal: _goalType,
                    );
                    try {
                      await provider.db.userSettingsDao.updateProfile(
                        name: _nameController.text.trim(),
                        age: age,
                        heightCm: height,
                        sex: _sex.name,
                        activityLevel: ActivityLevel.values.indexOf(_activity),
                        goalType: GoalType.values.indexOf(_goalType),
                      );
                      await provider.saveCalorieGoal(kcal);
                    } catch (e) {
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.failedToSaveProfile(e))),
                        );
                    } finally {
                      if (mounted) setState(() => _isSaving = false);
                    }
                    if (!mounted) return;
                    _calorieGoalController.text = kcal.toString();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.calculateAndSave)),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _saveButton(
                  label: l10n.save,
                  onPressed: () async {
                    FocusScope.of(context).unfocus();
                    final text = _calorieGoalController.text.trim();
                    final newGoal = int.tryParse(text);
                    if (newGoal == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.pleaseEnterValidNumber)),
                      );
                      return;
                    }
                    setState(() => _isSaving = true);
                    var success = false;
                    try {
                      final age = int.tryParse(_ageController.text.trim());
                      final height = int.tryParse(
                        _heightController.text.trim(),
                      );
                      if (age != null && height != null) {
                        await calorieGoalProvider.db.userSettingsDao
                            .updateProfile(
                              name: _nameController.text.trim(),
                              age: age,
                              heightCm: height,
                              sex: _sex.name,
                              activityLevel: ActivityLevel.values.indexOf(
                                _activity,
                              ),
                              goalType: GoalType.values.indexOf(_goalType),
                            );
                      }
                      await calorieGoalProvider.saveCalorieGoal(newGoal);
                      success = true;
                    } catch (e) {
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.failedToUpdateCalorieGoal(e)),
                          ),
                        );
                    } finally {
                      if (mounted) setState(() => _isSaving = false);
                    }
                    if (success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.saveCalorieGoal)),
                      );
                    }
                  },
                  secondary: true,
                ),

                const SizedBox(height: 24),

                // ── Appearance ────────────────────────────────────────────
                _SectionLabel(l10n.settings),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: Icon(
                          isDark ? Icons.dark_mode : Icons.light_mode,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        title: Text(isDark ? l10n.darkMode : l10n.lightMode),
                        value: isDark,
                        onChanged: (_) => themeProvider.toggleTheme(),
                      ),
                      Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: Icon(
                          Icons.language,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        title: Text(l10n.language),
                        trailing: DropdownButton<String?>(
                          value: localeProvider.locale?.languageCode,
                          underline: const SizedBox(),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(l10n.languageSystem),
                            ),
                            DropdownMenuItem(
                              value: 'en',
                              child: Text(l10n.languageEnglish),
                            ),
                            DropdownMenuItem(
                              value: 'de',
                              child: Text(l10n.languageGerman),
                            ),
                          ],
                          onChanged: (code) => localeProvider.setLocale(
                            code == null ? null : Locale(code),
                          ),
                        ),
                      ),
                      Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        secondary: Icon(
                          Icons.timer_outlined,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        title: Text(l10n.restTimerSetting),
                        subtitle: Text(l10n.restTimerSettingSubtitle),
                        value: _restTimerEnabled,
                        onChanged: (value) {
                          setState(() => _restTimerEnabled = value);
                          _saveRestTimerPreference(value);
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Sync ──────────────────────────────────────────────────
                _SectionLabel('Sync'),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: ListTile(
                    leading: _isSyncing
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary,
                            ),
                          )
                        : Icon(Icons.sync, color: colorScheme.onSurfaceVariant),
                    title: const Text('Sync now'),
                    subtitle: const Text('Push all pending local changes to the server'),
                    onTap: _isSyncing ? null : _runSync,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: ListTile(
                    leading: _isPulling
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary,
                            ),
                          )
                        : Icon(Icons.cloud_download_outlined, color: colorScheme.onSurfaceVariant),
                    title: const Text('Restore from server'),
                    subtitle: const Text('Download server data to this device'),
                    onTap: _isPulling ? null : _runPull,
                  ),
                ),

                const SizedBox(height: 16),

                // ── Account actions ───────────────────────────────────────
                Consumer(
                  builder: (context, ref, _) {
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      child: ListTile(
                        leading: Icon(Icons.logout, color: colorScheme.error),
                        title: Text(
                          l10n.signOut,
                          style: TextStyle(color: colorScheme.error),
                        ),
                        onTap: () async {
                          final access = context.read<AccessProvider>();
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text(l10n.signOut),
                              content: Text(l10n.signOutConfirm),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: Text(l10n.cancel),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text(l10n.signOut),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await access.reset();
                            await ref.read(authProvider.notifier).logout();
                            if (context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const auth_login.LoginScreen(),
                                ),
                                (_) => false,
                              );
                            }
                          }
                        },
                      ),
                    );
                  },
                ),

                const SizedBox(height: 8),

                // ── Delete account ────────────────────────────────────────
                Consumer(
                  builder: (context, ref, _) {
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      child: ListTile(
                        leading: Icon(Icons.delete_forever, color: colorScheme.error),
                        title: Text(
                          l10n.deleteAccount,
                          style: TextStyle(color: colorScheme.error),
                        ),
                        onTap: () async {
                          final passwordController = TextEditingController();
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text(l10n.deleteAccount),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l10n.deleteAccountWarning),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: passwordController,
                                    obscureText: true,
                                    decoration: InputDecoration(
                                      labelText: l10n.password,
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: Text(l10n.cancel),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                                  child: Text(l10n.deleteAccount),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true && context.mounted) {
                            final token = ref.read(authProvider).user?.token;
                            if (token == null) return;
                            final access = context.read<AccessProvider>();
                            try {
                              final serverUrl = ref.read(serverUrlProvider);
                              final repo = AuthRepository(ApiClient(baseUrl: serverUrl));
                              await repo.deleteAccount(token: token, password: passwordController.text);
                              await access.reset();
                              await ref.read(authProvider.notifier).logout();
                              if (context.mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (_) => const auth_login.LoginScreen()),
                                  (_) => false,
                                );
                              }
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(l10n.deleteAccountError)),
                                );
                              }
                            }
                          }
                        },
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                Center(
                  child: GestureDetector(
                    onTap: () => launchUrl(Uri.parse('https://forgefrom.netlify.app/')),
                    child: Text(
                      'forgefrom.netlify.app',
                      style: TextStyle(
                        fontFamily: 'Exo 2',
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _saveButton({
    required String label,
    required VoidCallback onPressed,
    bool secondary = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ElevatedButton(
      onPressed: _isSaving ? null : onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        backgroundColor:
            secondary ? colorScheme.onSurface.withValues(alpha: 0.07) : null,
        foregroundColor: secondary ? colorScheme.onSurface : null,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
      child:
          _isSaving
              ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
              : Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Exo 2',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
