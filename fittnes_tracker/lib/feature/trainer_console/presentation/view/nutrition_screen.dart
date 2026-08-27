import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/active_client_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/nutrition_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/calorie_ring.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/client_switcher.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/console_widgets.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/macro_summary.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/meal_detail_sheet.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/console_error.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:ForgeForm/core/nutrition/meal_category.dart';

/// Client-switcher (shared ActiveClientProvider) + a day-switcher, so the
/// trainer can browse any past day's nutrition, not just today.
class NutritionScreen extends StatefulWidget {
  /// Injection seam for tests; production lets the provider build the real one.
  final TrainerConsoleRepository? repository;

  const NutritionScreen({super.key, this.repository});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  late final NutritionProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = NutritionProvider(repository: widget.repository);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncToActiveClient());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncToActiveClient();
  }

  void _syncToActiveClient() {
    if (!mounted) return;
    final clientId = context.read<ActiveClientProvider>().activeClient?.clientId;
    if (clientId == null || _provider.loadedClientId == clientId) return;
    _provider.load(clientId);
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NutritionProvider>.value(
      value: _provider,
      child: Consumer2<ActiveClientProvider, NutritionProvider>(
        builder: (context, activeClient, nutrition, _) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _syncToActiveClient(),
          );

          final client = activeClient.activeClient;
          final isDesktop = MediaQuery.of(context).size.width > 1024;
          final padding = isDesktop ? 32.0 : 16.0;

          return Scaffold(
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerLowest,
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(
                      clientName: client?.clientName,
                      isDesktop: isDesktop,
                      nutrition: nutrition,
                      clientId: client?.clientId,
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: _Body(
                        activeClient: activeClient,
                        nutrition: nutrition,
                        isDesktop: isDesktop,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String? clientName;
  final bool isDesktop;
  final NutritionProvider nutrition;
  final String? clientId;

  const _Header({
    required this.clientName,
    required this.isDesktop,
    required this.nutrition,
    required this.clientId,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.consoleNavNutrition,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w800,
            fontSize: isDesktop ? 26 : 20,
            letterSpacing: -0.3,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          clientName == null
              ? l10n.nutritionSubtitleNoClient
              : l10n.nutritionSubtitle,
          style: TextStyle(
            fontFamily: 'Exo 2',
            fontSize: 13,
            color: colors.onSurface.withValues(alpha: 0.65),
          ),
        ),
      ],
    );

    final daySwitcher = clientId == null
        ? const SizedBox.shrink()
        : _DaySwitcher(nutrition: nutrition, clientId: clientId!);

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: title),
          const SizedBox(width: 16),
          daySwitcher,
          const SizedBox(width: 12),
          const ClientSwitcher(fullWidth: false),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        const SizedBox(height: 12),
        const ClientSwitcher(fullWidth: true),
        const SizedBox(height: 8),
        daySwitcher,
      ],
    );
  }
}

class _DaySwitcher extends StatelessWidget {
  final NutritionProvider nutrition;
  final String clientId;

  const _DaySwitcher({required this.nutrition, required this.clientId});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final date = nutrition.selectedDate;
    final today = DateTime.now();
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;

    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => nutrition.previousDay(clientId),
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: l10n.previousDay,
            iconSize: 20,
          ),
          Text(
            isToday
                ? l10n.today
                : DateFormat(
                    'EEE d MMM',
                    Localizations.localeOf(context).toString(),
                  ).format(date),
            style: TextStyle(
              fontFamily: 'Exo 2',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          IconButton(
            // Disabled rather than hidden, so the control doesn't reflow when
            // the trainer reaches today.
            onPressed: nutrition.canGoForward
                ? () => nutrition.nextDay(clientId)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: l10n.nextDay,
            iconSize: 20,
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final ActiveClientProvider activeClient;
  final NutritionProvider nutrition;
  final bool isDesktop;

  const _Body({
    required this.activeClient,
    required this.nutrition,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (activeClient.isLoading && activeClient.clients.isEmpty) {
      return ConsoleSkeleton(semanticsLabel: l10n.nutritionLoading);
    }
    if (activeClient.error != null) {
      return ConsoleErrorState(
        message: activeClient.error!.localizedMessage(l10n),
        onRetry: activeClient.loadClients,
      );
    }
    final client = activeClient.activeClient;
    if (client == null) {
      return ConsoleEmptyState(
        icon: Icons.group_outlined,
        title: l10n.rosterEmptyTitle,
        message: l10n.nutritionNoClientsBody,
      );
    }
    if (nutrition.isLoading) {
      return ConsoleSkeleton(semanticsLabel: l10n.nutritionLoading);
    }
    if (nutrition.error != null) {
      return ConsoleErrorState(
        message: nutrition.error!.localizedMessage(l10n),
        onRetry: () => nutrition.load(client.clientId),
      );
    }

    final summary = nutrition.summary;
    if (summary == null) {
      return ConsoleSkeleton(semanticsLabel: l10n.nutritionLoading);
    }

    final ringCard = _RingCard(summary: summary);
    final mealsCard = _MealsCard(summary: summary, clientName: client.firstName);
    final trendCard = _TrendCard(trend: summary.sevenDayTrend);

    if (isDesktop) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 340, child: ringCard),
                const SizedBox(width: 18),
                Expanded(child: mealsCard),
              ],
            ),
            const SizedBox(height: 18),
            trendCard,
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ringCard,
          const SizedBox(height: 14),
          mealsCard,
          const SizedBox(height: 14),
          trendCard,
        ],
      ),
    );
  }
}

