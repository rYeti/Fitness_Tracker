/// The one place the client folds a meal category to a comparable key.
///
/// Mirrors `FitTracker.Api/Repositories/MealCategory.cs`. The app has written
/// snacks as both `Snack` and `Snacks` over its life, and this API's DTOs
/// document lowercase where the tracker capitalises, so nothing may compare a
/// raw category string — see `docs/trainer-nutrition-duplicate-meals.md`.
abstract final class MealCategory {
  /// The canonical spellings the tracker writes today.
  static const breakfast = 'Breakfast';
  static const lunch = 'Lunch';
  static const dinner = 'Dinner';
  static const snacks = 'Snacks';

  /// [category] reduced to the value comparisons key on: lowercased, trimmed,
  /// and with the `Snacks` rename folded onto the `snack` it replaced.
  static String key(String category) {
    final normalized = category.trim().toLowerCase();
    return normalized == 'snacks' ? 'snack' : normalized;
  }

  /// Whether two category strings name the same meal.
  static bool areSame(String a, String b) => key(a) == key(b);

  /// Every spelling that folds to [category]'s key, lowercased.
  ///
  /// SQL cannot express the fold itself, so a query that filters on category
  /// compares `lower(category)` against this list rather than one string.
  static List<String> spellings(String category) {
    final k = key(category);
    return k == 'snack' ? const ['snack', 'snacks'] : [k];
  }
}
