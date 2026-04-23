import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/extended_nutrients.dart';
import '../../data/models/food_item_model.dart';
import '../../data/models/portion_option.dart';
import '../../data/repositories/nutrition_repository.dart';

class FoodDetailsScreen extends StatefulWidget {
  final FoodItemModel foodItem;
  final String category;
  final bool isTemplate;
  final List<PortionOption> portionOptions;
  final DateTime? date;

  const FoodDetailsScreen({
    super.key,
    required this.foodItem,
    required this.category,
    this.isTemplate = false,
    this.portionOptions = const [],
    this.date,
  });

  @override
  State<FoodDetailsScreen> createState() => _FoodDetailsScreenState();
}

class _FoodDetailsScreenState extends State<FoodDetailsScreen> {
  late final AppDatabase db;
  late final NutritionRepository _repository;
  late final TextEditingController _quantityController;

  /// What the user typed — either grams (when _selectedUnit==null) or a
  /// portion count (when a serving size is selected).
  double _portionInput = 1.0;

  /// null  → "g" mode: _portionInput is direct grams
  /// non-null → serving mode: actual grams = _portionInput * _selectedUnit!.grams
  PortionOption? _selectedUnit;

  /// Actual grams used for nutrition calculation.
  double get _actualGrams =>
      _selectedUnit == null ? _portionInput : _portionInput * _selectedUnit!.grams;

  // Calculated nutrition values
  double _calculatedCalories = 0;
  double _calculatedProtein = 0;
  double _calculatedCarbs = 0;
  double _calculatedFat = 0;

  ExtendedNutrients? _scaledNutrients;

  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    db = Provider.of<AppDatabase>(context, listen: false);
    _repository = NutritionRepository(db);

    if (widget.portionOptions.isNotEmpty) {
      // Default to the first serving size, quantity = 1 serving
      _selectedUnit = widget.portionOptions.first;
      _portionInput = 1.0;
    } else {
      // Grams mode — pre-fill with the item's stored gram value
      _selectedUnit = null;
      _portionInput = widget.foodItem.gramm > 0 ? widget.foodItem.gramm.toDouble() : 100.0;
    }

