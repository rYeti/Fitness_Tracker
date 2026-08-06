import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/food_item_model.dart';
import '../../data/models/meal_template.dart';
import '../../data/repositories/meal_template_repository.dart';
import 'food_add_screen.dart';

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
  final _batchWeightController = TextEditingController();
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
    _batchWeightController.dispose();
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
            TextFormField(
              controller: _batchWeightController,
              decoration: InputDecoration(
                labelText: loc.templateBatchWeight,
                hintText: loc.templateBatchWeightHint,
                border: const OutlineInputBorder(),
                suffixText: 'g',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: loc.category,
                border: const OutlineInputBorder(),
              ),
              initialValue: _selectedCategory,
              items: [
                DropdownMenuItem(value: 'Breakfast', child: Text(loc.mealBreakfast)),
                DropdownMenuItem(value: 'Lunch', child: Text(loc.mealLunch)),
                DropdownMenuItem(value: 'Dinner', child: Text(loc.mealDinner)),
                DropdownMenuItem(value: 'Snacks', child: Text(loc.mealSnacks)),
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
    final result = await Navigator.push<FoodItemModel>(
      context,
      MaterialPageRoute(
        builder: (context) => FoodAddScreen(
          category: _selectedCategory,
          isTemplate: true,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedFoods.add(
          MealTemplateItem(
            templateId: -1,
            foodId: result.id ?? 0,
            foodName: result.name,
            quantity: result.gramm.toDouble(),
            unit: 'g',
            calories: result.calories.toDouble(),
            protein: result.protein.toDouble(),
            carbs: result.carbs.toDouble(),
            fat: result.fat.toDouble(),
          ),
        );
      });
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

      final batchWeight = double.tryParse(_batchWeightController.text);
      final template = MealTemplate(
        name: _nameController.text,
        description: _descriptionController.text,
        category: _selectedCategory,
        items: _selectedFoods,
        totalWeightGrams: batchWeight,
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
