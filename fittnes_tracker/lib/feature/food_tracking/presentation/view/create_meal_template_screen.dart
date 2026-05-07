import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/utils/app_logger.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../data/models/meal_template.dart';
import '../../data/repositories/meal_template_repository.dart';
import '../widgets/food_search_screen.dart';
import 'barcode_scanner_view.dart';
import '../../data/models/food_item_model.dart';

class CreateMealTemplateScreen extends StatefulWidget {
  final String? initialCategory;

  const CreateMealTemplateScreen({Key? key, this.initialCategory})
    : super(key: key);

  @override
  State<CreateMealTemplateScreen> createState() =>
      _CreateMealTemplateScreenState();
}

class _CreateMealTemplateScreenState extends State<CreateMealTemplateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'Breakfast';
  List<MealTemplateItem> _selectedFoods = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF333333),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          loc.createMealTemplate,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: Colors.white,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: loc.templateName,
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return loc.pleaseEnterAName;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: loc.descriptionOptional,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: loc.category,
                border: const OutlineInputBorder(),
              ),
              value: _selectedCategory,
              items: [
                DropdownMenuItem(value: 'Breakfast', child: Text(loc.mealBreakfast)),
                DropdownMenuItem(value: 'Lunch', child: Text(loc.mealLunch)),
                DropdownMenuItem(value: 'Dinner', child: Text(loc.mealDinner)),
                DropdownMenuItem(value: 'Snack', child: Text(loc.mealSnacks)),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  loc.food,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _scanBarcode,
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: loc.scan,
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.deepPurple,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addFood,
                  icon: const Icon(Icons.add),
                  tooltip: loc.add,
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // List of selected foods
            ..._buildFoodsList(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveTemplate,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Text(loc.saveTemplate),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFoodsList() {
    final loc = AppLocalizations.of(context)!;
    if (_selectedFoods.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(loc.noFoodAdded),
          ),
        ),
      ];
    }

    return _selectedFoods.map((food) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(food.foodName),
          subtitle: Text(
            '${food.quantity} ${food.unit} • ${food.calories.toStringAsFixed(0)} cal',
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              setState(() {
                _selectedFoods.remove(food);
              });
            },
          ),
        ),
      );
    }).toList();
  }

  void _addFood() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => const FoodSearchScreen(allowMultipleSelection: true),
      ),
    );

    if (result != null && result is List<FoodItemData>) {
      setState(() {
        _selectedFoods.addAll(
          result.map(
            (food) => MealTemplateItem(
              templateId: -1,
              foodId: food.id,
              foodName: food.name,
              quantity: food.gramm.toDouble(),
              unit: 'g',
              calories: food.calories.toDouble(),
              protein: food.protein.toDouble(),
              carbs: food.carbs.toDouble(),
              fat: food.fat.toDouble(),
            ),
          ),
        );
      });
    }
  }

  void _scanBarcode() async {
    final loc = AppLocalizations.of(context)!;
    if (kIsWeb) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.barcodeNotSupportedOnWeb)));
      return;
    }

    try {
      final scannedFood = await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => BarcodeScannerView(
                category: _selectedCategory,
                isTemplate: true,
              ),
        ),
      );

      if (scannedFood != null) {
        if (scannedFood is FoodItemModel) {
          setState(() {
            _selectedFoods.add(
              MealTemplateItem(
                templateId: -1,
                foodId: scannedFood.id ?? 0,
                foodName: scannedFood.name,
                quantity: scannedFood.gramm.toDouble(),
                unit: 'g',
                calories: scannedFood.calories.toDouble(),
                protein: scannedFood.protein.toDouble(),
                carbs: scannedFood.carbs.toDouble(),
                fat: scannedFood.fat.toDouble(),
              ),
            );
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.addedToTemplate(scannedFood.name)),
              backgroundColor: Colors.green,
            ),
          );
        } else if (scannedFood is FoodItemData) {
          setState(() {
            _selectedFoods.add(
              MealTemplateItem(
                templateId: -1,
                foodId: scannedFood.id,
                foodName: scannedFood.name,
                quantity: scannedFood.gramm.toDouble(),
                unit: 'g',
                calories: scannedFood.calories.toDouble(),
                protein: scannedFood.protein.toDouble(),
                carbs: scannedFood.carbs.toDouble(),
                fat: scannedFood.fat.toDouble(),
              ),
            );
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.addedToTemplate(scannedFood.name)),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.i('Error scanning barcode: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorScanningBarcode(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _saveTemplate() {
    final loc = AppLocalizations.of(context)!;
    if (_formKey.currentState!.validate()) {
      if (_selectedFoods.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.pleaseAddAtLeastOneFood)));
        return;
      }

      final template = MealTemplate(
        name: _nameController.text,
        description: _descriptionController.text,
        category: _selectedCategory,
        items: _selectedFoods,
      );

      final repository = Provider.of<MealTemplateRepository>(
        context,
        listen: false,
      );
      repository
          .createMealTemplate(template)
          .then((_) {
            Navigator.pop(context, true);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(loc.templateCreatedSuccessfully)),
            );
          })
          .catchError((error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(loc.errorCreatingTemplate(error))),
            );
          });
    }
  }
}