    _quantityController = TextEditingController(text: _portionInput.toStringAsFixed(
      _portionInput == _portionInput.roundToDouble() ? 0 : 1,
    ));
    _calculateNutrition();
    _loadPremiumStatus();
  }

  Future<void> _loadPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isPremium = prefs.getBool('is_premium') ?? true; // TODO: remove debug override
    });
  }

  void _calculateNutrition() {
    final base = widget.foodItem.gramm > 0 ? widget.foodItem.gramm.toDouble() : 100.0;
    final grams = _actualGrams;
    setState(() {
      _calculatedCalories = widget.foodItem.calories * (grams / base);
      _calculatedProtein = widget.foodItem.protein * (grams / base);
      _calculatedCarbs = widget.foodItem.carbs * (grams / base);
      _calculatedFat = widget.foodItem.fat * (grams / base);
      _scaledNutrients = widget.foodItem.extendedNutrients?.scaleTo(grams);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.foodDetails)),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Food Name
                Text(
                  widget.foodItem.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Original Nutrition Card
                _buildNutritionCard(),
                const SizedBox(height: 16),

                // Portion Size and Calculated Values Card
                _buildPortionMarcroCalc(),
                const SizedBox(height: 16),

                // Extended nutrients (premium)
                if (widget.foodItem.extendedNutrients != null)
                  _buildExtendedNutrientsCard(),
                if (widget.foodItem.extendedNutrients != null)
                  const SizedBox(height: 16),

                // Add to Meal Section
                _buildAddToMealSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNutritionCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.nutritionInformation,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildNutrientRow(
              AppLocalizations.of(context)!.calories,
              _calculatedCalories,
              'kcal',
              Colors.orange,
            ),
            _buildNutrientRow(
              AppLocalizations.of(context)!.protein,
              _calculatedProtein,
              'g',
              Colors.red,
            ),
            _buildNutrientRow(
              AppLocalizations.of(context)!.carbs,
              _calculatedCarbs,
              'g',
              Colors.blue,
            ),
            _buildNutrientRow(
              AppLocalizations.of(context)!.fat,
              _calculatedFat,
              'g',
              Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientRow(
    String label,
    double numericValue,
    String unit,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 16)),
          const Spacer(),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: numericValue),
            duration: const Duration(milliseconds: 250),
            builder: (context, value, child) {
              final formatted =
                  value >= 10
                      ? value.toStringAsFixed(0)
                      : value.toStringAsFixed(1);
              return Text(
                '$formatted $unit',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExtendedNutrientsCard() {
    final loc = AppLocalizations.of(context)!;
    final nutrients = _scaledNutrients ?? widget.foodItem.extendedNutrients!;

    if (!_isPremium) {
      return Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(loc.extendedNutrientsTitle,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(loc.premiumBadge,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(loc.premiumFeatureBody),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                  onPressed: () {},
                  child: Text(loc.upgradeToPremium,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget nutrientTile(String label, double? value, String unit) {
      if (value == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 14)),
            const Spacer(),
            Text(
              '${value >= 10 ? value.toStringAsFixed(1) : value.toStringAsFixed(2)} $unit',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    Widget sectionHeader(String title) => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(title,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary)),
        );

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(loc.extendedNutrientsTitle,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(loc.premiumBadge,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            sectionHeader(loc.extendedNutrientsMacrosSection),
            nutrientTile(loc.nutrientFiber, nutrients.fiber, 'g'),
            nutrientTile(loc.nutrientSugar, nutrients.sugar, 'g'),
            nutrientTile(loc.nutrientSaturatedFat, nutrients.saturatedFat, 'g'),
            nutrientTile(loc.nutrientSalt, nutrients.salt, 'g'),
            nutrientTile(loc.nutrientSodium, nutrients.sodium, 'g'),
            sectionHeader(loc.extendedNutrientsVitaminsSection),
            nutrientTile(loc.nutrientVitaminA, nutrients.vitaminA, loc.unitUg),
            nutrientTile(loc.nutrientVitaminC, nutrients.vitaminC, loc.unitMg),
            nutrientTile(loc.nutrientVitaminD, nutrients.vitaminD, loc.unitUg),
            nutrientTile(loc.nutrientVitaminE, nutrients.vitaminE, loc.unitMg),
            nutrientTile(loc.nutrientVitaminK, nutrients.vitaminK, loc.unitUg),
            nutrientTile(loc.nutrientVitaminB1, nutrients.vitaminB1, loc.unitMg),
            nutrientTile(loc.nutrientVitaminB2, nutrients.vitaminB2, loc.unitMg),
            nutrientTile(loc.nutrientVitaminB3, nutrients.vitaminB3, loc.unitMg),
            nutrientTile(loc.nutrientVitaminB6, nutrients.vitaminB6, loc.unitMg),
            nutrientTile(loc.nutrientVitaminB9, nutrients.vitaminB9, loc.unitUg),
            nutrientTile(loc.nutrientVitaminB12, nutrients.vitaminB12, loc.unitUg),
            sectionHeader(loc.extendedNutrientsMineralsSection),
            nutrientTile(loc.nutrientCalcium, nutrients.calcium, loc.unitMg),
            nutrientTile(loc.nutrientIron, nutrients.iron, loc.unitMg),
            nutrientTile(loc.nutrientMagnesium, nutrients.magnesium, loc.unitMg),
            nutrientTile(loc.nutrientPotassium, nutrients.potassium, loc.unitMg),
            nutrientTile(loc.nutrientZinc, nutrients.zinc, loc.unitMg),
          ],
        ),
      ),
    );
  }

  Widget _buildPortionMarcroCalc() {
    final hasPortions = widget.portionOptions.isNotEmpty;

    // Build dropdown items: always include "g" (null unit) first,
    // then each API serving size.
    final unitItems = <DropdownMenuItem<PortionOption?>>[
      DropdownMenuItem<PortionOption?>(
        value: null,
        child: Text(AppLocalizations.of(context)!.quantityInGrams),
      ),
      if (hasPortions)
        ...widget.portionOptions.map(
          (p) {
            // Avoid "30g (30g)" — only append gram info when not already in label
            final alreadyHasGrams = RegExp(r'\d+\s*g', caseSensitive: false).hasMatch(p.label);
            final displayLabel = alreadyHasGrams ? p.label : '${p.label} (${p.grams}g)';
            return DropdownMenuItem<PortionOption?>(
              value: p,
              child: Text(displayLabel, overflow: TextOverflow.ellipsis),
            );
          },
        ),
    ];

    // Label for the left input: "Amount" in serving mode, "g" in grams mode
    final inputLabel = _selectedUnit == null
        ? AppLocalizations.of(context)!.quantityInGrams
        : AppLocalizations.of(context)!.portionLabel;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.portionSize,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // LEFT: quantity input
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: inputLabel,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
                      setState(() {
                        _portionInput = double.tryParse(cleaned) ?? 1.0;
                      });
                      _calculateNutrition();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                // RIGHT: unit dropdown (always visible; only serving sizes when available)
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<PortionOption?>(
                    value: _selectedUnit,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    items: unitItems,
                    onChanged: (unit) {
                      final currentGrams = _actualGrams;
                      setState(() {
                        _selectedUnit = unit;
                        if (unit == null) {
                          // Switching to gram mode — pre-fill with current actual grams
                          _portionInput = currentGrams.roundToDouble();
                          _quantityController.text = currentGrams.round().toString();
                        } else {
                          // Switching to portion mode — reset to 1 serving
                          _portionInput = 1.0;
                          _quantityController.text = '1';
                        }
                      });
                      _calculateNutrition();
                    },
                  ),
                ),
              ],
            ),
            // Show actual gram equivalent when in serving mode
            if (_selectedUnit != null) ...[
              const SizedBox(height: 8),
              Text(
                '= ${_actualGrams.round()} g',
                style: TextStyle(color: Theme.of(context).colorScheme.secondary),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAddToMealSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.isTemplate
              ? AppLocalizations.of(context)!.addToMealTemplate
              : AppLocalizations.of(context)!.addToTodayLog,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        // Show the selected category
        Text(
          '${AppLocalizations.of(context)!.mealCategory}: ${widget.category}',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 16),
        // Add to Daily Meal Log button - disabled if we're in template mode
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.green,
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade600,
          ),
          onPressed:
              widget.isTemplate
                  ? null
                  : () async {
                    final grams = _actualGrams;
                    final base = widget.foodItem.gramm > 0
                        ? widget.foodItem.gramm.toDouble()
                        : 100.0;
                    final newFoodId = await db.foodItemDao.insertFoodItem(
                      FoodItemCompanion.insert(
                        name: widget.foodItem.name,
                        calories: (widget.foodItem.calories * grams / base).round(),
                        protein: (widget.foodItem.protein * grams / base).round(),
                        carbs: (widget.foodItem.carbs * grams / base).round(),
                        fat: (widget.foodItem.fat * grams / base).round(),
                        gramm: Value(grams.round()),
                        extendedNutrientsJson: Value(
                          widget.foodItem.extendedNutrients?.scaleTo(grams).toJsonString(),
                        ),
                      ),
                    );
                    final newFood = await db.foodItemDao.getFoodItemById(newFoodId);
                    if (!mounted) return;
                    if (newFood != null) {
                      await _repository.addFoodToMeal(widget.category, newFood, date: widget.date);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${widget.foodItem.name} (${grams.round()}g) ${AppLocalizations.of(context)!.addedSuccessfully}',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                      Navigator.pop(context, true);
                    }
                  },
          child: Text(
            AppLocalizations.of(context)!.addToLog,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(height: 12),
        // Add to Template button - disabled if we're not in template mode
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade600,
          ),
          onPressed:
              !widget.isTemplate
                  ? null
                  : () {
                    final grams = _actualGrams;
                    final base = widget.foodItem.gramm > 0
                        ? widget.foodItem.gramm.toDouble()
                        : 100.0;
                    final updatedFoodItem = FoodItemModel(
                      id: widget.foodItem.id,
                      name: widget.foodItem.name,
                      calories: (widget.foodItem.calories * grams / base).round(),
                      protein: (widget.foodItem.protein * grams / base).round(),
                      carbs: (widget.foodItem.carbs * grams / base).round(),
                      fat: (widget.foodItem.fat * grams / base).round(),
                      gramm: grams.round(),
                    );
                    Navigator.pop(context, updatedFoodItem);
                  },
          child: Text(AppLocalizations.of(context)!.addToTemplate, style: const TextStyle(fontSize: 16)),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }
}
