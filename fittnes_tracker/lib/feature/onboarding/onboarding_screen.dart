import 'package:ForgeForm/core/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:ForgeForm/core/providers/enums.dart';
import 'package:ForgeForm/core/providers/user_goals_provider.dart';
import 'package:ForgeForm/feature/auth/presentation/view/login_screen.dart';
import 'package:ForgeForm/feature/settings/settings_screen.dart'
    show ActivityLevelLocalizations, GoalTypeLocalizations, SexLocalizations;
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Shared input decoration helper ────────────────────────────────────────────

InputDecoration onboardingFieldDecoration(BuildContext context, String label) {
  final cs = Theme.of(context).colorScheme;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(
      color: cs.onSurface.withValues(alpha: 0.10),
      width: 0.5,
    ),
  );
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: cs.onSurface.withValues(alpha: 0.07),
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: cs.primary, width: 1),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );
}

// ── Main OnboardingScreen ─────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 4;
  bool _isSaving = false;

  // Page 2 — Profile
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  Sex _sex = Sex.male;

  // Page 3 — Goals & Weight
  ActivityLevel _activity = ActivityLevel.moderatelyActive;
  GoalType _goalType = GoalType.maintenance;
  final _currentWeightController = TextEditingController();
  final _goalWeightController = TextEditingController();

  // Page 4 — Summary
  int _calculatedCalories = 2000;
  late final TextEditingController _calorieController;

  @override
  void initState() {
    super.initState();
    _calorieController = TextEditingController(text: '2000');
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _currentWeightController.dispose();
    _goalWeightController.dispose();
    _calorieController.dispose();
    super.dispose();
  }

  void _recalculate() {
    final age = int.tryParse(_ageController.text.trim()) ?? 0;
    final height = double.tryParse(_heightController.text.trim()) ?? 0;
    final weight = double.tryParse(_currentWeightController.text.trim()) ?? 70;
    if (age > 0 && height > 0) {
      final kcal = context.read<UserGoalsProvider>().calculateCalorieTarget(
        sex: _sex,
        age: age,
        heightCm: height,
        weightKg: weight,
        activity: _activity,
        goal: _goalType,
      );
      setState(() => _calculatedCalories = kcal);
      _calorieController.text = kcal.toString();
    }
  }

  void _nextPage() {
    if (_currentPage == 2) _recalculate();
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _prevPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finish() async {
    setState(() => _isSaving = true);
    try {
      final db = context.read<AppDatabase>();
      final provider = context.read<UserGoalsProvider>();

      final age = int.tryParse(_ageController.text.trim()) ?? 25;
      final height = int.tryParse(_heightController.text.trim()) ?? 170;
      final currentWeight =
          double.tryParse(_currentWeightController.text.trim()) ?? 70.0;
      final goalWeight =
          double.tryParse(_goalWeightController.text.trim()) ?? 70.0;
      final finalCalories =
          int.tryParse(_calorieController.text.trim()) ?? _calculatedCalories;

      await db.userSettingsDao.updateProfile(
        name: _nameController.text.trim(),
        age: age,
        heightCm: height,
        sex: _sex.name,
        activityLevel: ActivityLevel.values.indexOf(_activity),
        goalType: GoalType.values.indexOf(_goalType),
        startingWeight: currentWeight,
        goalWeight: goalWeight,
      );

      await provider.saveCalorieGoal(finalCalories);

      // Mark as already-synced so it is never pushed to the server.
      // It stays as a local starting-weight reference only.
      await db.weightRecordDao.addWeightRecord(
        WeightRecordCompanion.insert(
          date: DateTime.now(),
          weight: currentWeight,
          syncStatus: Value(WeightSyncStatus.synced.index),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);

      // Refresh provider so login screen shows up-to-date name and weight
      await provider.reload();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _OnboardingProgressBar(current: _currentPage, total: _totalPages),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  const _WelcomePage(),
                  _ProfilePage(
                    nameController: _nameController,
                    ageController: _ageController,
                    heightController: _heightController,
                    sex: _sex,
                    onSexChanged: (v) => setState(() => _sex = v ?? Sex.male),
                  ),
                  _GoalsPage(
                    activity: _activity,
                    onActivityChanged:
                        (v) => setState(
                          () => _activity = v ?? ActivityLevel.moderatelyActive,
                        ),
                    goalType: _goalType,
                    onGoalTypeChanged:
                        (v) => setState(
                          () => _goalType = v ?? GoalType.maintenance,
                        ),
                    currentWeightController: _currentWeightController,
                    goalWeightController: _goalWeightController,
                  ),
                  _SummaryPage(
                    calculatedCalories: _calculatedCalories,
                    calorieController: _calorieController,
                  ),
                ],
              ),
            ),
            _OnboardingNavButtons(
              currentPage: _currentPage,
              totalPages: _totalPages,
              isSaving: _isSaving,
              onNext: _nextPage,
              onBack: _prevPage,
              onFinish: _finish,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Progress bar ──────────────────────────────────────────────────────────────

class _OnboardingProgressBar extends StatelessWidget {
  final int current;
  final int total;

  const _OnboardingProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(total, (i) {
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color:
                    i <= current
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.12),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Nav buttons ───────────────────────────────────────────────────────────────

class _OnboardingNavButtons extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final bool isSaving;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onFinish;

  const _OnboardingNavButtons({
    required this.currentPage,
    required this.totalPages,
    required this.isSaving,
    required this.onNext,
    required this.onBack,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isFirst = currentPage == 0;
    final isLast = currentPage == totalPages - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Row(
        children: [
          if (!isFirst)
            OutlinedButton(
              onPressed: onBack,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                l10n.back,
                style: const TextStyle(
                  fontFamily: 'Exo 2',
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            const SizedBox.shrink(),
          const Spacer(),
          ElevatedButton(
            onPressed: isSaving ? null : (isLast ? onFinish : onNext),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child:
                isSaving
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : Text(
                      isLast ? l10n.onboardingGetStarted : l10n.next,
                      style: const TextStyle(
                        fontFamily: 'Exo 2',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

// ── Page 1: Welcome ───────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.fitness_center, color: cs.primary, size: 36),
          ),
          const SizedBox(height: 28),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Forge',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w800,
                    fontSize: 36,
                    color: cs.primary,
                  ),
                ),
                TextSpan(
                  text: 'Form',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w800,
                    fontSize: 36,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.onboardingWelcomeSubtitle,
            style: TextStyle(
              fontFamily: 'Exo 2',
              fontSize: 17,
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.onboardingWelcomeBody,
            style: TextStyle(
              fontFamily: 'Exo 2',
              fontSize: 15,
              height: 1.6,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 32),
          ...[
            (Icons.restaurant_menu, l10n.food),
            (Icons.fitness_center, l10n.gym),
            (Icons.monitor_weight, l10n.onboardingFeatureWeight),
            (Icons.bar_chart, l10n.progress),
          ].map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.$1, color: cs.primary, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    item.$2,
                    style: TextStyle(
                      fontFamily: 'Exo 2',
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page 2: Profile ───────────────────────────────────────────────────────────

class _ProfilePage extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController ageController;
  final TextEditingController heightController;
  final Sex sex;
  final ValueChanged<Sex?> onSexChanged;

  const _ProfilePage({
    required this.nameController,
    required this.ageController,
    required this.heightController,
    required this.sex,
    required this.onSexChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OnboardingPageHeader(
            title: l10n.onboardingProfileTitle,
            subtitle: l10n.onboardingProfileSubtitle,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: onboardingFieldDecoration(context, l10n.nameLabel),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: ageController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: onboardingFieldDecoration(context, l10n.age),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: heightController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: onboardingFieldDecoration(context, l10n.heightCm),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<Sex>(
            value: sex,
            isExpanded: true,
            decoration: onboardingFieldDecoration(context, l10n.sex),
            items:
                Sex.values
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.localized(context)),
                      ),
                    )
                    .toList(),
            onChanged: onSexChanged,
          ),
        ],
      ),
    );
  }
}

// ── Page 3: Goals & Weight ────────────────────────────────────────────────────

class _GoalsPage extends StatelessWidget {
  final ActivityLevel activity;
  final ValueChanged<ActivityLevel?> onActivityChanged;
  final GoalType goalType;
  final ValueChanged<GoalType?> onGoalTypeChanged;
  final TextEditingController currentWeightController;
  final TextEditingController goalWeightController;

  const _GoalsPage({
    required this.activity,
    required this.onActivityChanged,
    required this.goalType,
    required this.onGoalTypeChanged,
    required this.currentWeightController,
    required this.goalWeightController,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OnboardingPageHeader(
            title: l10n.onboardingGoalsTitle,
            subtitle: l10n.onboardingGoalsSubtitle,
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<ActivityLevel>(
            value: activity,
            isExpanded: true,
            decoration: onboardingFieldDecoration(context, l10n.activity),
            items:
                ActivityLevel.values
                    .map(
                      (a) => DropdownMenuItem(
                        value: a,
                        child: Text(a.localized(context)),
                      ),
                    )
                    .toList(),
            onChanged: onActivityChanged,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<GoalType>(
            value: goalType,
            isExpanded: true,
            decoration: onboardingFieldDecoration(context, l10n.goal),
            items:
                GoalType.values
                    .map(
                      (g) => DropdownMenuItem(
                        value: g,
                        child: Text(g.localized(context)),
                      ),
                    )
                    .toList(),
            onChanged: onGoalTypeChanged,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: currentWeightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: onboardingFieldDecoration(
              context,
              '${l10n.currentWeight} (${l10n.kg})',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: goalWeightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: onboardingFieldDecoration(
              context,
              '${l10n.goalWeight} (${l10n.kg})',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page 4: Summary ───────────────────────────────────────────────────────────

class _SummaryPage extends StatelessWidget {
  final int calculatedCalories;
  final TextEditingController calorieController;

  const _SummaryPage({
    required this.calculatedCalories,
    required this.calorieController,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OnboardingPageHeader(title: l10n.onboardingSummaryTitle),
          const SizedBox(height: 28),
          // Calorie highlight card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.primary.withValues(alpha: 0.20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: cs.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.onboardingSummaryCaloriesLabel,
                      style: TextStyle(
                        fontFamily: 'Exo 2',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '$calculatedCalories kcal',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w800,
                    fontSize: 32,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Editable field — same pattern as Settings screen
          TextField(
            controller: calorieController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: onboardingFieldDecoration(
              context,
              l10n.dailyCalorieGoal,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.onboardingSummaryCaloriesLabel,
            style: TextStyle(
              fontFamily: 'Exo 2',
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared page header ────────────────────────────────────────────────────────

class _OnboardingPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _OnboardingPageHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w800,
            fontSize: 26,
            color: cs.onSurface,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: TextStyle(
              fontFamily: 'Exo 2',
              fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ],
    );
  }
}
