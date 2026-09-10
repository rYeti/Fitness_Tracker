import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/nutrition/extended_nutrients.dart';
import 'package:ForgeForm/core/providers/access_provider.dart';
import 'package:ForgeForm/feature/food_tracking/presentation/view/food_add_screen.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// Re-logging a food from "Recently Added" used to lose its micronutrients
/// twice over, and neither loss was a type error: the tile built its
/// `FoodItemModel` field by field, listed the four macros, and stopped. The
/// model it produced was a perfectly valid `FoodItemModel` — just one whose
/// `extendedNutrients` happened to be null — so the detail screen drew no
/// Detailed Nutrition card, and the row it went on to insert carried a null
/// blob for the day's "Tracked nutrients" fold to find. Both screens were
/// individually correct; the food library row that held the data was never
/// asked for it.
///
/// So what's pinned here is the carry-through, end to end through the two
/// real screens: a stored food that has micronutrients still has them after
/// the round trip through the tile, the detail screen and the insert. See
/// `docs/trainer-console-micronutrients.md` §8.
///
/// 350 g of a food whose own serving *is* 350 g — the case that made the
/// scaling contract explicit (`rescale(fromGrams:toGrams:)`, never an
/// implicit per-100g). Fibre is stored and displayed in grams; iron is stored
/// in grams and displayed in mg, so the two together cover both sides of
/// `NutrientDef.gramsToDisplay`.
const _fibreGrams = 4.5;
const _ironGrams = 0.0042;

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.test(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> seedFood() => db.into(db.foodItem).insert(
        FoodItemCompanion.insert(
          name: 'Pizza Die Backfrische Mozzarella',
          calories: 746,
          protein: 35,
          carbs: 95,
          fat: 25,
          gramm: const Value(350),
          extendedNutrientsJson: Value(
            const ExtendedNutrients(fiber: _fibreGrams, iron: _ironGrams)
                .toJsonString(),
          ),
        ),
      );

  /// Bounded pumps rather than [WidgetTester.pumpAndSettle]: the recent list
  /// shows a `CircularProgressIndicator` until its drift stream emits, and an
  /// indeterminate spinner never settles — `pumpAndSettle` sits on it for its
  /// full ten-minute timeout instead of failing.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpFoodAdd(WidgetTester tester) async {
    // Both screens are tall scroll views; a default 800x600 viewport puts the
    // nutrient rows and the "Add to log" button outside the hit-test area.
    tester.view.physicalSize = const Size(600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: db),
          ChangeNotifierProvider<AccessProvider>.value(
            // The Detailed Nutrition card is premium-gated; without this the
            // screen renders the upgrade prompt and the rows never exist.
            value: AccessProvider.withState(isPremium: true),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FoodAddScreen(category: 'Breakfast'),
        ),
      ),
    );
    await settle(tester);
  }

  /// Tear the tree down *inside* the test body, then let the clock run.
  ///
  /// Two timers outlive these screens and both fail the test if they are
  /// still pending when the framework disposes the tree for us. Drift arms a
  /// zero-duration `StreamQueryStore.markAsClosed` timer when the recent
  /// list's `StreamBuilder` cancels its subscription, and
  /// `FoodAddScreen.initState` fires `NutritionRepository.prewarmConnection()`
  /// — a fire-and-forget HEAD to OpenFoodFacts that fails at once against
  /// `flutter_test`'s stub HttpClient but has already armed Dio's
  /// `receiveTimeout`. Unmounting first and then advancing past both retires
  /// them; neither is anything this test is about.
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 30));
  }

  Future<void> openRecentFood(WidgetTester tester) async {
    await tester.tap(find.text('Pizza Die Backfrische Mozzarella'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // route transition
  }

  testWidgets(
    'a food opened from Recently Added shows its micronutrients',
    (tester) async {
      await seedFood();
      await pumpFoodAdd(tester);
      await openRecentFood(tester);

      expect(find.text('Detailed Nutrition'), findsOneWidget);
      // Quantity defaults to the food's own 350 g, so the stored blob is
      // rescaled by 1 and reaches the screen unchanged — 4.5 g of fibre, and
      // 0.0042 g of iron converted to its display unit.
      expect(find.text('Fibre'), findsOneWidget);
      expect(find.text('4.50 g'), findsOneWidget);
      expect(find.text('Iron'), findsOneWidget);
      expect(find.text('4.20 mg'), findsOneWidget);

      await disposeTree(tester);
    },
  );

  testWidgets(
    "re-logging it writes a row the day's nutrient fold can see",
    (tester) async {
      await seedFood();
      await pumpFoodAdd(tester);
      await openRecentFood(tester);

      await tester.ensureVisible(find.text('Add to log'));
      await settle(tester);
      await tester.tap(find.text('Add to log'));
      await settle(tester);

      // The logged row is a *new* FoodItem, not the library entry it came
      // from — so it needs its own copy of the blob. This is exactly the
      // value `FoodTrackingScreen._dayMicronutrients` folds over.
      final rows = await db.foodItemDao.getAllFoodItems();
      expect(rows, hasLength(2));
      final logged = rows.last;
      expect(logged.gramm, 350);
      expect(logged.extendedNutrientsJson, isNotNull);

      final nutrients =
          ExtendedNutrients.fromJsonString(logged.extendedNutrientsJson!);
      expect(nutrients.fiber, closeTo(_fibreGrams, 1e-9));
      expect(nutrients.iron, closeTo(_ironGrams, 1e-9));
      // Nobody reported these, so they must stay silent rather than become a
      // reported zero — the rule the whole feature is built on.
      expect(nutrients.sugar, isNull);
      expect(nutrients.vitaminC, isNull);

      await disposeTree(tester);
    },
  );

  testWidgets(
    "the tile's quick-add carries them too, rescaled to the weight typed",
    (tester) async {
      await seedFood();
      await pumpFoodAdd(tester);

      // The `+` on the tile logs the food without ever opening the detail
      // screen, writing its own row — so it owes that row the same blob, and
      // owes it at the weight the user just typed rather than at the food's
      // stored serving.
      await tester
          .tap(find.byTooltip('Quick add Pizza Die Backfrische Mozzarella'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // sheet transition

      await tester.enterText(
        find.ancestor(
          of: find.text('Portion (g)'),
          matching: find.byType(TextField),
        ),
        '700',
      );
      await settle(tester);
      await tester.tap(find.text('Update'));
      await settle(tester);

      final rows = await db.foodItemDao.getAllFoodItems();
      expect(rows, hasLength(2));
      final logged = rows.last;
      expect(logged.gramm, 700);

      final nutrients =
          ExtendedNutrients.fromJsonString(logged.extendedNutrientsJson!);
      // Double the food's own 350 g serving, so double its micronutrients —
      // `rescale(fromGrams: 350)`. A hardcoded per-100g basis would have
      // produced seven times these, disagreeing with the macros written by
      // the very same lines. See `docs/trainer-console-micronutrients.md` §1b.
      expect(nutrients.fiber, closeTo(_fibreGrams * 2, 1e-9));
      expect(nutrients.iron, closeTo(_ironGrams * 2, 1e-9));

      await disposeTree(tester);
    },
  );
}