class _RingCard extends StatelessWidget {
  final ClientNutritionSummary summary;

  const _RingCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return ConsoleCard(
      radius: 16,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          CalorieRing(
            kcalConsumed: summary.totalCalories,
            kcalGoal: summary.calorieGoal,
          ),
          const SizedBox(height: 20),
          MacroSummary(
            protein: summary.macros.protein,
            carbs: summary.macros.carbs,
            fat: summary.macros.fat,
            calorieGoal: summary.calorieGoal,
          ),
        ],
      ),
    );
  }
}

class _MealsCard extends StatelessWidget {
  final ClientNutritionSummary summary;
  final String clientName;

  const _MealsCard({required this.summary, required this.clientName});

  /// The design orders meals by time of day rather than insertion order.
  static const _categoryOrder = ['breakfast', 'lunch', 'snack', 'dinner'];

  /// The category as written by the client app ("Breakfast", "Snacks") reduced
  /// to the one value the lookups below key on. The app has used both "Snack"
  /// and "Snacks" over its life, and the tracker capitalises where this API's
  /// DTOs document lowercase, so nothing here may compare the raw string:
  /// unrecognised categories fall through to a generic icon and the end of the
  /// list, which is how Snacks used to render. The fold itself lives in
  /// [MealCategory] so this side and the food tracker cannot drift apart.
  static String _key(String category) => MealCategory.key(category);

  static IconData _iconFor(String category) =>
      switch (_key(category)) {
        'breakfast' => Icons.free_breakfast_outlined,
        'lunch' => Icons.lunch_dining_outlined,
        'dinner' => Icons.dinner_dining_outlined,
        'snack' => Icons.cookie_outlined,
        _ => Icons.restaurant_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    if (summary.loggedMeals.isEmpty) {
      return ConsoleEmptyState(
        icon: Icons.no_meals_outlined,
        title: l10n.nothingLogged,
        message: l10n.nothingLoggedBody(clientName),
        inCard: true,
      );
    }

    final meals = [...summary.loggedMeals]..sort((a, b) {
      final ai = _categoryOrder.indexOf(_key(a.category));
      final bi = _categoryOrder.indexOf(_key(b.category));
      // Unknown categories sort last rather than to the front.
      return (ai < 0 ? _categoryOrder.length : ai)
          .compareTo(bi < 0 ? _categoryOrder.length : bi);
    });

    return ConsoleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConsoleSectionTitle(title: l10n.mealsLogged),
          for (final meal in meals) ...[
            _MealRow(meal: meal),
            if (meal != meals.last)
              Divider(height: 1, color: colors.onSurface.withValues(alpha: 0.08)),
          ],
        ],
      ),
    );
  }

  /// The wire value is an English slug ("breakfast"); the reader sees their
  /// own language. An unrecognised category keeps the server's own wording
  /// rather than being flattened to "Meal".
  static String _categoryLabel(String category, AppLocalizations l10n) =>
      switch (_key(category)) {
        'breakfast' => l10n.mealBreakfast,
        'lunch' => l10n.mealLunch,
        'dinner' => l10n.mealDinner,
        'snack' => l10n.mealSnacks,
        '' => l10n.meal,
        _ => category[0].toUpperCase() + category.substring(1).toLowerCase(),
      };
}

/// One meal in the "Meals logged" list. Tapping opens [MealDetailSheet] with
/// every food in the meal — the row itself only has space for a one-line,
/// ellipsised list of names.
class _MealRow extends StatelessWidget {
  final LoggedMeal meal;

