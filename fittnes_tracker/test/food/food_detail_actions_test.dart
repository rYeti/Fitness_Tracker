import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/feature/food_tracking/data/models/food_item_model.dart';
import 'package:ForgeForm/feature/food_tracking/presentation/view/food_detail_view.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// The food detail screen used to render both of its actions all the time and
/// disable the one that didn't apply. Nothing about that is a type error, and
/// no test could fail on it: a caller that forgot `isTemplate` still compiled,
/// still built, still showed two buttons — one of them dead. The only symptom
/// was a trainee tapping "Add to Template" while building a template and
/// nothing happening.
///
/// So what's pinned here isn't "the button works". It's that exactly one
/// action is on screen, and that it's the one the caller asked for.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.test(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// The detail screen is a tall scroll view; the actions sit at the bottom of
  /// it. A default 800x600 test viewport puts them outside the hit-test area,
  /// so give every case room rather than scrolling in each one.
  void giveRoom(WidgetTester tester) {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pump(WidgetTester tester, {required bool isTemplate}) async {
    giveRoom(tester);
    await tester.pumpWidget(
      Provider<AppDatabase>.value(
        value: db,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FoodDetailsScreen(
            foodItem: FoodItemModel(
              id: 1,
              name: 'Rolled oats',
              calories: 379,
              protein: 13,
              carbs: 67,
              fat: 7,
              gramm: 100,
            ),
            category: 'Breakfast',
            isTemplate: isTemplate,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('template mode offers only "Add to Template"', (tester) async {
    await pump(tester, isTemplate: true);

    expect(find.widgetWithText(FilledButton, 'Add to Template'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add to log'), findsNothing);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Add to Template'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('log mode offers only "Add to log"', (tester) async {
    await pump(tester, isTemplate: false);

    expect(find.widgetWithText(FilledButton, 'Add to log'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add to Template'), findsNothing);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Add to log'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('template mode hands the scaled food back to the caller', (
    tester,
  ) async {
    FoodItemModel? returned;

    giveRoom(tester);
    await tester.pumpWidget(
      Provider<AppDatabase>.value(
        value: db,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    returned = await Navigator.push<FoodItemModel>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FoodDetailsScreen(
                          foodItem: FoodItemModel(
                            id: 1,
                            name: 'Rolled oats',
                            calories: 379,
                            protein: 13,
                            carbs: 67,
                            fat: 7,
                            gramm: 100,
                          ),
                          category: 'Breakfast',
                          isTemplate: true,
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 50 g of a food stored per 100 g — the template gets the scaled copy,
    // not the raw library row.
    await tester.enterText(find.byType(TextField).first, '50');
    await tester.pumpAndSettle();
    final action = find.widgetWithText(FilledButton, 'Add to Template');
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(returned, isNotNull);
    expect(returned!.gramm, 50);
    expect(returned!.calories, 190);
    expect(returned!.protein, 7);
  });
}
