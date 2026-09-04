// lib/feature/presentation/view/food_tracking_screen.dart
import 'dart:async';

import 'package:drift/drift.dart';
import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/nutrition/extended_nutrients.dart';
import 'package:ForgeForm/core/nutrition/nutrient_pins_api.dart';
import 'package:ForgeForm/core/providers/access_provider.dart';
import 'package:ForgeForm/core/providers/user_goals_provider.dart';
import 'package:ForgeForm/core/widgets/tracked_nutrients_card.dart';
import 'package:ForgeForm/feature/dashboard/view/dashboard_screen.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:ForgeForm/feature/progress_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/models/food_item_model.dart';
import '../../data/repositories/nutrition_repository.dart';
import 'food_add_screen.dart';
import 'food_detail_view.dart';
import 'package:ForgeForm/core/widgets/forge_app_bar.dart';
import 'package:ForgeForm/core/widgets/content_pane.dart';

// Create a global key to access the FoodTrackingScreen state
final globalFoodTrackingKey = GlobalKey<_FoodTrackingScreenState>();

class FoodTrackingScreen extends StatefulWidget {
  const FoodTrackingScreen({super.key});

  @override
  State<FoodTrackingScreen> createState() => _FoodTrackingScreenState();
}

class _FoodTrackingScreenState extends State<FoodTrackingScreen> {
  late final AppDatabase db;
  late final NutritionRepository _repository;
  Map<String, List<FoodItemData>> _mealFoods = {};
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();

  /// Not day-specific — a coach's pin selection applies to every day, so this
  /// is fetched once rather than re-fetched on every date change.
  List<String> _pinnedNutrients = const [];

  /// Every food logged today, summed. Each [FoodItemData] already stores its
  /// nutrients scaled to the amount actually logged (see
  /// `docs/trainer-console-micronutrients.md` for the two bugs that made that
  /// untrue before this feature), so no rescaling happens here — a plain
  /// null-preserving sum across every meal's foods.
  ExtendedNutrients get _dayMicronutrients => ExtendedNutrients.sum(
        _mealFoods.values.expand((foods) => foods).map(
              (food) => food.extendedNutrientsJson == null
                  ? ExtendedNutrients.empty
                  : ExtendedNutrients.fromJsonString(food.extendedNutrientsJson!),
            ),
      );

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  // Map stored category keys to AppLocalizations getters so we can present
  // translated labels without changing storage or DB values.
  final Map<String, String Function(AppLocalizations)> _mealLabelGetters = {
    'Breakfast': (loc) => loc.mealBreakfast,
    'Lunch': (loc) => loc.mealLunch,
    'Dinner': (loc) => loc.mealDinner,
    'Snacks': (loc) => loc.mealSnacks,
  };

  String _localizedMealLabel(String category, BuildContext ctx) {
    final loc = AppLocalizations.of(ctx)!;
    final getter = _mealLabelGetters[category];
    return getter?.call(loc) ?? category;
  }

  @override
  void initState() {
    super.initState();
    // Get the database instance from Provider instead of creating a new one
    db = Provider.of<AppDatabase>(context, listen: false);
    _repository = NutritionRepository(db);
    loadNutritionData();
    unawaited(_loadPinnedNutrients());
  }

  Future<void> _loadPinnedNutrients() async {
    try {
      final pins = await NutrientPinsApi().fetchMyPins();
      if (mounted) setState(() => _pinnedNutrients = pins);
    } catch (_) {
      // Leave the card unrendered (empty pin list) rather than surfacing a
      // second error state on a screen whose main job is the food log.
    }
  }

  void _prevDay() => setState(() {
        _selectedDate = _selectedDate.subtract(const Duration(days: 1));
        loadNutritionData();
      });

  void _nextDay() => setState(() {
        _selectedDate = _selectedDate.add(const Duration(days: 1));
        loadNutritionData();
      });

