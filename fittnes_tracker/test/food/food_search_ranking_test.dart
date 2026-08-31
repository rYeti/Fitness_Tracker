import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/feature/food_tracking/domain/food_search_ranking.dart';

/// The ranking algorithm shipped untested inside a 1,582-line widget. Nothing
/// in it needs a widget tree, and nothing about a wrong answer is visible:
/// a mis-tuned penalty or a missing diacritic produces a result list that
/// still renders, still scrolls, and is simply worse. These tests assert the
/// *ordering* — which is the only observable the algorithm actually has.
void main() {
  /// Ranking is comparative, so most assertions read better as "this beats
  /// that" than as a bare number. Absolute scores are pinned only where the
  /// band boundary itself is the contract.
  void expectRanksAbove(String query, String better, String worse) {
    final b = nameScore(query, better);
    final w = nameScore(query, worse);
    expect(
      b,
      lessThan(w),
      reason: '"$better" ($b) should rank above "$worse" ($w) for "$query"',
    );
  }

  group('normalisation', () {
    test('case and surrounding whitespace do not affect the score', () {
      expect(nameScore('  BANANA ', 'banana'), nameScore('banana', 'Banana'));
      expect(nameScore('Banana', 'banana'), 0);
    });

    test('an empty query or an empty name never matches', () {
      expect(nameScore('', 'banana'), noMatch);
      expect(nameScore('banana', ''), noMatch);
      expect(nameScore('   ', 'banana'), noMatch);
    });

    test('punctuation-only input tokenises to nothing rather than throwing', () {
      expect(nameScore('---', '...'), noMatch);
    });
  });

  group('diacritic folding', () {
    test('an accent-free query matches an accented name', () {
      // Someone typing on a UK keyboard should still find "Eierlikör".
      expect(nameScore('eierlikor', 'Eierlikör'), 0);
      expect(nameScore('creme', 'Crème'), 0);
    });

    test('ss and ß are the same word', () {
      // Folding ß to a bare "s" would leave "weissbrot" an edit away from
      // "weisbrot" instead of equal to it.
      expect(removeDiacritics('weißbrot'), 'weissbrot');
      expect(nameScore('weissbrot', 'Weißbrot'), 0);
    });

    test('folding is applied to both sides', () {
      expect(nameScore('Müsli', 'Muesli'.replaceAll('ue', 'ü')), 0);
    });
  });

  group('tokenize', () {
    test('splits on punctuation and drops the empties', () {
      expect(tokenize('fettsaure c22:6 n-3 all-cis'), [
        'fettsaure',
        'c22',
        '6',
        'n',
        '3',
        'all',
        'cis',
      ]);
    });

    test('keeps accented characters as word characters', () {
      expect(tokenize('eierlikör creme'), ['eierlikör', 'creme']);
    });
  });

  group('levenshtein', () {
    test('identical strings are distance zero', () {
      expect(levenshtein('quark', 'quark'), 0);
    });

    test('an empty side costs the other side length', () {
      expect(levenshtein('', 'quark'), 5);
      expect(levenshtein('quark', ''), 5);
    });

    test('counts substitutions, insertions and deletions alike', () {
      expect(levenshtein('quark', 'qark'), 1); // deletion
      expect(levenshtein('quark', 'quarks'), 1); // insertion
      expect(levenshtein('quark', 'quork'), 1); // substitution
      expect(levenshtein('kitten', 'sitting'), 3);
    });

    test('is symmetric', () {
      expect(levenshtein('banane', 'banana'), levenshtein('banana', 'banane'));
    });
  });

  group('score bands', () {
    test('an exact match beats everything', () {
      expect(nameScore('banana', 'Banana'), 0);
      expectRanksAbove('banana', 'Banana', 'Banana bread');
    });

    test('a single-token name equal to the query scores just below exact', () {
      // "banana" vs "Banana," — the name tokenises to one token that equals
      // the query, but the raw strings differ.
      expect(nameScore('banana', 'Banana,'), 1);
    });

    test('a prefix match beats a word-boundary match', () {
      expectRanksAbove('choc', 'Chocolate bar', 'Dark choc bar');
    });

    test('the word-boundary band is flat — position and length do not count', () {
      // Not an assertion that this is *right*; an assertion of what it does.
      // Every other band pays for distance (later tokens add `i * 5`, prefixes
      // pay for the length they overshoot by), but a match after a space or a
      // hyphen returns a constant 15 wherever it sits. So a two-word name and
      // a four-word one tie, and the sort falls through to its tiebreaker —
      // shorter display name first — which happens to recover the sensible
      // order here by accident rather than by design.
      expect(nameScore('milk', 'Whole milk'), 15);
      expect(nameScore('milk', 'Coconut milk drink powder'), 15);
    });

    test('an unrelated name does not match at all', () {
      expect(nameScore('banana', 'Rindersteak'), noMatch);
    });
  });

  group('the short-query prefix penalty', () {
    // The source calls this case out by name: without the steep penalty for
    // queries of 3 characters or fewer, "Ei" ranked a liqueur alongside the
    // egg someone was actually looking for.
    test('"Ei" prefers Ei, then Eis, then Eierlikör', () {
      final scores = {
        'Ei': nameScore('Ei', 'Ei'),
        'Eis': nameScore('Ei', 'Eis'),
        'Eierlikör': nameScore('Ei', 'Eierlikör'),
      };
      expect(scores['Ei'], lessThan(scores['Eis']!));
      expect(scores['Eis'], lessThan(scores['Eierlikör']!));
    });

    test('a long query is penalised gently, so a qualifier is not fatal', () {
      // 8 characters of extra name costs 1 point here and 64 above.
      final long = nameScore('haferflocken', 'Haferflocken zart');
      final short = nameScore('haf', 'Haferflocken zart');
      expect(long, lessThan(short));
    });
  });

  group('fuzzy matching', () {
    test('a one-character typo still finds the product', () {
      expect(nameScore('bananna', 'Bananna'.replaceAll('nn', 'n')), lessThan(noMatch));
      expect(nameScore('quork', 'Quark'), lessThan(noMatch));
    });

    test('a closer typo ranks above a further one', () {
      expectRanksAbove('quork', 'Quark', 'Quirky');
    });

    test('queries under 3 characters are not fuzzy-matched', () {
      // Two characters are too few to tell a typo from a different word, and
      // fuzzing them would flood the list.
      expect(nameScore('qu', 'Ei'), noMatch);
    });

    test('a substring hit is the last resort and needs 4 characters', () {
      expect(nameScore('kase', 'Frischkaseaufstrich'), greaterThanOrEqualTo(100));
      expect(nameScore('kas', 'Frischkaseaufstrich'), noMatch);
    });
  });

  group('itemName', () {
    test('prefers the name keys in order', () {
      expect(itemName({'product_name': 'Skyr', 'name': 'x'}), 'Skyr');
      expect(itemName({'name': 'Skyr', 'title': 'x'}), 'Skyr');
      expect(itemName({'title': 'Skyr'}), 'Skyr');
      expect(itemName({'label': 'Skyr'}), 'Skyr');
    });

    test('falls back to the brand only when no name is populated', () {
      expect(itemName({'product_name': '  ', 'brands': 'Arla'}), 'Arla');
      expect(itemName({'product_name': 'Skyr', 'brands': 'Arla'}), 'Skyr');
    });

    test('an item with nothing usable yields an empty string, not a crash', () {
      expect(itemName(<String, dynamic>{}), '');
      expect(itemName({'product_name': '   ', 'brands': ''}), '');
      expect(itemName(42), '');
    });
  });

  group('bestNameScore', () {
    test('a German query matches the German name on an English display', () {
      // This is the whole reason the function exists: the display name is
      // locale-pinned, so scoring against it alone loses the other locale.
      final item = <String, dynamic>{
        'product_name': 'Cottage cheese',
        '_name_en': 'Cottage cheese',
        '_name_de': 'Hüttenkäse',
      };
      expect(bestNameScore('huttenkase', item), 0);
      expect(bestNameScore('cottage cheese', item), 0);
    });

    test('it takes the best of the candidates, not the first', () {
      final item = <String, dynamic>{
        'product_name': 'Semi-skimmed milk drink',
        '_name_de': 'Milch',
      };
      expect(bestNameScore('milch', item), lessThan(nameScore('milch', 'Semi-skimmed milk drink')));
    });

    test('an item with no usable name scores as no match', () {
      expect(bestNameScore('milch', <String, dynamic>{}), noMatch);
    });

    test('non-string locale fields are ignored rather than crashing', () {
      final item = <String, dynamic>{'product_name': 'Milch', '_name_de': 42};
      expect(bestNameScore('milch', item), 0);
    });
  });
}
