import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/food_item_model.dart';
import '../../data/models/meal_template.dart';
import '../../data/repositories/meal_template_repository.dart';
import 'food_add_screen.dart';
import 'package:ForgeForm/core/widgets/forge_app_bar.dart';

class EditMealTemplateScreen extends StatefulWidget {
  final MealTemplate template;

  const EditMealTemplateScreen({Key? key, required this.template})
    : super(key: key);

  @override
  State<EditMealTemplateScreen> createState() => _EditMealTemplateScreenState();
}

class _EditMealTemplateScreenState extends State<EditMealTemplateScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _batchWeightController;
  late String _selectedCategory;
  late List<MealTemplateItem> _selectedFoods;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template.name);
    _descriptionController = TextEditingController(
      text: widget.template.description ?? '',
    );
    _batchWeightController = TextEditingController(
      text: widget.template.totalWeightGrams != null
          ? widget.template.totalWeightGrams!.toStringAsFixed(0)
          : '',
    );
    _selectedCategory = widget.template.category;
    _selectedFoods = List.from(widget.template.items);
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: ForgeAppBar(
        title: l10n.editMealTemplate,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.templateName,
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.pleaseEnterAName;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: l10n.descriptionOptional,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _batchWeightController,
              decoration: InputDecoration(
                labelText: l10n.templateBatchWeight,
                hintText: l10n.templateBatchWeightHint,
                border: const OutlineInputBorder(),
                suffixText: 'g',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: l10n.category,
                border: const OutlineInputBorder(),
              ),
              initialValue: _selectedCategory,
              items: [
                DropdownMenuItem(value: 'Breakfast', child: Text(l10n.mealBreakfast)),
                DropdownMenuItem(value: 'Lunch',     child: Text(l10n.mealLunch)),
                DropdownMenuItem(value: 'Dinner',    child: Text(l10n.mealDinner)),
                DropdownMenuItem(value: 'Snacks',    child: Text(l10n.mealSnacks)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _selectedCategory = value);
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  l10n.foods,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _addFood,
                  icon: const Icon(Icons.add),
                  tooltip: l10n.add,
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._buildFoodItems(l10n),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saveTemplate,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Text(l10n.saveChanges),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFoodItems(AppLocalizations l10n) {
    if (_selectedFoods.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(l10n.noFoodsAdded),
          ),
        ),
      ];
    }

    return _selectedFoods.map((food) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
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
            templateId: widget.template.id ?? -1,
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
    final l10n = AppLocalizations.of(context)!;
    if (_formKey.currentState!.validate()) {
      if (_selectedFoods.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pleaseAddAtLeastOneFood)),
        );
        return;
      }

      final batchWeight = double.tryParse(_batchWeightController.text);
      final template = MealTemplate(
        id: widget.template.id,
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
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      repository
          .updateMealTemplate(template)
          .then((_) {
            navigator.pop(true);
            messenger.showSnackBar(
              SnackBar(content: Text(l10n.templateUpdatedSuccessfully)),
            );
          })
          .catchError((error) {
            messenger.showSnackBar(
              SnackBar(content: Text(l10n.errorCreatingTemplate(error))),
            );
          });
    }
  }
}