  void _goToday() => setState(() {
        _selectedDate = DateTime.now();
        loadNutritionData();
      });

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      loadNutritionData();
    }
  }

  Future<void> _editPortion(String category, FoodItemData food) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: food.gramm.toString());
    final newGramm = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16, right: 16, top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.editPortion,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.portionGrams,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(l10n.cancel)),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final v = int.tryParse(controller.text.trim());
                    if (v != null && v > 0) Navigator.pop(ctx, v);
                  },
                  child: Text(l10n.updatePortion),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (newGramm == null || newGramm == food.gramm) return;
    final base = food.gramm > 0 ? food.gramm : 100;
    final ratio = newGramm / base;
    // Rescale from `base`, not implicitly from 100 — a food's stored
    // micronutrients represent its own current serving, which for a
    // re-added local food is not always 100g. See
    // `docs/trainer-console-micronutrients.md`.
    final existingNutrients = food.extendedNutrientsJson == null
        ? null
        : ExtendedNutrients.fromJsonString(food.extendedNutrientsJson!);
    final rescaledNutrients = existingNutrients?.rescale(
      fromGrams: base.toDouble(),
      toGrams: newGramm.toDouble(),
    );
    await db.foodItemDao.updateFoodItem(
      food.id,
      calories: (food.calories * ratio).round(),
      protein: (food.protein * ratio).round(),
      carbs: (food.carbs * ratio).round(),
      fat: (food.fat * ratio).round(),
      gramm: newGramm,
      extendedNutrientsJson: Value(rescaledNutrients?.toJsonString()),
    );
    loadNutritionData();
    _refreshDashboard();
  }

  // Nutrition mutations (add/edit/delete) only update this screen's own
  // state via loadNutritionData(). DashboardScreen shows a separate daily
  // calorie total that isn't recomputed just by switching tabs (it lives in
  // an IndexedStack), so it must be nudged explicitly whenever food data
  // actually changes.
  void _refreshDashboard() {
    globalDashboardKey.currentState?.refresh();
    globalProgressKey.currentState?.reloadNutritionData();
  }

  // Making this method public so it can be called from outside
  Future<void> loadNutritionData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      const mealCategories = ['Breakfast', 'Lunch', 'Dinner', 'Snacks'];
      final mealFoods = <String, List<FoodItemData>>{};

      for (final category in mealCategories) {
        mealFoods[category] = await _repository.getFoodItemsForCategory(
          category,
          date: _selectedDate,
        );
      }

      if (mounted) {
        setState(() {
          _mealFoods = mealFoods;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToLoadData(e)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ForgeAppBar(
        title: AppLocalizations.of(context)!.food,
        bottom: _isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.restaurant_menu, color: Colors.white),
            tooltip: AppLocalizations.of(context)!.mealTemplates,
            onPressed: () {
              context.push('/meal-templates');
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: AppLocalizations.of(context)!.refresh,
            onPressed: loadNutritionData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadNutritionData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ContentPane(
            child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDateNav(),
                const SizedBox(height: 8),
                _buildDailySummary(),
                const SizedBox(height: 16),
                _buildTrackedNutrients(),
                const SizedBox(height: 24),
                _buildMealsList(),
              ],
            ),
          ),
          )
        ),
      ),
    );
  }

  Widget _buildDateNav() {
    final locale = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat('EEE, d MMM yyyy', locale);
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          tooltip: l10n.previousDay,
          onPressed: _prevDay,
        ),
        TextButton(
          onPressed: _pickDate,
          child: Text(
            dateFormat.format(_selectedDate),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            semanticsLabel:
                '${dateFormat.format(_selectedDate)}. ${l10n.pickDate}',
          ),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 18),
          tooltip: l10n.nextDay,
          onPressed: _nextDay,
        ),
        if (!_isToday)
          TextButton(
            onPressed: _goToday,
            child: Text(l10n.today),
          ),
      ],
    );
  }

  /// Read-only: what a coach chose to track, not something the trainee
  /// edits here. Gated on the same premium flag as the per-food card
  /// (`food_detail_view.dart`) — see docs/trainer-console-micronutrients.md
  /// for why the gate is enforced server-side too, and why device-side IAP
  /// premium is invisible to that server-side check.
  Widget _buildTrackedNutrients() {
    final l10n = AppLocalizations.of(context)!;
    final isPremium = context.read<AccessProvider>().hasPremiumAccess;
    return TrackedNutrientsCard(
      locked: !isPremium,
      pinnedKeys: _pinnedNutrients,
      nutrients: _dayMicronutrients,
      dayScope: true,
      subtitle: l10n.trackedNutrientsSubtitleTrainee,
    );
  }

  Widget _buildDailySummary() {
    final locale = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat('EEEE, MMMM d', locale);
    final calorieGoal = Provider.of<UserGoalsProvider>(context).calorieGoal;
    // Calculate daily totals from _mealFoods
    int totalCalories = 0;
    int totalProtein = 0;
    int totalCarbs = 0;
    int totalFat = 0;
    _mealFoods.forEach((_, foods) {
      for (final food in foods) {
        totalCalories += food.calories;
        totalProtein += food.protein;
        totalCarbs += food.carbs;
        totalFat += food.fat;
      }
    });
    final progress = calorieGoal > 0 ? totalCalories / calorieGoal : 0.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateFormat.format(_selectedDate),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$totalCalories / $calorieGoal kcal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress > 1 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNutrientSummary(
                  AppLocalizations.of(context)!.proteinLabel,
                  '${totalProtein}g',
                  Icons.egg_outlined,
                  const Color(0xFFE57373),
                  calorieGoal > 0
                      ? '${(totalProtein * 4 / calorieGoal * 100).toStringAsFixed(1)}%'
                      : '0%',
                ),
                _buildNutrientSummary(
                  AppLocalizations.of(context)!.carbsLabel,
                  '${totalCarbs}g',
                  Icons.grain,
                  const Color(0xFF64B5F6),
                  calorieGoal > 0
                      ? '${(totalCarbs * 4 / calorieGoal * 100).toStringAsFixed(1)}%'
                      : '0%',
                ),
                _buildNutrientSummary(
                  AppLocalizations.of(context)!.fatLabel,
                  '${totalFat}g',
                  Icons.water_drop_outlined,
                  const Color(0xFF81C784),
                  calorieGoal > 0
                      ? '${(totalFat * 9 / calorieGoal * 100).toStringAsFixed(1)}%'
                      : '0%',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientSummary(
    String label,
    String value,
    IconData icon,
    Color color,
    String percentage,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(
          percentage,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }

  Widget _buildMealsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.food,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ..._mealFoods.entries.map((entry) {
          return _buildMealCard(entry.key, entry.value);
        }),
      ],
    );
  }

  Widget _buildMealCard(String category, List<FoodItemData> foods) {
    final totalCalories = foods.fold(0, (sum, food) => sum + food.calories);

    return Builder(
      builder:
          (localContext) => Card(
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: Meal Name and Calories
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _localizedMealLabel(category, localContext),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$totalCalories kcal',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 0.5),

                  // Buttons Row
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () async {
                            await Navigator.push(
                              localContext,
                              MaterialPageRoute(
                                builder:
                                    (context) => FoodAddScreen(
                                          category: category,
                                          date: _selectedDate,
                                        ),
                              ),
                            );
                            loadNutritionData();
                            _refreshDashboard();
                          },
                          // A bare "+" is the only affordance for adding food
                          // to this category, so it has to say which category
                          // it belongs to — there is one per meal and they are
                          // otherwise indistinguishable.
                          child: Tooltip(
                            message: AppLocalizations.of(
                              context,
                            )!.addFoodToCategory(category),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                              child: const Center(
                                child: Icon(Icons.add, size: 22),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Meal Items
                  if (foods.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(
                        AppLocalizations.of(context)!.noFoodAdded,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    Column(
                      children:
                          foods.map((food) {
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(food.name),
                              subtitle: Builder(builder: (ctx) {
                                final l = AppLocalizations.of(ctx)!;
                                return Text(
                                  '${food.calories} kcal · ${l.proteinLabel}: ${food.protein}g · ${l.carbsLabel}: ${food.carbs}g · ${l.fatLabel}: ${food.fat}g',
                                );
                              }),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FoodDetailsScreen(
                                      foodItem: FoodItemModel.fromData(food),
                                      category: category,
                                      date: _selectedDate,
                                      isEditing: true,
                                    ),
                                  ),
                                );
                                loadNutritionData();
                                _refreshDashboard();
                              },
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    // Naming the food matters more here than
                                    // anywhere else on the screen: a row of
                                    // bare "Edit"/"Delete" buttons gives a
                                    // screen-reader user no way to tell which
                                    // meal entry they are about to change.
                                    tooltip: AppLocalizations.of(
                                      context,
                                    )!.editFoodEntry(food.name),
                                    // Sizing comes from iconButtonTheme. It
                                    // used to be a local `constraints:` here,
                                    // which measured 44x40 in a browser --
                                    // `constraints` overrides the theme's
                                    // minimumSize, so the local fix was the
                                    // thing keeping the real one out.
                                    onPressed: () => _editPortion(category, food),
                                  ),
                                  // Destructive and non-destructive actions
                                  // were adjacent with no gap, so a mis-tap
                                  // landed on delete.
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: AppLocalizations.of(
                                      context,
                                    )!.deleteFoodEntry(food.name),
                                    onPressed: () async {
                                      final l10n = AppLocalizations.of(context)!;
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: Text(l10n.delete),
                                          content: Text(food.name),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: Text(l10n.cancel),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Theme.of(context).colorScheme.error,
                                              ),
                                              child: Text(l10n.delete),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true) {
                                        await _repository.removeFoodFromMeal(
                                          category,
                                          food,
                                          date: _selectedDate,
                                        );
                                        loadNutritionData();
                                        _refreshDashboard();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    ),
                ],
              ),
            ),
          ),
    );
  }
}
