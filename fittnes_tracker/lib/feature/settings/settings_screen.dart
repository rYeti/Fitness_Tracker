import 'package:ForgeForm/core/providers/enums.dart';
import 'package:ForgeForm/core/providers/theme_provider.dart';
import 'package:ForgeForm/core/providers/user_goals_provider.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
          if (dbSex == 'male')
            _sex = Sex.male;
          else if (dbSex == 'female')
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
    final calorieGoalProvider = Provider.of<UserGoalsProvider>(context);
    if (!calorieGoalProvider.isLoaded) {
      return SafeArea(child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          title: Text(
            AppLocalizations.of(context)!.settings,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: Colors.white,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Provider.of<ThemeProvider>(context).themeMode == ThemeMode.light
                    ? Icons.dark_mode
                    : Icons.light_mode,
                color: Colors.white,
              ),
              onPressed:
                  () =>
                      Provider.of<ThemeProvider>(
                        context,
                        listen: false,
                      ).toggleTheme(),
            ),
          ],
        ),
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      ));
    }
    if (!_initialized) {
      _calorieGoalController.text = calorieGoalProvider.calorieGoal.toString();
      _initialized = true;
    }

    return SafeArea(child: Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.settings,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Provider.of<ThemeProvider>(context).themeMode == ThemeMode.light
                  ? Icons.dark_mode
                  : Icons.light_mode,
              color: Colors.white,
            ),
            onPressed:
                () =>
                    Provider.of<ThemeProvider>(
                      context,
                      listen: false,
                    ).toggleTheme(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: _fieldDecoration(AppLocalizations.of(context)!.nameLabel),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _fieldDecoration(AppLocalizations.of(context)!.age),
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return AppLocalizations.of(
                      context,
                    )!.pleaseEnterValidAgeAndHeight;
                  if ((int.tryParse(v.trim()) ?? 0) <= 0)
                    return AppLocalizations.of(
                      context,
                    )!.pleaseEnterValidAgeAndHeight;
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _fieldDecoration(
                  AppLocalizations.of(context)!.heightCm,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return AppLocalizations.of(
                      context,
                    )!.pleaseEnterValidAgeAndHeight;
                  if ((int.tryParse(v.trim()) ?? 0) <= 0)
                    return AppLocalizations.of(
                      context,
                    )!.pleaseEnterValidAgeAndHeight;
                  return null;
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<Sex>(
                value: _sex,
                decoration: _fieldDecoration(AppLocalizations.of(context)!.sex),
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
                decoration: _fieldDecoration(
                  AppLocalizations.of(context)!.activity,
                ),
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
                decoration: _fieldDecoration(
                  AppLocalizations.of(context)!.goal,
                ),
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
                decoration: _fieldDecoration(
                  AppLocalizations.of(context)!.dailyCalorieGoal,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return AppLocalizations.of(context)!.pleaseEnterValidNumber;
                  if (int.tryParse(v.trim()) == null)
                    return AppLocalizations.of(context)!.pleaseEnterValidNumber;
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _saveButton(
                label: AppLocalizations.of(context)!.calculateAndSave,
                onPressed: () async {
                  final age = int.tryParse(_ageController.text.trim());
                  final height = int.tryParse(_heightController.text.trim());
                  if (age == null || height == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter valid age and height'),
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
                        SnackBar(content: Text('Failed to save profile: $e')),
                      );
                  } finally {
                    if (mounted) setState(() => _isSaving = false);
                  }
                  if (!mounted) return;
                  _calorieGoalController.text = kcal.toString();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context)!.calculateAndSave,
                      ),
                    ),
                  );
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 10),
              _saveButton(
                label: AppLocalizations.of(context)!.save,
                onPressed: () async {
                  FocusScope.of(context).unfocus();
                  final text = _calorieGoalController.text.trim();
                  final newGoal = int.tryParse(text);
                  if (newGoal == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context)!.pleaseEnterValidNumber,
                        ),
                      ),
                    );
                    return;
                  }
                  setState(() => _isSaving = true);
                  var success = false;
                  try {
                    final age = int.tryParse(_ageController.text.trim());
                    final height = int.tryParse(_heightController.text.trim());
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
                          content: Text('Failed to update calorie goal: $e'),
                        ),
                      );
                  } finally {
                    if (mounted) setState(() => _isSaving = false);
                  }
                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context)!.saveCalorieGoal,
                        ),
                      ),
                    );
                    Navigator.pop(context);
                  }
                },
                secondary: true,
              ),
            ],
          ),
        ),
      ),
    ));
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
        backgroundColor: secondary
            ? colorScheme.onSurface.withValues(alpha: 0.07)
            : null,
        foregroundColor: secondary ? colorScheme.onSurface : null,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
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
