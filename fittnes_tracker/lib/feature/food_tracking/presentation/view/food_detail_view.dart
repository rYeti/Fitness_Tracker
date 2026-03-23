import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/food_item_model.dart';
import '../../data/repositories/nutrition_repository.dart';

class PortionOption {
  final String label;
  final int grams;
  const PortionOption(this.label, this.grams);

  @override
  bool operator ==(Object other) =>
      other is PortionOption && other.grams == grams && other.label == label;

  @override
  int get hashCode => Object.hash(label, grams);
}

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
  }

  void _calculateNutrition() {
    final base = widget.foodItem.gramm > 0 ? widget.foodItem.gramm.toDouble() : 100.0;
    final grams = _actualGrams;
    setState(() {
      _calculatedCalories = widget.foodItem.calories * (grams / base);
      _calculatedProtein = widget.foodItem.protein * (grams / base);
      _calculatedCarbs = widget.foodItem.carbs * (grams / base);
      _calculatedFat = widget.foodItem.fat * (grams / base);
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
          (p) => DropdownMenuItem<PortionOption?>(
            value: p,
            child: Text('${p.label} (${p.grams}g)', overflow: TextOverflow.ellipsis),
          ),
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
                      setState(() => _selectedUnit = unit);
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
