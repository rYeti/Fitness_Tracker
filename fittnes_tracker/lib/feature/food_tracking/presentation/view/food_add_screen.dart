// lib/feature/presentation/view/food_add_screen.dart
import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/providers/access_provider.dart';
import 'package:ForgeForm/core/utils/app_logger.dart';
import 'package:ForgeForm/feature/premium/paywall_screen.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../data/models/extended_nutrients.dart';
import '../../data/models/food_item_model.dart';
import '../../data/models/portion_option.dart';
import '../../data/repositories/nutrition_repository.dart';
import 'barcode_scanner_view.dart';
import 'food_detail_view.dart';

class FoodAddScreen extends StatefulWidget {
  final String category;
  final DateTime? date;

  const FoodAddScreen({super.key, required this.category, this.date});

  @override
  _FoodAddScreenState createState() => _FoodAddScreenState();
}

class _FoodAddScreenState extends State<FoodAddScreen> {
  late final AppDatabase db;
  late final NutritionRepository _repository;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _searchFailed = false; // true when network failed (show retry)
  String _searchError = '';
  List<Map<String, dynamic>> _localResults = [];
  List<Map<String, dynamic>> _apiResults = [];
  CancelToken _apiCancelToken = CancelToken();
  Timer? _debounce;
  String _lastSearchQuery = ''; // Track last search to prevent stale results