  const _MealRow({required this.meal});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final label = _MealsCard._categoryLabel(meal.category, l10n);
    final icon = _MealsCard._iconFor(meal.category);

    // Nothing to drill into when the meal came back without per-food detail
    // (an empty meal, or an API build older than the detail view) — the row
    // stays a plain, non-tappable summary rather than opening a blank sheet.
    final canOpen = meal.foods.isNotEmpty;

    final content = Padding(
      // 44px min tap target per CLAUDE.md, with the icon tile at 36px.
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ForgeColors.forgeOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 19, color: ForgeColors.forgeOrange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Exo 2',
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: colors.onSurface,
                  ),
                ),
                if (meal.foodNames.isNotEmpty)
                  Text(
                    meal.foodNames.join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Exo 2',
                      fontSize: 11.5,
                      color: colors.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${meal.calories} kcal',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: colors.onSurface,
            ),
          ),
          if (canOpen) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colors.onSurface.withValues(alpha: 0.45),
            ),
          ],
        ],
      ),
    );

    if (!canOpen) return content;

    return Semantics(
      container: true,
      button: true,
      label: l10n.mealDetailSemantics(label, meal.calories),
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => MealDetailSheet.show(
            context,
            meal: meal,
            mealLabel: label,
            icon: icon,
          ),
          child: content,
        ),
      ),
    );
  }
}

/// 7-day calories-vs-target bars. Hand-built rather than pulled into fl_chart:
/// it's a fixed 7-bar comparison against a single reference line, and the
/// over-budget colouring is per-bar.
class _TrendCard extends StatelessWidget {
  final List<DailyCalorieTotal> trend;

  const _TrendCard({required this.trend});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    if (trend.isEmpty) {
      return ConsoleEmptyState(
        icon: Icons.bar_chart_outlined,
        title: l10n.noTrendYet,
        message: l10n.noTrendYetBody,
        inCard: true,
      );
    }

    // Scale to the tallest of (biggest day, goal) so the goal line is always
    // on-chart even when every day came in under it.
    final maxValue = [
      ...trend.map((d) => d.totalCalories),
      ...trend.map((d) => d.goal),
    ].fold<int>(1, (a, b) => b > a ? b : a);

    return ConsoleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConsoleSectionTitle(title: l10n.caloriesVsTarget),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final day in trend)
                  Expanded(
                    child: _TrendBar(
                      day: day,
                      maxValue: maxValue,
                      isLast: day == trend.last,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _LegendDot(
                color: ForgeColors.forgeOrange,
                label: l10n.withinTarget,
              ),
              const SizedBox(width: 16),
              _LegendDot(color: ForgeColors.statusBad, label: l10n.overTarget),
              const Spacer(),
              Text(
                l10n.targetCalories(trend.last.goal),
                style: TextStyle(
                  fontFamily: 'Exo 2',
                  fontSize: 11.5,
                  color: colors.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendBar extends StatelessWidget {
  final DailyCalorieTotal day;
  final int maxValue;
  final bool isLast;

  const _TrendBar({
    required this.day,
    required this.maxValue,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final over = day.isOverBudget;
    final fraction = (day.totalCalories / maxValue).clamp(0.0, 1.0);

    // The bar's own label carries the day, the number and whether it went
    // over — the loose "1850"/"Wed" Texts inside would otherwise be read as
    // two unconnected fragments.
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: over
          ? l10n.trendBarSemanticsOver(
              DateFormat('EEEE', locale).format(day.date),
              day.totalCalories,
            )
          : l10n.trendBarSemantics(
              DateFormat('EEEE', locale).format(day.date),
              day.totalCalories,
            ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '${day.totalCalories}',
              style: TextStyle(
                fontFamily: 'Exo 2',
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: colors.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    // A logged-but-tiny day still shows a sliver rather than
                    // disappearing entirely.
                    height: day.totalCalories > 0
                        ? (constraints.maxHeight * fraction).clamp(3.0, constraints.maxHeight)
                        : 0,
                    decoration: BoxDecoration(
                      color: over
                          ? ForgeColors.statusBad
                          : ForgeColors.forgeOrange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              DateFormat('E', locale).format(day.date),
              style: TextStyle(
                fontFamily: 'Exo 2',
                fontSize: 10,
                fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
                color: colors.onSurface.withValues(alpha: isLast ? 0.85 : 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Exo 2',
            fontSize: 11.5,
            color: colors.onSurface.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}
