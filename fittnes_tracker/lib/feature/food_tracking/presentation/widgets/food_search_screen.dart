import 'package:ForgeForm/core/app_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/repositories/nutrition_repository.dart';
import 'package:drift/drift.dart' as drift;

class FoodSearchScreen extends StatefulWidget {
  final bool allowMultipleSelection;

  const FoodSearchScreen({Key? key, this.allowMultipleSelection = false})
    : super(key: key);

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<FoodItemData> _foodItems = [];
  List<FoodItemData> _selectedItems = [];
  bool _isLoading = true;
  bool _isSearching = false;
  late NutritionRepository _repository;
  List<dynamic> _searchResults = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Add listener to tab controller to clear search results when changing tabs
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          // Clear search results when switching tabs
          _searchResults = [];
        });
      }
    });

    // We'll load food items after the widget is fully initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final database = Provider.of<AppDatabase>(context, listen: false);
      _repository = NutritionRepository(database);
      _loadFoodItems();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFoodItems() async {
    // Get the database from the Provider
    final database = Provider.of<AppDatabase>(context, listen: false);
    final items = await database.foodItemDao.getAllFoodItems();

    // Only update state if the widget is still mounted
    if (mounted) {
      setState(() {
        _foodItems = items;
        _isLoading = false;
      });
    }
  }

  List<FoodItemData> _getFilteredItems() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      return _foodItems;
    }
    return _foodItems
        .where((item) => item.name.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await _repository.searchFoods(query);

      // Sort results by relevance
      results.sort((a, b) {
        final nameA = _itemName(a).toLowerCase();
        final nameB = _itemName(b).toLowerCase();

        // Exact matches first
        final exactMatchA = nameA == query.toLowerCase();
        final exactMatchB = nameB == query.toLowerCase();
        if (exactMatchA && !exactMatchB) return -1;
        if (!exactMatchA && exactMatchB) return 1;

        // Then starts-with matches
        final startsWithA = nameA.startsWith(query.toLowerCase());
        final startsWithB = nameB.startsWith(query.toLowerCase());
        if (startsWithA && !startsWithB) return -1;
        if (!startsWithA && startsWithB) return 1;

        // Then by length (shorter names first)
        return nameA.length - nameB.length;
      });

      setState(() {
        _searchResults = results.take(30).toList();
        _isSearching = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
        setState(() => _isSearching = false);
      }
    }
  }

  String _itemName(dynamic item) {
    // Handle both FoodItemData and API response items
    if (item is Map) {
      return (item['product_name'] ?? item['name'] ?? '').toString();
    }
    return '';
  }

  Future<void> _addFoundFoodToDatabase(Map<String, dynamic> foodData) async {
    try {
      // Extract food data
      final String name = _itemName(foodData);

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              Text('Adding $name to your foods...'),
            ],
          ),
          duration: const Duration(seconds: 1),
        ),
      );

      // Parse nutritional information
      final Map<String, dynamic> nutrients = foodData['nutriments'] ?? {};
      final int calories = _parseNutrient(
        nutrients['energy-kcal_100g'] ?? nutrients['energy-kcal'] ?? 0,
      );
      final int protein = _parseNutrient(
        nutrients['proteins_100g'] ?? nutrients['proteins'] ?? 0,
      );
      final int carbs = _parseNutrient(
        nutrients['carbohydrates_100g'] ?? nutrients['carbohydrates'] ?? 0,
      );
      final int fat = _parseNutrient(
        nutrients['fat_100g'] ?? nutrients['fat'] ?? 0,
      );

      // Create food item
      final foodId = await _repository.db.foodItemDao.insertFoodItem(
        FoodItemCompanion.insert(
          name: name,
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
          gramm: const drift.Value(100),
        ),
      );

      // Get the created food item and add it to selection
      final foodItem = await _repository.db.foodItemDao.getFoodItemById(foodId);
      if (foodItem != null) {
        _toggleItemSelection(foodItem);

        // Add to local list for immediate availability
        setState(() {
          _foodItems = [..._foodItems, foodItem];
        });
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name added to your foods'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Switch to My Foods tab
      _tabController.animateTo(0);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding food: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  int _parseNutrient(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      try {
        return double.parse(value).round();
      } catch (e) {
        return 0;
      }
    }
    return 0;
  }

  void _toggleItemSelection(FoodItemData item) {
    setState(() {
      if (_selectedItems.contains(item)) {
        _selectedItems.remove(item);
      } else {
        if (widget.allowMultipleSelection) {
          _selectedItems.add(item);
        } else {
          _selectedItems = [item];
          // If single selection, return immediately
          Navigator.pop(context, _selectedItems);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _getFilteredItems();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Food'),
        actions:
            widget.allowMultipleSelection && _selectedItems.isNotEmpty
                ? [
                  TextButton(
                    onPressed: () => Navigator.pop(context, _selectedItems),
                    child: Text('Done (${_selectedItems.length})'),
                  ),
                ]
                : null,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'My Foods'), Tab(text: 'Search Online')],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Foods',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              // Clear search results
                              _searchResults = [];
                            });
                          },
                        )
                        : null,
              ),
              onChanged: (_) {
                setState(() {});
                // If we're on the online search tab and the text is not empty,
                // perform search automatically after a short delay
                if (_tabController.index == 1 &&
                    _searchController.text.trim().isNotEmpty) {
                  // Debounce the search to avoid too many requests
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted && _searchController.text.trim().isNotEmpty) {
                      _performSearch();
                    }
                  });
                }
              },
              onSubmitted: (_) {
                // If we're on the online search tab, perform search
                if (_tabController.index == 1) {
                  _performSearch();
                }
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Local foods tab
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredItems.isEmpty
                    ? const Center(child: Text('No local foods found'))
                    : ListView.builder(
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final isSelected = _selectedItems.contains(item);
                        return ListTile(
                          title: Text(item.name),
                          subtitle: Text(
                            '${item.calories} cal • ${item.protein}g protein • ${item.carbs}g carbs • ${item.fat}g fat',
                          ),
                          trailing:
                              widget.allowMultipleSelection
                                  ? Checkbox(
                                    value: isSelected,
                                    onChanged:
                                        (_) => _toggleItemSelection(item),
                                  )
                                  : const Icon(Icons.keyboard_arrow_right),
                          onTap: () => _toggleItemSelection(item),
                        );
                      },
                    ),

                // Online search tab
                _buildOnlineSearchTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineSearchTab() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchController.text.isEmpty) {
      return const Center(
        child: Text('Enter search terms to find foods online'),
      );
    }

    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('No results found for this search'),
          const SizedBox(height: 8),
          const Text('Try using more general terms or check spelling'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _performSearch,
            child: const Text('Try Again'),
          ),
        ],
      );
    }

    return Column(
      children: [
        if (_searchResults.isEmpty && !_isSearching)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: _performSearch,
              child: const Text('Search Online'),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final item = _searchResults[index];
              final name = _itemName(item);

              // Extract nutritional data
              final Map<String, dynamic> nutrients = item['nutriments'] ?? {};
              final calories = _parseNutrient(
                nutrients['energy-kcal_100g'] ?? nutrients['energy-kcal'] ?? 0,
              );
              final protein = _parseNutrient(
                nutrients['proteins_100g'] ?? nutrients['proteins'] ?? 0,
              );
              final carbs = _parseNutrient(
                nutrients['carbohydrates_100g'] ??
                    nutrients['carbohydrates'] ??
                    0,
              );
              final fat = _parseNutrient(
                nutrients['fat_100g'] ?? nutrients['fat'] ?? 0,
              );

              final String brand = (item['brands'] ?? '').toString();

              return ListTile(
                title: Text(name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (brand.isNotEmpty) Text('Brand: $brand'),
                    Text(
                      '$calories cal • ${protein}g protein • ${carbs}g carbs • ${fat}g fat',
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _addFoundFoodToDatabase(item),
                ),
                isThreeLine: brand.isNotEmpty,
              );
            },
          ),
        ),
      ],
    );
  }
}
