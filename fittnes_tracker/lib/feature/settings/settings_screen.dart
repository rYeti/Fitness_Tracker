import 'dart:convert';

import 'package:ForgeForm/core/data_export/data_exporter.dart';
import 'package:ForgeForm/feature/auth/data/repositories/auth_repository.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ForgeForm/feature/auth/presentation/view/login_screen.dart'
    as auth_login;
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/dao/meal_template_dao.dart';
import 'package:ForgeForm/core/di/service_locator.dart';
import 'package:ForgeForm/core/network/api_client.dart';
import 'package:ForgeForm/core/network/services/sync_service.dart';
import 'package:ForgeForm/core/providers/access_provider.dart';
import 'package:ForgeForm/feature/auth/presentation/sign_out.dart';
import 'package:ForgeForm/feature/chat/presentation/view/chat_storage_screen.dart';
import 'package:ForgeForm/feature/chat/presentation/view/coach_chat_entry.dart';
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
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' hide Consumer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ForgeForm/feature/premium/paywall_launcher.dart';
import 'package:ForgeForm/feature/premium/premium_gate.dart';
import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/feature/trainer/presentation/view/join_trainer_screen.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/licence_screen.dart';
import 'package:ForgeForm/core/widgets/forge_app_bar.dart';
import 'package:ForgeForm/core/widgets/content_pane.dart';

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
  bool _isCalculating = false;
  bool _restTimerEnabled = true;
  // RPE logging is off by default and free for everyone (Hevy pattern:
  // hidden until the user opts in, never premium-gated).
  bool _rpeTrackingEnabled = false;
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
  bool _isRestoringPurchases = false;
  bool _isExporting = false;

  /// Builds an export via [build] and lets the user pick where to save it.
  /// Free for all users — data ownership is never behind the paywall.
  Future<void> _runExport(
    Future<String> Function(DataExporter exporter) build,
    String fileName,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isExporting = true);
    try {
      final content = await build(DataExporter(sl<AppDatabase>()));
      final savedPath = await FilePicker.platform.saveFile(
        fileName: fileName,
        bytes: Uint8List.fromList(utf8.encode(content)),
      );
      // null means the user cancelled the save dialog — not an error.
      if (savedPath != null) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.exportSaved)));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailed)));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String get _exportDateSuffix =>
      DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _runRestorePurchases() async {
    setState(() => _isRestoringPurchases = true);
    await restorePurchases(context);
    if (mounted) setState(() => _isRestoringPurchases = false);
  }

  Future<void> _runSync() async {
    final l10n = AppLocalizations.of(context)!;
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
      await prefs.setInt(
        'last_sync_timestamp',
        DateTime.now().millisecondsSinceEpoch,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.syncComplete)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.syncFailed(e))));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _runPull() async {
    final l10n = AppLocalizations.of(context)!;
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
      await prefs.setInt(
        lastPullPrefsKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      if (mounted) {
        globalFoodTrackingKey.currentState?.loadNutritionData();
        Provider.of<WeightProvider>(context, listen: false).reload();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.restoreComplete)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.restoreFailed(e))));
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
        _rpeTrackingEnabled = prefs.getBool('rpe_tracking_enabled') ?? false;
      });
    }
  }

  Future<void> _saveRestTimerPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rest_timer_enabled', value);
  }

  Future<void> _saveRpeTrackingPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rpe_tracking_enabled', value);
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
    final hasPremium = context.watch<AccessProvider>().hasPremiumAccess;
    final isTrainer = context.watch<AccessProvider>().isTrainer;
    final isTrainerClient = context.watch<AccessProvider>().isTrainerClient;

    if (!calorieGoalProvider.isLoaded) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: ForgeAppBar(title: l10n.settings),
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    if (!_initialized) {
      _calorieGoalController.text = calorieGoalProvider.calorieGoal.toString();
      _initialized = true;
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: ForgeAppBar(title: l10n.settings),
      body: ContentPane(
        child: SingleChildScrollView(
          // Bottom padding is not symmetric with the top: the last field ends
          // at the bottom navigation bar, and 8px of clearance reads as the
          // field being clipped by it.
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Premium banner ────────────────────────────────────────
                if (!hasPremium) ...[
                  _GoPremiumBanner(),
                  const SizedBox(height: 16),
                ],

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

                // ── Your coach ────────────────────────────────────────────
                // Chat lives here rather than in the bottom bar: that bar is
                // `type: fixed` with five items already, and a sixth crowds it
                // badly on a phone.
                if (isTrainerClient) ...[
                  const SizedBox(height: 12),
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
                          Icons.forum_outlined,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(l10n.coachChat),
                      subtitle: Text(l10n.coachChatSubtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const CoachChatEntry(),
                            ),
                          ),
                    ),
                  ),
                ],

                // ── Trainer Console ───────────────────────────────────────
                // Only trainers see this; the route's gate re-checks the role
                // anyway, so this is discovery rather than enforcement.
                if (isTrainer) ...[
                  const SizedBox(height: 12),
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
                          Icons.groups_outlined,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(l10n.trainerConsole),
                      subtitle: Text(l10n.trainerConsoleSubtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/trainer-console'),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                          Icons.workspace_premium_outlined,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(l10n.yourPlan),
                      subtitle: Text(l10n.yourPlanSubtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const LicenceScreen(),
                            ),
                          ),
                    ),
                  ),
                ],

                // ── Joining a trainer ─────────────────────────────────────
                // There is deliberately no "become a trainer" entry here. That
                // card used to open the plan screen, whose load provisioned a
                // Free licence — so an ordinary user tapping it once became a
                // permanent trainer. Trainer is now an account type chosen at
                // registration, and an existing account can't convert.
                if (!isTrainerClient) ...[
                  const SizedBox(height: 12),
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
                          Icons.link,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(l10n.joinATrainer),
                      subtitle: Text(l10n.joinATrainerSubtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const JoinTrainerScreen(),
                            ),
                          ),
                    ),
                  ),
                ],

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
                    if (v == null || v.trim().isEmpty) {
                      return l10n.pleaseEnterValidNumber;
                    }
                    if (int.tryParse(v.trim()) == null) {
                      return l10n.pleaseEnterValidNumber;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _saveButton(
                  label: l10n.calculateAndSave,
                  isLoading: _isCalculating,
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
                    setState(() => _isCalculating = true);
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
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.failedToSaveProfile(e))),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isCalculating = false);
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
                  isLoading: _isSaving,
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
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.failedToUpdateCalorieGoal(e)),
                          ),
                        );
                      }
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
                _SectionLabel(l10n.appearance),
                Card(
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
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
                          onChanged:
                              (code) => localeProvider.setLocale(
                                code == null ? null : Locale(code),
                              ),
                        ),
                      ),
                      Divider(height: 1, indent: 16, endIndent: 16),
                      PremiumGate(
                        child: SwitchListTile(
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
                      ),
                      Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        secondary: Icon(
                          Icons.speed,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        title: Text(l10n.rpeTrackingSetting),
                        subtitle: Text(l10n.rpeTrackingSettingSubtitle),
                        value: _rpeTrackingEnabled,
                        onChanged: (value) {
                          setState(() => _rpeTrackingEnabled = value);
                          _saveRpeTrackingPreference(value);
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Sync ──────────────────────────────────────────────────
                _SectionLabel(l10n.syncSectionLabel),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: ListTile(
                    leading:
                        _isSyncing
                            ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.primary,
                              ),
                            )
                            : Icon(
                              Icons.sync,
                              color: colorScheme.onSurfaceVariant,
                            ),
                    title: Text(l10n.syncNow),
                    subtitle: Text(l10n.syncNowSubtitle),
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
                    leading:
                        _isPulling
                            ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.primary,
                              ),
                            )
                            : Icon(
                              Icons.cloud_download_outlined,
                              color: colorScheme.onSurfaceVariant,
                            ),
                    title: Text(l10n.restoreFromServer),
                    subtitle: Text(l10n.restoreFromServerSubtitle),
                    onTap: _isPulling ? null : _runPull,
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
                    leading:
                        _isRestoringPurchases
                            ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.primary,
                              ),
                            )
                            : Icon(
                              Icons.shopping_bag_outlined,
                              color: colorScheme.onSurfaceVariant,
                            ),
                    title: Text(l10n.paywallRestorePurchases),
                    onTap: _isRestoringPurchases ? null : _runRestorePurchases,
                  ),
                ),

                const SizedBox(height: 16),

                // ── Data export (free for everyone) ───────────────────────
                _SectionLabel(l10n.exportSectionLabel),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.fitness_center,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        title: Text(l10n.exportWorkoutsCsv),
                        onTap:
                            _isExporting
                                ? null
                                : () => _runExport(
                                  (e) => e.exportWorkoutsCsv(),
                                  'forgeform_workouts_$_exportDateSuffix.csv',
                                ),
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.monitor_weight_outlined,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        title: Text(l10n.exportWeightCsv),
                        onTap:
                            _isExporting
                                ? null
                                : () => _runExport(
                                  (e) => e.exportWeightCsv(),
                                  'forgeform_weight_$_exportDateSuffix.csv',
                                ),
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.restaurant_outlined,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        title: Text(l10n.exportNutritionCsv),
                        onTap:
                            _isExporting
                                ? null
                                : () => _runExport(
                                  (e) => e.exportNutritionCsv(),
                                  'forgeform_nutrition_$_exportDateSuffix.csv',
                                ),
                      ),
                      ListTile(
                        leading:
                            _isExporting
                                ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.primary,
                                  ),
                                )
                                : Icon(
                                  Icons.data_object,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                        title: Text(l10n.exportFullJson),
                        subtitle: Text(l10n.exportFullJsonHint),
                        onTap:
                            _isExporting
                                ? null
                                : () => _runExport(
                                  (e) => e.exportFullJson(),
                                  'forgeform_backup_$_exportDateSuffix.json',
                                ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Chat storage ──────────────────────────────────────────
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.storage_outlined,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    title: Text(l10n.chatStorageTitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const ChatStorageScreen(),
                          ),
                        ),
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
                          final signedOut = await confirmAndSignOut(
                            context,
                            ref,
                          );
                          if (signedOut && context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const auth_login.LoginScreen(),
                              ),
                              (_) => false,
                            );
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
                        leading: Icon(
                          Icons.delete_forever,
                          color: colorScheme.error,
                        ),
                        title: Text(
                          l10n.deleteAccount,
                          style: TextStyle(color: colorScheme.error),
                        ),
                        onTap: () async {
                          final passwordController = TextEditingController();
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder:
                                (_) => AlertDialog(
                                  title: Text(l10n.deleteAccount),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      onPressed:
                                          () => Navigator.pop(context, false),
                                      child: Text(l10n.cancel),
                                    ),
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(context, true),
                                      style: TextButton.styleFrom(
                                        foregroundColor: colorScheme.error,
                                      ),
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
                              final repo = AuthRepository(
                                ApiClient(baseUrl: serverUrl),
                              );
                              await repo.deleteAccount(
                                token: token,
                                password: passwordController.text,
                              );
                              await access.reset();
                              await ref.read(authProvider.notifier).logout();
                              if (context.mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder:
                                        (_) => const auth_login.LoginScreen(),
                                  ),
                                  (_) => false,
                                );
                              }
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.deleteAccountError),
                                  ),
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
                    onTap:
                        () => launchUrl(
                          Uri.parse('https://forgefrom.netlify.app/'),
                        ),
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

                const SizedBox(height: 8),

                Center(
                  child: GestureDetector(
                    onTap:
                        () => launchUrl(
                          Uri.parse(
                            'https://forgefrom.netlify.app/privacy-policy',
                          ),
                          mode: LaunchMode.externalApplication,
                        ),
                    child: Text(
                      'Privacy Policy',
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
    required bool isLoading,
    bool secondary = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        backgroundColor:
            secondary ? colorScheme.onSurface.withValues(alpha: 0.07) : null,
        foregroundColor: secondary ? colorScheme.onSurface : null,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
      child:
          isLoading
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

class _GoPremiumBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.onInverseSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.bolt, color: colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.goPremiumBannerTitle,
                  style: TextStyle(
                    color: colorScheme.onInverseSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppLocalizations.of(context)!.goPremiumBannerSubtitle,
                  style: TextStyle(
                    color: colorScheme.onInverseSurface.withValues(alpha: 0.70),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: () => openPaywall(context),
            style: FilledButton.styleFrom(
              backgroundColor: ForgeColors.forgeOrange,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            child: Text(AppLocalizations.of(context)!.goPremiumBannerButton),
          ),
        ],
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
