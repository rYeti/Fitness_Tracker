// lib/feature/presentation/view/food_tracking_screen.dart
import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/providers/theme_provider.dart';
import 'package:ForgeForm/core/providers/user_goals_provider.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/models/food_item_model.dart';
import '../../data/repositories/nutrition_repository.dart';
import 'food_add_screen.dart';
import 'food_detail_view.dart';

// Create a global key to access the FoodTrackingScreen state
final globalFoodTrackingKey = GlobalKey<_FoodTrackingScreenState>();

class FoodTrackingScreen extends StatefulWidget {
  const FoodTrackingScreen({Key? key}) : super(key: key);

  @override
  State<FoodTrackingScreen> createState() => _FoodTrackingScreenState();
}

class _FoodTrackingScreenState extends State<FoodTrackingScreen> {
  late final AppDatabase db;
  late final NutritionRepository _repository;
  Map<String, List<FoodItemData>> _mealFoods = {};
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();

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
                ElevatedButton(
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
    await db.foodItemDao.updateFoodItem(
      food.id,
      calories: (food.calories * ratio).round(),
      protein: (food.protein * ratio).round(),
      carbs: (food.carbs * ratio).round(),
      fat: (food.fat * ratio).round(),
      gramm: newGramm,
    );
    loadNutritionData();
  }

  // Making this method public so it can be called from outside
  Future<void> loadNutritionData() async {
    setState(() => _isLoading = true);
    try {
      final mealCategories = [
        'Breakfast',
        'Lunch',
        'Dinner',
        'Snacks',
      ];
      final mealFoods = <String, List<FoodItemData>>{};

      for (final category in mealCategories) {
        mealFoods[category] = await _repository.getFoodItemsForCategory(
          category,
          date: _selectedDate,
        );
      }

      setState(() {
        _mealFoods = mealFoods;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToLoadData(e)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Forge',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: Color(0xFFFF6B3E),
                ),
              ),
              TextSpan(
                text: 'Form',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
            ],
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
          IconButton(
            icon: const Icon(Icons.restaurant_menu, color: Colors.white),
            tooltip: 'Meal Templates',
            onPressed: () {
              Navigator.pushNamed(context, '/meal-templates');
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: loadNutritionData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadNutritionData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDateNav(),
                const SizedBox(height: 8),
                _buildDailySummary(),
                const SizedBox(height: 24),
                _buildMealsList(),
              ],
            ),
          ),
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
          onPressed: _prevDay,
        ),
        TextButton(
          onPressed: _pickDate,
          child: Text(
            dateFormat.format(_selectedDate),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 18),
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
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$totalCalories / $calorieGoal kcal',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                progress > 1 ? Colors.red : Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNutrientSummary(
                  AppLocalizations.of(context)!.proteinLabel,
                  '${totalProtein}g',
                  Colors.red,
                  calorieGoal > 0
                      ? '${(totalProtein * 4 / calorieGoal * 100).toStringAsFixed(1)}%'
                      : '0%',
                ),
                _buildNutrientSummary(
                  AppLocalizations.of(context)!.carbsLabel,
                  '${totalCarbs}g',
                  Colors.blue,
                  calorieGoal > 0
                      ? '${(totalCarbs * 4 / calorieGoal * 100).toStringAsFixed(1)}%'
                      : '0%',
                ),
                _buildNutrientSummary(
                  AppLocalizations.of(context)!.fatLabel,
                  '${totalFat}g',
                  Colors.green,
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
    Color color,
    String percentage,
  ) {
    return Column(
      children: [
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
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 8),
                              const Icon(Icons.add, size: 22),
                            ],
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
                              subtitle: Text(
                                '${food.calories} kcal · P: ${food.protein}g · C: ${food.carbs}g · F: ${food.fat}g',
                              ),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FoodDetailsScreen(
                                      foodItem: FoodItemModel(
                                        id: food.id,
                                        name: food.name,
                                        calories: food.calories,
                                        protein: food.protein,
                                        carbs: food.carbs,
                                        fat: food.fat,
                                        gramm: food.gramm,
                                      ),
                                      category: category,
                                      date: _selectedDate,
                                    ),
                                  ),
                                );
                                loadNutritionData();
                              },
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    onPressed: () => _editPortion(category, food),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      await _repository.removeFoodFromMeal(
                                        category,
                                        food,
                                        date: _selectedDate,
                                      );
                                      loadNutritionData();
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