  // Reuse the same meal localization approach as food_tracking_screen
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
    db = Provider.of<AppDatabase>(context, listen: false);
    _repository = NutritionRepository(db);
    _repository.prewarmConnection();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _apiCancelToken.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _performSearch);
  }

  // ========== SEARCH HELPER METHODS ==========

  /// Normalize string: lowercase and trim whitespace
  String _norm(String s) => s.toLowerCase().trim();

  /// Remove diacritics (accents) for better multilingual matching
  String _removeDiacritics(String s) {
    const diacritics = {
      // German
      'ä': 'a', 'ö': 'o', 'ü': 'u', 'ß': 'ss',
      // French
      'à': 'a', 'â': 'a', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ç': 'c',
      'æ': 'ae', 'œ': 'oe',
      // Spanish/Portuguese
      'á': 'a', 'ã': 'a', 'í': 'i', 'ó': 'o', 'õ': 'o', 'ú': 'u', 'ñ': 'n',
      // Nordic
      'å': 'a',
      // General accents
      'ì': 'i', 'î': 'i', 'ï': 'i',
      'ò': 'o', 'ô': 'o',
      'ù': 'u', 'û': 'u',
    };

    String result = s;
    diacritics.forEach((key, value) {
      result = result.replaceAll(key, value);
    });
    return result;
  }

  /// Split string into words, removing punctuation and special characters
  List<String> _tokenize(String s) {
    return s
        .split(RegExp(r'[^a-z0-9äöüßàáâãäåèéêëìíîïòóôõöùúûüñç]+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Calculate Levenshtein distance (edit distance) between two strings
  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final m = a.length, n = b.length;
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));

    for (var i = 0; i <= m; i++) dp[i][0] = i;
    for (var j = 0; j <= n; j++) dp[0][j] = j;

    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    return dp[m][n];
  }

  /// OPTIMIZED food search scoring algorithm (lower = better)
  int _nameScore(String query, String name) {
    final qRaw = _norm(query);
    final nRaw = _norm(name);

    if (qRaw.isEmpty || nRaw.isEmpty) return 1000000;

    final q = _removeDiacritics(qRaw);
    final n = _removeDiacritics(nRaw);

    if (q == n) return 0;

    final nTokens = _tokenize(n);
    final qTokens = _tokenize(q);

    if (qTokens.isEmpty || nTokens.isEmpty) return 1000000;

    final queryTerm = qTokens.first;

    if (nTokens.length == 1 && nTokens.first == queryTerm) return 1;

    if (n.startsWith(q)) {
      final lengthDiff = n.length - q.length;
      // Short queries need a steep penalty so "Ei" doesn't rank
      // equally with "Eis" or "Eierlikör".
      final penalty = q.length <= 3 ? lengthDiff * 8 : lengthDiff ~/ 5;
      return 5 + penalty;
    }

    if (n.contains(' $q') || n.contains('-$q')) return 15;

    if (nTokens.first == queryTerm) {
      return 20 + (nTokens.length - 1) * 5;
    }

    if (nTokens.first.startsWith(queryTerm)) {
      return 30 +
          (nTokens.first.length - queryTerm.length) +
          (nTokens.length - 1) * 5;
    }

    for (int i = 1; i < nTokens.length; i++) {
      if (nTokens[i] == queryTerm) return 40 + i * 5;
    }

    for (int i = 1; i < nTokens.length; i++) {
      if (nTokens[i].startsWith(queryTerm)) {
        return 50 + (nTokens[i].length - queryTerm.length) + i * 5;
      }
    }

    if (queryTerm.length >= 3) {
      final tokensToCheck = nTokens.take(3);
      for (int idx = 0; idx < tokensToCheck.length; idx++) {
        final token = tokensToCheck.elementAt(idx);
        final lenDiff = (token.length - queryTerm.length).abs();
        if (lenDiff <= 2) {
          final dist = _levenshtein(token, queryTerm);
          if (dist <= 2) {
            return 100 + (dist * 20) + lenDiff + idx * 10;
          }
        }
      }
    }

    if (queryTerm.length >= 4) {
      for (int idx = 0; idx < nTokens.take(3).length; idx++) {
        final token = nTokens[idx];
        if (token.contains(queryTerm)) {
          return 200 + (token.length - queryTerm.length) + idx * 20;
        }
      }
    }

    return 1000000;
  }

  /// Extract the display name from a search result item
  String _itemName(dynamic item) {
    if (item is Map) {
      for (final k in ['product_name', 'name', 'title', 'label']) {
        final v = item[k];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString();
      }
      final brands = item['brands'];
      if (brands != null && brands.toString().trim().isNotEmpty) {
        return brands.toString();
      }
      return '';
    }
    try {
      final v = item.name;
      return v?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    final searchQuery = query;

    if (query.isEmpty) {
      setState(() {
        _localResults = [];
        _apiResults = [];
        _isSearching = false;
        _searchFailed = false;
        _lastSearchQuery = '';
      });
      return;
    }

    if (searchQuery == _lastSearchQuery &&
        (_localResults.isNotEmpty || _apiResults.isNotEmpty)) {
      return;
    }

    // Cancel any in-flight API request before starting a new one
    _apiCancelToken.cancel();
    _apiCancelToken = CancelToken();

    if (mounted) {
      setState(() {
        _isSearching = true;
        _searchFailed = false;
        _searchError = '';
      });
    }

    try {
      final localItems = await db.foodItemDao.getAllFoodItems();
      if (!mounted || _searchController.text.trim() != searchQuery) {
        if (mounted) setState(() => _isSearching = false);
        return;
      }

      final qLower = searchQuery.toLowerCase();

      // Deduplicate by name: keep only the highest-id item per name so that
      // the most recently saved version appears (avoids stale duplicate entries).
      final seen = <String, FoodItemData>{};
      for (final item in localItems) {
        final key = item.name.toLowerCase().trim();
        if (!seen.containsKey(key) || item.id > seen[key]!.id) {
          seen[key] = item;
        }
      }

      // Normalize calories to per-100g for the nutriments map so the search
      // list subtitle shows per-100g values consistently.
      final localAsMaps =
          seen.values
              .where((item) => item.name.toLowerCase().contains(qLower))
              .map((item) {
                final base = item.gramm > 0 ? item.gramm : 100;
                return <String, dynamic>{
                  'product_name': item.name,
                  'brands': 'My Foods',
                  'nutriments': {
                    'energy-kcal_100g': (item.calories * 100 / base).round(),
                    'proteins_100g': (item.protein * 100 / base).round(),
                    'carbohydrates_100g': (item.carbs * 100 / base).round(),
                    'fat_100g': (item.fat * 100 / base).round(),
                  },
                  'id': item.id.toString(),
                  '_source': 'local',
                  '_gramm': item.gramm,
                  '_calories_raw': item.calories,
                  '_protein_raw': item.protein,
                  '_carbs_raw': item.carbs,
                  '_fat_raw': item.fat,
                  '_extended_nutrients_json': item.extendedNutrientsJson,
                };
              })
              .toList();

      if (localAsMaps.isNotEmpty) {
        _updateResults(searchQuery, localAsMaps, [], stillLoading: true);
      }

      final locale = Localizations.localeOf(context);
      final fetchedApi = await _repository.searchFoods(
        searchQuery,
        languageCode: locale.languageCode,
        cancelToken: _apiCancelToken,
      );

      if (!mounted) return;
      if (_searchController.text.trim() != searchQuery) {
        if (mounted) setState(() => _isSearching = false);
        return;
      }

      _updateResults(searchQuery, localAsMaps, fetchedApi);
    } catch (e) {
      if (mounted && _searchController.text.trim() == searchQuery) {
        setState(() {
          _isSearching = false;
          // If local results are already showing, don't replace them with
          // an error banner — just silently stop the loading indicator.
          if (_localResults.isEmpty) {
            _searchFailed = true;
            _searchError = e.toString();
          }
        });
      }
    }
  }

  void _updateResults(
    String searchQuery,
    List<Map<String, dynamic>> localMaps,
    List<Map<String, dynamic>> apiMaps, {
    bool stillLoading = false,
  }) {
    if (!mounted || _searchController.text.trim() != searchQuery) return;

    List<Map<String, dynamic>> _score(List<Map<String, dynamic>> items) {
      final scored = items.take(100).toList();
      scored.sort((a, b) {
        final sa = _nameScore(searchQuery, _itemName(a));
        final sb = _nameScore(searchQuery, _itemName(b));
        if (sa != sb) return sa.compareTo(sb);
        return _itemName(a).length.compareTo(_itemName(b).length);
      });
      return scored
          .where((r) => _nameScore(searchQuery, _itemName(r)) < 400)
          .toList();
    }

    bool _hasNutrition(Map<String, dynamic> r) {
      if (r['_source'] == 'local') return true;
      final n = r['nutriments'] as Map?;
      if (n == null) return false;
      final cal = (n['energy-kcal_100g'] as num?)?.toDouble() ?? 0;
      final pro = (n['proteins_100g'] as num?)?.toDouble() ?? 0;
      final carbs = (n['carbohydrates_100g'] as num?)?.toDouble() ?? 0;
      final fat = (n['fat_100g'] as num?)?.toDouble() ?? 0;
      return cal > 0 || pro > 0 || carbs > 0 || fat > 0;
    }

    setState(() {
      _localResults = _score(localMaps);
      _apiResults = _score(apiMaps).where(_hasNutrition).take(30).toList();
      _lastSearchQuery = searchQuery;
      _isSearching = stillLoading;
    });
  }

  String _displayNameFromScanned(dynamic scanned) {
    if (scanned == null) return 'Unknown';
    if (scanned is String) return scanned;
    if (scanned is Map) {
      return scanned['product_name']?.toString() ??
          scanned['name']?.toString() ??
          scanned['brands']?.toString() ??
          'Unknown';
    }
    try {
      final name =
          (scanned.name ?? scanned.productName ?? scanned.product_name);
      if (name != null) return name.toString();
    } catch (_) {}
    return scanned.toString();
  }

  Future<void> _scanBarcode() async {
    final dynamic scanned = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => BarcodeScannerView(
              category: widget.category,
              isTemplate: false,
            ),
      ),
    );

    if (scanned == null || scanned is bool) return;

    try {
      await _repository.addFoodToMeal(widget.category, scanned, date: widget.date);
      await _loadFoodItems();
      final name = _displayNameFromScanned(scanned);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${name} ${AppLocalizations.of(context)!.addedSuccessfully}',
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        AppLogger.i('Error adding scanned food to meal: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context)!.addFailed}: ${e.toString()}',
          ),
        ),
      );
    }
  }

  Future<void> _loadFoodItems() async {}

  Future<void> _quickAddFromRecent(FoodItemData item) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(
      text: item.gramm > 0 ? item.gramm.toString() : '100',
    );
    final colorScheme = Theme.of(context).colorScheme;

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
            Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 2),
            Text(
              '${item.calories} kcal · P: ${item.protein}g · C: ${item.carbs}g · F: ${item.fat}g',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.55)),
            ),
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
                  child: Text(l10n.cancel),
                ),
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

    if (newGramm == null || !mounted) return;

    final base = item.gramm > 0 ? item.gramm : 100;
    final ratio = newGramm / base;

    final newFoodId = await db.foodItemDao.insertFoodItem(
      FoodItemCompanion.insert(
        name: item.name,
        calories: (item.calories * ratio).round(),
        protein: (item.protein * ratio).round(),
        carbs: (item.carbs * ratio).round(),
        fat: (item.fat * ratio).round(),
        gramm: Value(newGramm),
      ),
    );

    if (!mounted) return;
    final newFood = await db.foodItemDao.getFoodItemById(newFoodId);
    if (!mounted || newFood == null) return;

    await _repository.addFoodToMeal(widget.category, newFood, date: widget.date);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} (${newGramm}g) ${l10n.addedSuccessfully}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  List<PortionOption> _buildPortionOptions(Map<String, dynamic> productData) =>
      PortionOption.fromProductData(productData);

  void _selectFoodItem(Map<String, dynamic> productData) async {
    final isLocal = productData['_source'] == 'local';

    ExtendedNutrients? extended;
    if (isLocal) {
      final json = productData['_extended_nutrients_json'] as String?;
      if (json != null) extended = ExtendedNutrients.fromJsonString(json);
    } else {
      final nutriments = productData['nutriments'] as Map<String, dynamic>? ?? {};
      final ext = ExtendedNutrients.fromNutriments(nutriments);
      if (ext.hasAnyData) extended = ext;
    }

    // For local items use the raw stored values (per-portion) so that
    // _calculateNutrition divides by gramm correctly in the detail screen.
    // For API items use the nutriments map (values are per-100g, gramm=100).
    final foodItem = FoodItemModel(
      id: int.tryParse(productData['id']?.toString() ?? '') ?? 0,
      name: productData['product_name'] ?? productData['brands'] ?? 'Unknown',
      calories: isLocal
          ? (productData['_calories_raw'] as int? ??
              (productData['nutriments']?['energy-kcal_100g'] as num?)?.toInt() ?? 0)
          : (productData['nutriments']?['energy-kcal_100g'] as num?)?.toInt() ?? 0,
      protein: isLocal
          ? (productData['_protein_raw'] as int? ??
              (productData['nutriments']?['proteins_100g'] as num?)?.round() ?? 0)
          : (productData['nutriments']?['proteins_100g'] as num?)?.round() ?? 0,
      carbs: isLocal
          ? (productData['_carbs_raw'] as int? ??
              (productData['nutriments']?['carbohydrates_100g'] as num?)?.round() ?? 0)
          : (productData['nutriments']?['carbohydrates_100g'] as num?)?.round() ?? 0,
      fat: isLocal
          ? (productData['_fat_raw'] as int? ??
              (productData['nutriments']?['fat_100g'] as num?)?.round() ?? 0)
          : (productData['nutriments']?['fat_100g'] as num?)?.round() ?? 0,
      gramm: (productData['_gramm'] as int?) ?? 100,
      extendedNutrients: extended,
    );
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (context) => FoodDetailsScreen(
              foodItem: foodItem,
              category: widget.category,
              portionOptions: _buildPortionOptions(productData),
              date: widget.date,
            ),
      ),
    );
  }

  Future<void> _addCustomFood() async {
    final hasPremium = context.read<AccessProvider>().hasPremiumAccess;
    if (!hasPremium) {
      final count = await db.foodItemDao.countCustomFoodItems();
      if (!mounted) return;
      if (count >= 10) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PaywallScreen()),
        );
        return;
      }
    }
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final caloriesController = TextEditingController();
    final proteinController = TextEditingController();
    final carbsController = TextEditingController();
    final fatController = TextEditingController();

    // Holds the inserted food ID once the dialog confirms.
    int? insertedId;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Theme.of(dialogContext).colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          title: Text(
            AppLocalizations.of(dialogContext)!.addCustomFood,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Theme.of(dialogContext).colorScheme.onSurface,
            ),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogField(
                    nameController,
                    AppLocalizations.of(dialogContext)!.foodName,
                    validator:
                        (v) =>
                            (v == null || v.isEmpty)
                                ? AppLocalizations.of(dialogContext)!.pleaseEnterAName
                                : null,
                  ),
                  _dialogField(
                    caloriesController,
                    AppLocalizations.of(dialogContext)!.calories,
                    type: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return AppLocalizations.of(dialogContext)!.pleaseEnterCalories;
                      }
                      if (double.tryParse(v) == null) {
                        return AppLocalizations.of(dialogContext)!.pleaseEnterValidNumber;
                      }
                      return null;
                    },
                  ),
                  _dialogField(
                    proteinController,
                    AppLocalizations.of(dialogContext)!.protein,
                    type: const TextInputType.numberWithOptions(decimal: true),
                    validator:
                        (v) =>
                            (v == null || v.isEmpty || double.tryParse(v) == null)
                                ? AppLocalizations.of(dialogContext)!.pleaseEnterValidNumber
                                : null,
                  ),
                  _dialogField(
                    carbsController,
                    AppLocalizations.of(dialogContext)!.carbs,
                    type: const TextInputType.numberWithOptions(decimal: true),
                    validator:
                        (v) =>
                            (v == null || v.isEmpty || double.tryParse(v) == null)
                                ? AppLocalizations.of(dialogContext)!.pleaseEnterValidNumber
                                : null,
                  ),
                  _dialogField(
                    fatController,
                    AppLocalizations.of(dialogContext)!.fat,
                    type: const TextInputType.numberWithOptions(decimal: true),
                    validator:
                        (v) =>
                            (v == null || v.isEmpty || double.tryParse(v) == null)
                                ? AppLocalizations.of(dialogContext)!.pleaseEnterValidNumber
                                : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              child: Text(AppLocalizations.of(dialogContext)!.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final id = await db.foodItemDao.insertFoodItem(
                    FoodItemCompanion.insert(
                      name: nameController.text.trim(),
                      calories: double.parse(caloriesController.text).round(),
                      protein: double.parse(proteinController.text).round(),
                      carbs: double.parse(carbsController.text).round(),
                      fat: double.parse(fatController.text).round(),
                    ),
                  );
                  insertedId = id;
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: Text(AppLocalizations.of(dialogContext)!.addToLog),
            ),
          ],
        );
      },
    );

    if (!mounted || insertedId == null) return;

    final newFood = await db.foodItemDao.getFoodItemById(insertedId!);
    if (!mounted || newFood == null) return;

    await _repository.addFoodToMeal(widget.category, newFood, date: widget.date);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${newFood.name} ${AppLocalizations.of(context)!.addedSuccessfully}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _dialogField(
    TextEditingController controller,
    String label, {
    TextInputType type = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: colorScheme.onSurface.withValues(alpha: 0.07),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(
              color: colorScheme.onSurface.withValues(alpha: 0.10),
              width: 0.5,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(
              color: colorScheme.onSurface.withValues(alpha: 0.10),
              width: 0.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: colorScheme.primary, width: 1),
          ),
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(child: Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(
            context,
          )!.addFood(_localizedMealLabel(widget.category, context)),
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.searchForFood,
                  filled: true,
                  fillColor: colorScheme.surfaceContainerLow,
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.camera_alt_rounded,
                      color: colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                    onPressed: _scanBarcode,
                    tooltip: AppLocalizations.of(context)!.scanBarcode,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(
                      color: colorScheme.onSurface.withValues(alpha: 0.10),
                      width: 0.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(
                      color: colorScheme.onSurface.withValues(alpha: 0.10),
                      width: 0.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(color: colorScheme.primary, width: 1),
                  ),
                ),
                onChanged: (_) => _onSearchChanged(),
                onSubmitted: (_) => _performSearch(),
              ),
            ),
            if (_searchController.text.isEmpty && !_isSearching)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  AppLocalizations.of(context)!.recentlyAdded,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            Builder(
              builder: (context) {
                final hasQuery = _searchController.text.isNotEmpty;

                // ── No query → recent foods ──────────────────────────────
                if (!hasQuery) {
                  return StreamBuilder<List<FoodItemData>>(
                    stream: db.foodItemDao.watchVisibleFoodItems(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: CircularProgressIndicator(
                              color: colorScheme.primary,
                            ),
                          ),
                        );
                      }
                      // Deduplicate by name: keep the highest-id entry per name
                      // so that the most-recently-added version appears once.
                      final seen = <String, FoodItemData>{};
                      for (final item in snapshot.data!) {
                        final key = item.name.toLowerCase().trim();
                        if (!seen.containsKey(key) || item.id > seen[key]!.id) {
                          seen[key] = item;
                        }
                      }
                      final foodItems = seen.values.toList()
                        ..sort((a, b) => b.id.compareTo(a.id));
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: foodItems.length,
                        itemBuilder: (context, index) {
                          final item = foodItems[index];
                          return _foodListTile(
                            title: item.name,
                            subtitle:
                                '${item.calories} kcal | P: ${item.protein}g | C: ${item.carbs}g | F: ${item.fat}g',
                            onTap: () async {
                              await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => FoodDetailsScreen(
                                        foodItem: FoodItemModel(
                                          id: item.id,
                                          name: item.name,
                                          calories: item.calories,
                                          protein: item.protein,
                                          carbs: item.carbs,
                                          fat: item.fat,
                                          gramm: item.gramm,
                                        ),
                                        category: widget.category,
                                        date: widget.date,
                                      ),
                                ),
                              );
                            },
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: colorScheme.error,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      db.foodItemDao.hideFromRecent(item.name),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.add,
                                    color: colorScheme.primary,
                                    size: 20,
                                  ),
                                  onPressed: () => _quickAddFromRecent(item),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                }

                final hasAny = _localResults.isNotEmpty || _apiResults.isNotEmpty;

                // ── Waiting with no results yet → full spinner ───────────
                if (_isSearching && !hasAny) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: CircularProgressIndicator(
                        color: colorScheme.primary,
                      ),
                    ),
                  );
                }

                // ── Network failure ───────────────────────────────────────
                if (_searchFailed && !hasAny) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.wifi_off,
                            size: 56,
                            color: colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            AppLocalizations.of(context)!.couldNotReachFoodDatabase,
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _searchError,
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() => _lastSearchQuery = '');
                              _performSearch();
                            },
                            icon: const Icon(Icons.refresh),
                            label: Text(AppLocalizations.of(context)!.retry),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // ── No results found ──────────────────────────────────────
                if (!_isSearching && !hasAny) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 56,
                            color: colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            AppLocalizations.of(context)!.noResultsFor(_searchController.text),
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // ── Results: My Foods + Online Results sections ───────────
                Widget buildSection(
                  String label,
                  List<Map<String, dynamic>> items,
                ) {
                  if (items.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                      ...items.map(
                        (result) => _foodListTile(
                          title: _itemName(result).isNotEmpty
                              ? _itemName(result)
                              : 'Unknown',
                          subtitle: result['brands']?.toString() ?? 'Generic',
                          onTap: () => _selectFoodItem(result),
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isSearching)
                      LinearProgressIndicator(color: colorScheme.primary),
                    buildSection(
                      AppLocalizations.of(context)!.myFoods,
                      _localResults,
                    ),
                    buildSection(
                      AppLocalizations.of(context)!.onlineResults,
                      _apiResults,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCustomFood,
        elevation: 2,
        child: const Icon(Icons.add),
      ),
    ));
  }

  Widget _foodListTile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.onSurface.withValues(alpha: 0.10),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Exo 2',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Exo 2',
                        fontSize: 11,
                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
