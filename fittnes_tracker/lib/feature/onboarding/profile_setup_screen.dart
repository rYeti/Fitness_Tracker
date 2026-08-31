import 'package:ForgeForm/core/forge_motion.dart';
import 'package:ForgeForm/core/widgets/form_pane.dart';
import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/providers/enums.dart';
import 'package:ForgeForm/core/providers/user_goals_provider.dart';
import 'package:ForgeForm/feature/onboarding/onboarding_screen.dart'
    show onboardingFieldDecoration;
import 'package:ForgeForm/feature/onboarding/profile_setup_prefs.dart';
import 'package:ForgeForm/feature/settings/settings_screen.dart'
    show ActivityLevelLocalizations, GoalTypeLocalizations, SexLocalizations;
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Personal-fitness setup: profile, goals, and a daily calorie target.
///
/// Runs **after** authentication, and only for trainees. It used to run before
/// the login screen, which meant every trainer was asked for their own cutting
/// goal before they could reach the console — and the role is not knowable
/// pre-auth, since it comes from an endpoint that needs a token.
///
/// Because there is now a real account behind it, what this writes is the
/// user's actual data: the starting weight record is queued for sync rather
/// than being marked already-synced to keep it local, which is what the
/// pre-auth version had to do.
class ProfileSetupScreen extends StatefulWidget {
  /// Account this setup belongs to; completion is recorded per account.
  final String userId;

  /// Where to go when setup is finished or skipped.
  final WidgetBuilder onDone;

  const ProfileSetupScreen({
    super.key,
    required this.userId,
    required this.onDone,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 3;
  bool _isSaving = false;

  // Page 1 — Profile
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  Sex _sex = Sex.male;

  // Page 2 — Goals & Weight
  ActivityLevel _activity = ActivityLevel.moderatelyActive;
  GoalType _goalType = GoalType.maintenance;
  final _currentWeightController = TextEditingController();
  final _goalWeightController = TextEditingController();

  // Page 3 — Summary
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
    final height =
        double.tryParse(_heightController.text.trim().replaceAll(',', '.')) ??
        0;
    final weight =
        double.tryParse(
          _currentWeightController.text.trim().replaceAll(',', '.'),
        ) ??
        70;
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
    final l10n = AppLocalizations.of(context)!;
    if (_currentPage == 0) {
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.pleaseEnterAName)));
        return;
      }
      if (_ageController.text.trim().isEmpty ||
          _heightController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pleaseEnterValidAgeAndHeight)),
        );
        return;
      }
    }
    if (_currentPage == 1) {
      if (_currentWeightController.text.trim().isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.pleaseEnterValidNumber)));
        return;
      }
      _recalculate();
    }
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

  /// Leaves setup without filling it in. Recorded as complete so the app
  /// doesn't nag on every launch — goals remain editable in Settings.
  Future<void> _skip() async {
    await ProfileSetupPrefs.markComplete(widget.userId);
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: widget.onDone));
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

      // Queued for sync, not marked already-synced. The pre-auth version had
      // to keep this local because there was no account to attach it to; there
      // is one now, so the trainee's starting weight belongs on the server
      // like any other weigh-in.
      await db.weightRecordDao.addWeightRecord(
        WeightRecordCompanion.insert(
          date: DateTime.now(),
          weight: currentWeight,
          syncStatus: Value(WeightSyncStatus.pending.index),
        ),
      );

      await ProfileSetupPrefs.markComplete(widget.userId);
      await provider.reload();

      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: widget.onDone));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToSaveProfile(e)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isSaving ? null : _skip,
                child: Text(l10n.profileSetupSkip),
              ),
            ),
            _ProfileSetupProgressBar(current: _currentPage, total: _totalPages),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
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
            _ProfileSetupNavButtons(
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

class _ProfileSetupProgressBar extends StatelessWidget {
  final int current;
  final int total;

  const _ProfileSetupProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(total, (i) {
          return Expanded(
            child: AnimatedContainer(
              duration: ForgeMotion.of(context, ForgeMotion.emphasis),
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

class _ProfileSetupNavButtons extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final bool isSaving;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onFinish;

  const _ProfileSetupNavButtons({
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
          FilledButton(
            onPressed: isSaving ? null : (isLast ? onFinish : onNext),
            style: FilledButton.styleFrom(
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

// ── Page 1: Profile ───────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: FormPane(
        horizontalPadding: 24,
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
      ),
    );
  }
}

// ── Page 2: Goals & Weight ────────────────────────────────────────────────────

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
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: FormPane(
        horizontalPadding: 24,
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: onboardingFieldDecoration(
                context,
                '${l10n.currentWeight} (${l10n.kg})',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: goalWeightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: onboardingFieldDecoration(
                context,
                '${l10n.goalWeight} (${l10n.kg})',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Page 3: Summary ───────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: FormPane(
        horizontalPadding: 24,
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
