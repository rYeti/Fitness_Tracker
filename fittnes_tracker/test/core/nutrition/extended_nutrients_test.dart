import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/nutrition/extended_nutrients.dart';

/// `rescale` and the null-preserving fold are the two pieces of logic behind
/// three real defects (see docs/trainer-console-micronutrients.md): a
/// re-added local food's micronutrients scaling by a different factor than
/// its macros, and a null nutrient reading as a reported zero once summed.
/// Neither is a type error — `ExtendedNutrients scaleTo(double)` compiled
/// fine while dividing by the wrong number every time it was called on
/// anything but a per-100g food.
void main() {
  group('rescale', () {
    test('scales every field by toGrams/fromGrams', () {
      const n = ExtendedNutrients(fiber: 10, iron: 0.005);
      final scaled = n.rescale(fromGrams: 50, toGrams: 100);

      expect(scaled.fiber, 20);
      expect(scaled.iron, 0.01);
    });

    test(
      'a food whose own serving is not 100g scales from that serving, '
      'not from an assumed 100g',
      () {
        // The defect this pins: a re-added local food's stored blob
        // represents its own base serving (say 250g), not 100g. The old
        // `scaleTo(grams)` unconditionally divided by 100, so logging 500g of
        // a 250g-based food scaled the macros by 2x (500/250) and the
        // micronutrients by 5x (500/100) — two different numbers for the same
        // food, on the same screen.
        const perTwoFifty = ExtendedNutrients(fiber: 25);
        final forFiveHundred = perTwoFifty.rescale(fromGrams: 250, toGrams: 500);

        expect(forFiveHundred.fiber, 50); // 2x, matching the macro scaling
        expect(forFiveHundred.fiber, isNot(125)); // NOT scaleTo's old 5x
      },
    );

    test('a null value stays null after rescaling', () {
      const n = ExtendedNutrients(fiber: 10);
      final scaled = n.rescale(fromGrams: 100, toGrams: 200);

      expect(scaled.fiber, 20);
      expect(scaled.iron, isNull);
    });

    test('is a no-op when the grams are equal', () {
      const n = ExtendedNutrients(fiber: 10);
      expect(identical(n.rescale(fromGrams: 100, toGrams: 100), n), isTrue);
    });
  });

  group('null-preserving fold', () {
    test('two nulls stay null, never a reported zero', () {
      const a = ExtendedNutrients();
      const b = ExtendedNutrients();
      final sum = a + b;

      expect(sum.iron, isNull);
    });

    test('one reported value plus one unreported one keeps the reported value', () {
      const a = ExtendedNutrients(iron: 5);
      const b = ExtendedNutrients();
      final sum = a + b;

      expect(sum.iron, 5);
    });

    test('two reported values add normally', () {
      const a = ExtendedNutrients(iron: 5);
      const b = ExtendedNutrients(iron: 3);
      final sum = a + b;

      expect(sum.iron, 8);
    });

    test('sum() of an empty list is all-null, not a claim of zero intake', () {
      final sum = ExtendedNutrients.sum(const []);
      expect(sum.hasAnyData, isFalse);
    });

    test('sum() folds a mix of reported and unreported fields per-nutrient', () {
      final sum = ExtendedNutrients.sum(const [
        ExtendedNutrients(fiber: 2, iron: 1),
        ExtendedNutrients(fiber: 3),
        ExtendedNutrients(),
      ]);

      expect(sum.fiber, 5);
      expect(sum.iron, 1);
      expect(sum.calcium, isNull);
    });
  });
}
